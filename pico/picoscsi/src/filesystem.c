/************************************************************************

    filesystem.c

    PicoSCSI - Raspberry Pico SCSI-1 Drive Emulator
    Copyright (C) 2025 Simon Inns

    This file is part of PicoSCSI.

    PicoSCSI is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Email: simon.inns@gmail.com

************************************************************************/

// Global includes
#include <pico/stdlib.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

#include "debug.h"
#include "picom.h"
#include "filesystem.h"

// File system state structure
struct filesystemStateStruct {
    bool fsMountState;  // File system mount state (true = mounted, false =
                        // dismounted)

    uint8_t lunDirectory;  // Current LUN directory ID
    uint8_t lunNumber;     // Current LUN number
    bool fsLunStatus[8];   // LUN image availability flags for the currently
                           // selected LUN directory (true = started, false =
                           // stopped)
    uint8_t fsLunUserCode[8][5];  // LUN 5-byte User code (used for F-Code
                                  // interactions - only present for laser disc
                                  // images)

    uint8_t fsResult;  // File system result code
    uint8_t fsCounter;

} filesystemState;

static char fileName[255];  // String for storing LFN filename

static uint8_t sectorBuffer[SECTOR_BUFFER_SIZE];  // Buffer for reading sectors
static bool lunOpenFlag = false;  // Flag to track when a LUN is open for
                                  // read/write (to prevent multiple file opens)

// Globals for multi-sector reading
static uint32_t sectorsInBuffer = 0;
static uint32_t currentBufferSector = 0;
static uint32_t sectorsRemaining = 0;

static void filesystemFlush(void) {
    // If a LUN is open close it
    if (lunOpenFlag) {
        // Close the open file object
        //   f_close(&filesystemState.fileObject);
        lunOpenFlag = false;
        if (debugFlag_filesystem)
            debugPrintf("File system: filesystemFlush(): Completed\r\n");
    }
}

// Function to initialise the file system control functions
void filesystemInitialise(void) {
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemInitialise(): Initialising file "
            "system\r\n");
    filesystemState.lunDirectory = 0;      // Default to LUN directory 0
    filesystemState.fsMountState = false;  // FS default state is unmounted

    // Mount the file system
    filesystemMount();
}

// Reset the file system (called when the host signals reset)
void filesystemReset(void) {
    uint8_t lunNumber;
    bool errorFlag = false;

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemReset(): Resetting file system\r\n");

    // Is the SD card/FAT file system  mounted?
    if (filesystemState.fsMountState == true) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemReset(): File system is flagged as "
                "mounted\r\n");

        // Test mounted LUNs to make sure they are still available
        // Note: This is in case the SD card has been removed or changed since
        // the last reset.
        for (lunNumber = 0; lunNumber < 8; lunNumber++) {
            // If the LUN status is available, test it to make sure
            if (filesystemReadLunStatus(lunNumber)) {
                if (!filesystemTestLunStatus(lunNumber)) errorFlag = true;
            }
        }

        // If any of the LUN's had an invalid status we should remount to ensure
        // everything is ok.
        if (errorFlag) {
            debugPrintf(
                "File system: filesystemReset(): LUN status flags are "
                "incorrect!\r\n");

            // Dismount and then mount file system to ensure it is correct
            filesystemDismount();
            filesystemMount();
        }
    } else {
        // If the file system is not currently mounted, attempt to mount it
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemReset(): File system is not mounted - "
                "attempting to mount\r\n");
        filesystemMount();
    }
}

// File system mount and dismount functions
// -------------------------------------------------------------------------------------------------------------------

// Function to mount the file system
bool filesystemMount(void) {
    if (debugFlag_filesystem)
        debugPrintf("File system: filesystemMount(): Mounting file system\r\n");

    // Is the file system already mounted?
    uint8_t pirResponse = picomGetMountState();

    if (pirResponse == PIR_TRUE) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemMount(): ERROR: File system is already "
                "mounted\r\n");
        return false;
    }

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemMount(): Flushing the file system\r\n");
    filesystemFlush();

    // Set all LUNs to stopped
    filesystemSetLunStatus(0, false);
    filesystemSetLunStatus(1, false);
    filesystemSetLunStatus(2, false);
    filesystemSetLunStatus(3, false);
    filesystemSetLunStatus(4, false);
    filesystemSetLunStatus(5, false);
    filesystemSetLunStatus(6, false);
    filesystemSetLunStatus(7, false);

    // Mount the host filesystem
    pirResponse = picomSetMountState(true);

    // Check the result
    if (pirResponse != PIR_TRUE) {
        if (debugFlag_filesystem) {
            switch (pirResponse) {
                case PIR_FALSE:
                    debugPrintf(
                        "File system: filesystemMount(): ERROR: "
                        "Pi could not mount filesystem\r\n");
                    break;

                case PIR_TIMEOUT:
                    debugPrintf(
                        "File system: filesystemMount(): ERROR: "
                        "Pi did not respond (timeout)\r\n");
                    break;

                default:
                    debugPrintf(
                        "File system: filesystemMount(): ERROR: Unknown "
                        "error\r\n");
            }
        }

        // Exit with error status
        filesystemState.fsMountState = false;
        return false;
    }

    if (debugFlag_filesystem)
        debugPrintf("File system: filesystemMount(): Successful\r\n");
    filesystemState.fsMountState = true;

    // Note: ADFS does not send a SCSI STARTSTOP command on reboot... it assumes
    // that LUN 0 is already started. This is theoretically incorrect... the
    // host should not assume anything about the state of a SCSI LUN. However,
    // in order to support this buggy implementation we have to start LUN 0
    // here.
    filesystemSetLunStatus(0, true);

    return true;
}

// Function to dismount the file system
bool filesystemDismount(void) {
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemDismount(): Dismounting file system\r\n");

    // Is the file system mounted?
    if (filesystemState.fsMountState == false) {
        // Nothing to do...
        debugPrintf(
            "File system: filesystemDismount(): No file system to "
            "dismount\r\n");
        return false;
    }

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemDismount(): Flushing the file system\r\n");
    filesystemFlush();

    // Set all LUNs to stopped
    filesystemSetLunStatus(0, false);
    filesystemSetLunStatus(1, false);
    filesystemSetLunStatus(2, false);
    filesystemSetLunStatus(3, false);
    filesystemSetLunStatus(4, false);
    filesystemSetLunStatus(5, false);
    filesystemSetLunStatus(6, false);
    filesystemSetLunStatus(7, false);

    // Dismount the SD card
    filesystemState.fsResult = 0;  // f_mount(&filesystemState.fsObject, "", 0);

    // Check the result
    if (filesystemState.fsResult != 0) {
        if (debugFlag_filesystem) {
            switch (filesystemState.fsResult) {
                case 1:
                    debugPrintf(
                        "File system: filesystemDismount(): ERROR: "
                        "FR_INVALID_DRIVE\r\n");
                    break;

                case 2:
                    debugPrintf(
                        "File system: filesystemDismount(): ERROR: "
                        "FR_DISK_ERR\r\n");
                    break;

                case 3:
                    debugPrintf(
                        "File system: filesystemDismount(): ERROR: "
                        "FR_NOT_READY\r\n");
                    break;

                case 4:
                    debugPrintf(
                        "File system: filesystemDismount(): ERROR: "
                        "FR_NO_FILESYSTEM\r\n");
                    break;

                default:
                    debugPrintf(
                        "File system: filesystemDismount(): ERROR: Unknown "
                        "error\r\n");
            }
        }

        // Exit with error status
        filesystemState.fsMountState = false;
        return false;
    }

    if (debugFlag_filesystem)
        debugPrintf("File system: filesystemDismount(): Successful\r\n");
    filesystemState.fsMountState = false;
    return true;
}

// LUN status control functions
// -------------------------------------------------------------------------------------------------------------------------------

// Function to set the status of a LUN image
bool filesystemSetLunStatus(uint8_t lunNumber, bool lunStatus) {
    // Is the requested status the same as the current status?
    if (filesystemState.fsLunStatus[lunNumber] == lunStatus) {
        if (debugFlag_filesystem) {
            if (filesystemState.fsLunStatus[lunNumber]) {
                debugPrintf(
                    "File system: filesystemSetLunStatus(): LUN number %d is "
                    "started\r\n",
                    lunNumber);
            } else {
                debugPrintf(
                    "File system: filesystemSetLunStatus(): LUN number %d is "
                    "stopped\r\n",
                    lunNumber);
            }
        }

        return true;
    }

    // Transitioning from stopped to started?
    if (filesystemState.fsLunStatus[lunNumber] == false && lunStatus == true) {
        // Is the file system mounted?
        if (filesystemState.fsMountState == false) {
            // Nothing to do...
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemSetLunStatus(): ERROR: No file "
                    "system mounted - cannot set LUNs to started!\r\n");
            return false;
        }

        // If the LUN image is starting the file system needs to recheck the LUN
        // and LUN descriptor to ensure everything is up to date

        // Check that the currently selected LUN directory exists (and, if not,
        // create it)
        if (!filesystemCheckLunDirectory(filesystemState.lunDirectory)) {
            // Failed!
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemSetLunStatus(): ERROR: Could not "
                    "access LUN image directory!\r\n");
            return false;
        }

        // Check that the LUN image exists
        if (!filesystemCheckLunImage(lunNumber)) {
            // Failed!
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemSetLunStatus(): ERROR: Could not "
                    "access LUN image file!\r\n");
            return false;
        }

        // Exit with success
        filesystemState.fsLunStatus[lunNumber] = true;

        if (debugFlag_filesystem) {
            debugPrintf("File system: filesystemSetLunStatus(): LUN number %d",
                        lunNumber);
            debugPrintf(" is started\r\n");
        }

        return true;
    }

    // Transitioning from started to stopped?
    if (filesystemState.fsLunStatus[lunNumber] == true && lunStatus == false) {
        // If the LUN image is stopping the file system doesn't need to do
        // anything other than note the change of status
        filesystemState.fsLunStatus[lunNumber] = false;

        if (debugFlag_filesystem) {
            debugPrintf("File system: filesystemSetLunStatus(): LUN number %d",
                        lunNumber);
            debugPrintf(" is stopped\r\n");
        }

        // Exit with success
        return true;
    }

    return false;
}

// Function to read the status of a LUN image
bool filesystemReadLunStatus(uint8_t lunNumber) {
    return filesystemState.fsLunStatus[lunNumber];
}

// Function to confirm that a LUN image is still available
bool filesystemTestLunStatus(uint8_t lunNumber) {
    if (filesystemState.fsLunStatus[lunNumber] == true) {
        // Check that the LUN image exists
        if (!filesystemCheckLunImage(lunNumber)) {
            // Failed!
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemTestLunStatus(): ERROR: Could not "
                    "access LUN image file!\r\n");
            return false;
        }
    } else {
        // LUN is not marked as available!
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemTestLunStatus(): LUN status is marked "
                "as stopped - cannot test\r\n");
        return false;
    }

    // LUN tested OK
    return true;
}

// Function to read the user code for the specified LUN image
void filesystemReadLunUserCode(uint8_t lunNumber, uint8_t userCode[5]) {
    userCode[0] = filesystemState.fsLunUserCode[lunNumber][0];
    userCode[1] = filesystemState.fsLunUserCode[lunNumber][1];
    userCode[2] = filesystemState.fsLunUserCode[lunNumber][2];
    userCode[3] = filesystemState.fsLunUserCode[lunNumber][3];
    userCode[4] = filesystemState.fsLunUserCode[lunNumber][4];
}

// Check that the currently selected LUN directory exists (and, if not, create
// it)
bool filesystemCheckLunDirectory(uint8_t lunDirectory) {
    // Is the file system mounted?
    if (filesystemState.fsMountState == false) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCheckLunDirectory(): ERROR: No file "
                "system mounted\r\n");
        return false;
    }

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCheckLunDirectory(): Flushing the file "
            "system\r\n");
    filesystemFlush();

    // Does a directory exist for the currently selected LUN directory - if not,
    // create it
    sprintf(fileName, "/BeebSCSI%d", lunDirectory);

    filesystemState.fsResult =
        1;  // f_opendir(&filesystemState.dirObject, fileName);

    // Check the result
    if (filesystemState.fsResult != 0) {
        switch (filesystemState.fsResult) {
            case 1:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): f_opendir "
                        "returned FR_NO_PATH - Directory does not exist\r\n");
                break;

            case 2:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_DISK_ERR\r\n");
                return false;
                break;

            case 3:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_INT_ERR\r\n");
                return false;
                break;

            case 4:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_INVALID_NAME\r\n");
                return false;
                break;

            case 5:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_INVALID_OBJECT\r\n");
                return false;
                break;

            case 6:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_INVALID_DRIVE\r\n");
                return false;
                break;

            case 7:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_NOT_ENABLED\r\n");
                return false;
                break;

            case 8:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_NO_FILESYSTEM\r\n");
                return false;
                break;

            case 9:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_TIMEOUT\r\n");
                return false;
                break;

            case 10:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_NOT_ENOUGH_CORE\r\n");
                return false;
                break;

            case 11:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned FR_TOO_MANY_OPEN_FILES\r\n");
                return false;
                break;

            default:
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemCheckLunDirectory(): ERROR: "
                        "f_opendir returned unknown error\r\n");
                return false;
                break;
        }
    }

    // Did a directory exist?
    if (filesystemState.fsResult == 13) {  // FR_NO_PATH) {
        // f_closedir(&filesystemState.dirObject);

        // Create the LUN image directory - it's not present on the SD card
        filesystemState.fsResult = -1;  // f_mkdir(fileName);

        // Now open the directory
        // filesystemState.fsResult = f_opendir(&filesystemState.dirObject,
        // fileName);

        // Check the result
        if (filesystemState.fsResult != 0) {
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemCheckLunDirectory(): ERROR: Unable "
                    "to create LUN directory\r\n");
            // f_closedir(&filesystemState.dirObject);
            return false;
        }

        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCheckLunDirectory(): Created LUN "
                "directory entry\r\n");
        // f_closedir(&filesystemState.dirObject);
    } else {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCheckLunDirectory(): LUN directory "
                "found\r\n");
        // f_closedir(&filesystemState.dirObject);
    }

    return true;
}

// Function to scan for SCSI LUN image file on the mounted file system
// and check the image is valid.
bool filesystemCheckLunImage(uint8_t lunNumber) {
    uint32_t lunFileSize;
    uint32_t lunDscSize;

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCheckLunImage(): Flushing the file "
            "system\r\n");
    filesystemFlush();

    // Attempt to open the LUN image
    sprintf(fileName, "/BeebSCSI%d/scsi%d.dat", filesystemState.lunDirectory,
            lunNumber);
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCheckLunImage(): Checking for (.dat) LUN "
            "image %d",
            lunNumber);
    filesystemState.fsResult =
        1;  // f_open(&filesystemState.fileObject, fileName, FA_READ);

    if (filesystemState.fsResult != 0) {
        if (debugFlag_filesystem) {
            switch (filesystemState.fsResult) {
                case 1:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_DISK_ERR\r\n");
                    break;

                case 2:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_INT_ERR\r\n");
                    break;

                case 3:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_NOT_READY\r\n");
                    break;

                case 4:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): LUN image not "
                        "found\r\n");
                    break;

                case 5:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_NO_PATH\r\n");
                    break;

                case 6:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_INVALID_NAME\r\n");
                    break;

                case 7:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_DENIED\r\n");
                    break;

                case 8:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_EXIST\r\n");
                    break;

                case 9:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_INVALID_OBJECT\r\n");
                    break;

                case 10:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_WRITE_PROTECTED\r\n");
                    break;

                case 11:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_INVALID_DRIVE\r\n");
                    break;

                case 12:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_NOT_ENABLED\r\n");
                    break;

                case 13:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_NO_FILESYSTEM\r\n");
                    break;

                case 14:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_TIMEOUT\r\n");
                    break;

                case 15:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_LOCKED\r\n");
                    break;

                case 16:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_NOT_ENOUGH_CORE\r\n");
                    break;

                case 17:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned FR_TOO_MANY_OPEN_FILES\r\n");
                    break;

                default:
                    debugPrintf(
                        "File system: filesystemCheckLunImage(): ERROR: f_open "
                        "on LUN image returned Funknown error\r\n");
                    break;
            }
        }

        // Exit with error
        // f_close(&filesystemState.fileObject);
        return false;
    }

    // Opening the LUN image was successful
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCheckLunImage(): LUN image found\r\n");

    // Get the size of the LUN image in bytes
    lunFileSize = 0;  //(uint32_t)f_size(&filesystemState.fileObject);
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCheckLunImage(): LUN size in bytes "
            "(according to .dat) = %d",
            lunFileSize);

    // Check that the LUN file size is actually a size which ADFS can support
    // (the number of sectors is limited to a 21 bit number) i.e. a maximum of
    // 0x1FFFFF or 2,097,151 (* 256 bytes per sector = 512Mb = 536,870,656
    // bytes)
    if (lunFileSize > 536870656) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCheckLunImage(): WARNING: The LUN file "
                "size is greater than 512Mbs\r\n");
    }

    // Close the LUN image file
    // f_close(&filesystemState.fileObject);

    // Check if the LUN descriptor file (.dsc) is present
    sprintf(fileName, "/BeebSCSI%d/scsi%d.dsc", filesystemState.lunDirectory,
            lunNumber);

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCheckLunImage(): Checking for (.dsc) LUN "
            "descriptor %d",
            lunNumber);
    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_READ);

    if (filesystemState.fsResult != 0) {
        // LUN descriptor file is not found
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCheckLunImage(): LUN descriptor not "
                "found\r\n");
        // f_close(&filesystemState.fileObject);

        // Automatically create a LUN descriptor file for the LUN image
        if (filesystemCreateDscFromLunImage(filesystemState.lunDirectory,
                                            lunNumber, lunFileSize)) {
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemCheckLunImage(): Automatically "
                    "created .dsc for LUN image\r\n");
        } else {
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemCheckLunImage(): ERROR: "
                    "Automatically creating .dsc for LUN image failed\r\n");
        }
    } else {
        // LUN descriptor file is present
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCheckLunImage(): LUN descriptor "
                "found\r\n");
        // f_close(&filesystemState.fileObject);

        // Calculate the LUN size from the descriptor file
        lunDscSize = filesystemGetLunSizeFromDsc(filesystemState.lunDirectory,
                                                 lunNumber);
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCheckLunImage(): LUN size in bytes "
                "(according to .dsc) = %d",
                lunDscSize);

        // Are the file size and DSC size consistent?
        if (lunDscSize != lunFileSize) {
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemCheckLunImage(): WARNING: File "
                    "size and DSC parameters are NOT consistent\r\n");
        }
    }

    // Check if the LUN user code descriptor file (.ucd) is present
    sprintf(fileName, "/BeebSCSI%d/scsi%d.ucd", filesystemState.lunDirectory,
            lunNumber);

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCheckLunImage(): Checking for (.ucd) LUN "
            "user code descriptor\r\n");
    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_READ);

    if (filesystemState.fsResult != 0) {
        // LUN descriptor file is not found
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCheckLunImage(): LUN user code "
                "descriptor not found\r\n");
        // f_close(&filesystemState.fileObject);

        // Set the user code descriptor to the default (probably not a laser
        // disc image)
        filesystemState.fsLunUserCode[lunNumber][0] = 0x00;
        filesystemState.fsLunUserCode[lunNumber][1] = 0x00;
        filesystemState.fsLunUserCode[lunNumber][2] = 0x00;
        filesystemState.fsLunUserCode[lunNumber][3] = 0x00;
        filesystemState.fsLunUserCode[lunNumber][4] = 0x00;
    } else {
        // LUN user code descriptor file is present
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCheckLunImage(): LUN user code "
                "descriptor found\r\n");

        // Close the .ucd file
        // f_close(&filesystemState.fileObject);

        // Read the user code from the .ucd file
        filesystemGetUserCodeFromUcd(filesystemState.lunDirectory, lunNumber);
    }

    // Exit with success
    if (debugFlag_filesystem)
        debugPrintf("File system: filesystemCheckLunImage(): Successful\r\n");
    return true;
}

// Function to calculate the LUN image size from the LUN descriptor file
// parameters
uint32_t filesystemGetLunSizeFromDsc(uint8_t lunDirectory, uint8_t lunNumber) {
    uint32_t lunSize = 0;
    uint16_t fsCounter;

    uint32_t blockSize;
    uint32_t cylinderCount;
    uint32_t dataHeadCount;

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemGetLunSizeFromDsc(): Flushing the file "
            "system\r\n");
    filesystemFlush();

    // Assemble the DSC file name
    sprintf(fileName, "/BeebSCSI%d/scsi%d.dsc", lunDirectory, lunNumber);

    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_READ);
    if (filesystemState.fsResult == 0) {
        // Read the DSC data
        filesystemState.fsResult = -1;  // f_read(&filesystemState.fileObject,
                                        // sectorBuffer, 22, &fsCounter);

        // Check that the file was read OK and is the correct length
        if (filesystemState.fsResult != 0 && fsCounter == 22) {
            // Something went wrong
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemGetLunSizeFromDsc(): ERROR: Could "
                    "not read .dsc file\r\n");
            // f_close(&filesystemState.fileObject);
            return 0;
        }

        // Interpret the DSC information and calculate the LUN size
        if (debugFlag_filesystem) debugLunDescriptor(sectorBuffer);

        blockSize =
            (((uint32_t)sectorBuffer[9] << 16) +
             ((uint32_t)sectorBuffer[10] << 8) + (uint32_t)sectorBuffer[11]);
        cylinderCount =
            (((uint32_t)sectorBuffer[13] << 8) + (uint32_t)sectorBuffer[14]);
        dataHeadCount = (uint32_t)sectorBuffer[15];

        // Note:
        //
        // The drive size (actual data storage) is calculated by the following
        // formula:
        //
        // tracks = heads * cylinders
        // sectors = tracks * 33
        // (the '33' is because SuperForm uses a 2:1 interleave format with 33
        // sectors per track (F-2 in the ACB-4000 manual)) bytes = sectors *
        // block size (block size is always 256 bytes)
        lunSize = ((dataHeadCount * cylinderCount) * 33) * blockSize;
        // f_close(&filesystemState.fileObject);
    }

    return lunSize;
}

// Function to automatically create a DSC file based on the file size of the LUN
// image Note, this function is specific to the BBC Micro and the ACB-4000 host
// adapter card If the DSC is inaccurate then, for the BBC Micro, it's not that
// important, since the host only looks at its own file system data (Superform
// and other formatters use the DSC information though... so beware).
bool filesystemCreateDscFromLunImage(uint8_t lunDirectory, uint8_t lunNumber,
                                     uint32_t lunFileSize) {
    uint32_t cylinders;
    uint32_t heads;
    uint16_t fsCounter;

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCreateDscFromLunImage(): Flushing the file "
            "system\r\n");
    filesystemFlush();

    // Calculate the LUN file size in tracks (33 sectors per track, 256 bytes
    // per sector)

    // Check that the LUN file size is actually a size which ADFS can support
    // (the number of sectors is limited to a 21 bit number) i.e. a maximum of
    // 0x1FFFFF or 2,097,151 (* 256 bytes per sector = 512Mb = 536,870,656
    // bytes)
    if (lunFileSize > 536870656) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCreateDscFromLunImage(): WARNING: The "
                "LUN file size is greater than 512Mbs\r\n");
    }

    // Check that the LUN file size is actually a size which the ACB-4000 card
    // could have supported (given that the block and track sizes were fixed to
    // 256 and 33 respectively)
    if (lunFileSize % (256 * 33) != 0) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCreateDscFromLunImage(): WARNING: The "
                "LUN file size could not be supported by an ACB-4000 card\r\n");
    }
    lunFileSize = lunFileSize / (33 * 256);

    // The lunFileSize (in tracks) should be evenly divisible by the head count
    // and the head count should be 16 or less.
    heads = 16;
    while ((lunFileSize % heads != 0) && heads != 1) heads--;
    cylinders = lunFileSize / heads;

    if (debugFlag_filesystem) {
        debugPrintf(
            "File system: filesystemCreateDscFromLunImage(): LUN size in "
            "tracks (33 * 256 bytes) = %d",
            lunFileSize);
        debugPrintf(
            "File system: filesystemCreateDscFromLunImage(): Number of heads = "
            "%d",
            heads);
        debugPrintf(
            "File system: filesystemCreateDscFromLunImage(): Number of "
            "cylinders = %d",
            cylinders);
    }

    // The first 4 bytes are the Mode Select Parameter List (ACB-4000 manual
    // figure 5-18)
    sectorBuffer[0] = 0;  // Reserved (0)
    sectorBuffer[1] = 0;  // Reserved (0)
    sectorBuffer[2] = 0;  // Reserved (0)
    sectorBuffer[3] = 8;  // Length of Extent Descriptor List (8)

    // The next 8 bytes are the Extent Descriptor list (there can only be one of
    // these and it's always 8 bytes) (ACB-4000 manual figure 5-19)
    sectorBuffer[4] = 0;   // Density code
    sectorBuffer[5] = 0;   // Reserved (0)
    sectorBuffer[6] = 0;   // Reserved (0)
    sectorBuffer[7] = 0;   // Reserved (0)
    sectorBuffer[8] = 0;   // Reserved (0)
    sectorBuffer[9] = 0;   // Block size MSB
    sectorBuffer[10] = 1;  // Block size
    sectorBuffer[11] = 0;  // Block size LSB = 256

    // The next 12 bytes are the Drive Parameter List (ACB-4000 manual figure
    // 5-20)
    sectorBuffer[12] = 1;  // List format code
    sectorBuffer[13] =
        (uint8_t)((cylinders & 0x0000FF00) >> 8);          // Cylinder count MSB
    sectorBuffer[14] = (uint8_t)(cylinders & 0x000000FF);  // Cylinder count LSB
    sectorBuffer[15] = (uint8_t)(heads & 0x000000FF);      // Data head count
    sectorBuffer[16] = 0;    // Reduced write current cylinder MSB
    sectorBuffer[17] = 128;  // Reduced write current cylinder LSB = 128
    sectorBuffer[18] = 0;    // Write pre-compensation cylinder MSB
    sectorBuffer[19] = 128;  // Write pre-compensation cylinder LSB = 128
    sectorBuffer[20] = 0;    // Landing zone position
    sectorBuffer[21] = 1;    // Step pulse output rate code

    // Assemble the DSC file name
    sprintf(fileName, "/BeebSCSI%d/scsi%d.dsc", lunDirectory, lunNumber);

    filesystemState.fsResult = -1;  // f_open(&filesystemState.fileObject,
                                    // fileName, FA_CREATE_NEW | FA_WRITE);
    if (filesystemState.fsResult == 0) {
        // Write the DSC data
        filesystemState.fsResult = -1;  // f_write(&filesystemState.fileObject,
                                        // sectorBuffer, 22, &fsCounter);

        // Check that the file was written OK and is the correct length
        if (filesystemState.fsResult != 0 && fsCounter == 22) {
            // Something went wrong
            if (debugFlag_filesystem) {
                debugPrintf(
                    "File system: filesystemCreateDscFromLunImage(): ERROR: "
                    ".dsc create failed\r\n");

                switch (filesystemState.fsResult) {
                    case 1:
                        debugPrintf(
                            "File system: filesystemCreateDscFromLunImage(): "
                            "ERROR: f_write on LUN .dsc returned "
                            "FR_DISK_ERR\r\n");
                        break;

                    case 2:
                        debugPrintf(
                            "File system: filesystemCreateDscFromLunImage(): "
                            "ERROR: f_write on LUN .dsc returned "
                            "FR_INT_ERR\r\n");
                        break;

                    case 3:
                        debugPrintf(
                            "File system: filesystemCreateDscFromLunImage(): "
                            "ERROR: f_write on LUN .dsc returned "
                            "FR_DENIED\r\n");
                        break;

                    case 4:
                        debugPrintf(
                            "File system: filesystemCreateDscFromLunImage(): "
                            "ERROR: f_write on LUN .dsc returned "
                            "FR_INVALID_OBJECT\r\n");
                        break;

                    case 5:
                        debugPrintf(
                            "File system: filesystemCreateDscFromLunImage(): "
                            "ERROR: f_write on LUN .dsc returned "
                            "FR_TIMEOUT\r\n");
                        break;

                    default:
                        debugPrintf(
                            "File system: filesystemCreateDscFromLunImage(): "
                            "ERROR: f_write on LUN .dsc returned unknown "
                            "error\r\n");
                        break;
                }
            }

            // f_close(&filesystemState.fileObject);
            return false;
        }
    } else {
        // Something went wrong
        if (debugFlag_filesystem) {
            switch (filesystemState.fsResult) {
                case 1:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned FR_DISK_ERR\r\n");
                    break;

                case 2:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned FR_INT_ERR\r\n");
                    break;

                case 3:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned FR_NOT_READY\r\n");
                    break;

                case 4:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned FR_NO_FILE\\r\n");
                    break;

                case 5:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned FR_NO_PATH\r\n");
                    break;

                case 6:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned "
                        "FR_INVALID_NAME\r\n");
                    break;

                case 7:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned FR_DENIED\r\n");
                    break;

                case 8:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned FR_EXIST\r\n");
                    break;

                case 9:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned "
                        "FR_INVALID_OBJECT\r\n");
                    break;

                case 10:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned "
                        "FR_WRITE_PROTECTED\r\n");
                    break;

                case 11:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned "
                        "FR_INVALID_DRIVE\r\n");
                    break;

                case 12:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned "
                        "FR_NOT_ENABLED\r\n");
                    break;

                case 13:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned "
                        "FR_NO_FILESYSTEM\r\n");
                    break;

                case 14:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned FR_TIMEOUT\r\n");
                    break;

                case 15:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned FR_LOCKED\r\n");
                    break;

                case 16:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned "
                        "FR_NOT_ENOUGH_CORE\r\n");
                    break;

                case 17:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned "
                        "FR_TOO_MANY_OPEN_FILES\r\n");
                    break;

                default:
                    debugPrintf(
                        "File system: filesystemCreateDscFromLunImage(): "
                        "ERROR: f_open on LUN .dsc returned unknown error\r\n");
                    break;
            }
        }

        // f_close(&filesystemState.fileObject);
        return false;
    }

    // Descriptor write OK
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCreateDscFromLunImage(): .dsc file "
            "created\r\n");
    // f_close(&filesystemState.fileObject);

    return true;
}

// Function to read the user code data from the LUN user code descriptor file
// (.ucd)
void filesystemGetUserCodeFromUcd(uint8_t lunDirectoryNumber,
                                  uint8_t lunNumber) {
    uint16_t fsCounter;

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemGetUserCodeFromUcd(): Flushing the file "
            "system\r\n");
    filesystemFlush();

    // Assemble the UCD file name
    sprintf(fileName, "/BeebSCSI%d/scsi%d.ucd", lunDirectoryNumber, lunNumber);

    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_READ);
    if (filesystemState.fsResult == 0) {
        // Read the DSC data
        filesystemState.fsResult =
            -1;  // f_read(&filesystemState.fileObject,
                 // filesystemState.fsLunUserCode[lunNumber], 5, &fsCounter);

        // Check that the file was read OK and is the correct length
        if (filesystemState.fsResult != 0 && fsCounter == 5) {
            // Something went wrong
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemGetUserCodeFromUcd(): ERROR: Could "
                    "not read .ucd file\r\n");
            // f_close(&filesystemState.fileObject);
            return;
        }

        if (debugFlag_filesystem) {
            debugPrintf(
                "File system: filesystemGetUserCodeFromUcd(): User code bytes "
                "(from .ucd): %d",
                filesystemState.fsLunUserCode[lunNumber][0]);
            debugPrintf(", %d", filesystemState.fsLunUserCode[lunNumber][1]);
            debugPrintf(", %d", filesystemState.fsLunUserCode[lunNumber][2]);
            debugPrintf(", %d", filesystemState.fsLunUserCode[lunNumber][3]);
            debugPrintf(", %d", filesystemState.fsLunUserCode[lunNumber][4]);
        }

        // f_close(&filesystemState.fileObject);
    }
}

// Function to set the current LUN directory (for the LUN jukeboxing
// functionality)
void filesystemSetLunDirectory(uint8_t lunDirectoryNumber) {
    // Change the current LUN directory number
    filesystemState.lunDirectory = lunDirectoryNumber;

    // Set all LUNs to stopped
    filesystemSetLunStatus(0, false);
    filesystemSetLunStatus(1, false);
    filesystemSetLunStatus(2, false);
    filesystemSetLunStatus(3, false);
    filesystemSetLunStatus(4, false);
    filesystemSetLunStatus(5, false);
    filesystemSetLunStatus(6, false);
    filesystemSetLunStatus(7, false);
}

// Function to read the current LUN directory (for the LUN jukeboxing
// functionality)
uint8_t filesystemGetLunDirectory(void) { return filesystemState.lunDirectory; }

// Functions for creating LUNs and LUN descriptors
// ------------------------------------------------------------------------------------------------------------

// Function to create a new LUN image (makes an empty .dat file)
bool filesystemCreateLunImage(uint8_t lunNumber) {
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCreateLunImage(): Flushing the file "
            "system\r\n");
    filesystemFlush();

    // Assemble the .dat file name
    sprintf(fileName, "/BeebSCSI%d/scsi%d.dat", filesystemState.lunDirectory,
            lunNumber);

    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_READ);
    if (filesystemState.fsResult == 0) {
        // File opened ok - which means it already exists...
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCreateLunImage(): .dat already exists "
                "- ignoring request to create a new .dat\r\n");
        // f_close(&filesystemState.fileObject);
        return true;
    }

    // Create a new .dat file
    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_CREATE_NEW);
    if (filesystemState.fsResult != 0) {
        // Create .dat file failed
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCreateLunImage(): ERROR: Could not "
                "create new .dat file!\r\n");
        // f_close(&filesystemState.fileObject);
        return false;
    }

    // LUN .dat file created successfully
    // f_close(&filesystemState.fileObject);
    if (debugFlag_filesystem)
        debugPrintf("File system: filesystemCreateLunImage(): Successful\r\n");
    return true;
}

// Function to create a new LUN descriptor (makes an empty .dsc file)
bool filesystemCreateLunDescriptor(uint8_t lunNumber) {
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCreateLunDescriptor(): Flushing the file "
            "system\r\n");
    filesystemFlush();

    // Assemble the .dsc file name
    sprintf(fileName, "/BeebSCSI%d/scsi%d.dsc", filesystemState.lunDirectory,
            lunNumber);

    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_READ);
    if (filesystemState.fsResult == 0) {
        // File opened ok - which means it already exists...
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCreateLunDescriptor(): .dsc already "
                "exists - ignoring request to create a new .dsc\r\n");
        // f_close(&filesystemState.fileObject);
        return true;
    }

    // Create a new .dsc file
    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_CREATE_NEW);
    if (filesystemState.fsResult != 0) {
        // Create .dsc file failed
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCreateLunDescriptor(): ERROR: Could "
                "not create new .dsc file!\r\n");
        // f_close(&filesystemState.fileObject);
        return false;
    }

    // LUN DSC file created successfully
    // f_close(&filesystemState.fileObject);
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemCreateLunDescriptor(): Successful\r\n");
    return true;
}

// Function to read a LUN descriptor
bool filesystemReadLunDescriptor(uint8_t lunNumber, uint8_t buffer[]) {
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemReadLunDescriptor(): Flushing the file "
            "system\r\n");
    filesystemFlush();

    // Assemble the .dsc file name
    sprintf(fileName, "/BeebSCSI%d/scsi%d.dsc", filesystemState.lunDirectory,
            lunNumber);

    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_READ);
    if (filesystemState.fsResult == 0) {
        // Read the .dsc data
        filesystemState.fsResult =
            -1;  // f_read(&filesystemState.fileObject, buffer, 22,
                 // &filesystemState.fsCounter);

        // Check that the file was read OK and is the correct length
        if (filesystemState.fsResult != 0 && filesystemState.fsCounter == 22) {
            // Something went wrong
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemReadLunDescriptor(): ERROR: Could "
                    "not read .dsc file for LUN\r\n");
            // f_close(&filesystemState.fileObject);
            return false;
        }
    } else {
        // Looks like the .dsc file is not present on the file system
        debugPrintf(
            "File system: filesystemReadLunDescriptor(): ERROR: Could not open "
            ".dsc file for LUN %d",
            lunNumber);
        // f_close(&filesystemState.fileObject);
        return false;
    }

    // Descriptor read OK
    // f_close(&filesystemState.fileObject);
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemReadLunDescriptor(): Successful\r\n");
    return true;
}

// Function to write a LUN descriptor
bool filesystemWriteLunDescriptor(uint8_t lunNumber, uint8_t buffer[]) {
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemWriteLunDescriptor(): Flushing the file "
            "system\r\n");
    filesystemFlush();

    // Assemble the .dsc file name
    sprintf(fileName, "/BeebSCSI%d/scsi%d.dsc", filesystemState.lunDirectory,
            lunNumber);

    filesystemState.fsResult = -1;
    ;  // f_open(&filesystemState.fileObject, fileName, FA_READ | FA_WRITE);
    if (filesystemState.fsResult == 0) {
        // Write the .dsc data
        filesystemState.fsResult =
            -1;  // f_write(&filesystemState.fileObject, buffer, 22,
                 // &filesystemState.fsCounter);

        // Check that the file was written OK and is the correct length
        if (filesystemState.fsResult != 0 && filesystemState.fsCounter == 22) {
            // Something went wrong
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemWriteLunDescriptor(): ERROR: Could "
                    "not write .dsc file for LUN\r\n");
            // f_close(&filesystemState.fileObject);
            return false;
        }
    } else {
        // Looks like the .dsc file is not present on the file system
        debugPrintf(
            "File system: filesystemWriteLunDescriptor(): ERROR: Could not "
            "open .dsc file for LUN %d",
            lunNumber);
        // f_close(&filesystemState.fileObject);
        return false;
    }

    // Descriptor write OK
    // f_close(&filesystemState.fileObject);
    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemWriteLunDescriptor(): Successful\r\n");
    return true;
}

// Function to format a LUN image
bool filesystemFormatLun(uint8_t lunNumber, uint8_t dataPattern) {
    uint32_t requiredNumberOfSectors = 0;

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemFormatLun(): Flushing the file system\r\n");
    filesystemFlush();

    if (debugFlag_filesystem)
        debugPrintf(
            "File system: filesystemFormatLun(): Formatting LUN image %d",
            lunNumber);

    // Read the LUN descriptor for the LUN image into the sector buffer
    if (!filesystemReadLunDescriptor(lunNumber, sectorBuffer)) {
        // Unable to read the LUN descriptor
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemFormatLun(): ERROR: Could not read "
                ".dsc file for LUN\r\n");
        return false;
    }

    // Calculate the number of 256 byte sectors required to fulfill the drive
    // geometry tracks = heads * cylinders sectors = tracks * 33
    requiredNumberOfSectors =
        ((uint32_t)sectorBuffer[15] *
         (((uint32_t)sectorBuffer[13] << 8) + (uint32_t)sectorBuffer[14])) *
        33;
    if (debugFlag_filesystem)
        debugPrintf("File system: filesystemFormatLun(): Sectors required = %d",
                    requiredNumberOfSectors);

    // Assemble the .dat file name
    sprintf(fileName, "/BeebSCSI%d/scsi%d.dat", filesystemState.lunDirectory,
            lunNumber);

    // Note: We are using the expand FAT method to create the LUN image... the
    // dataPattern byte will be ignored. Fill the sector buffer with the
    // required data pattern for (counter = 0; counter < 256; counter++)
    // sectorBuffer[counter] = dataPattern;

    // Create the .dat file (the old .dat file, if present, will be unlinked
    // (i.e. gone forever))
    filesystemState.fsResult =
        -1;  // f_open(&filesystemState.fileObject, fileName, FA_READ | FA_WRITE
             // | FA_CREATE_ALWAYS);
    if (filesystemState.fsResult == 0) {
        // Write the required number of sectors to the DAT file
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemFormatLun(): Performing format...\r\n");

        // If we try to write 512MBs of data to the SD card in 256 byte chunks
        // via SPI it will take a very long time to complete...
        //
        // So instead we use the FAT FS expand command to allocate a file of the
        // required LUN size
        //
        // Note: This allocates a contiguous area for the file which can help to
        // speed up read/write times.  If you would prefer the file to be small
        // and grow as used, just remove the f_expand and the fsResult check.
        // Every thing will work fine without them.
        //
        // This ignores the data pattern (since the file is only allocated - not
        // actually written).
        filesystemState.fsResult =
            -1;  // f_expand(&filesystemState.fileObject,
                 // (FSIZE_t)(requiredNumberOfSectors * 256), 1);

        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemFormatLun(): Format complete\r\n");

        // Check that the file was written OK
        if (filesystemState.fsResult != 0) {
            // Something went wrong writing to the .dat
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemFormatLun(): ERROR: Could not "
                    "write .dat\r\n");
            // f_close(&filesystemState.fileObject);
            return false;
        }
    } else {
        // Something went wrong opening the .dat
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemFormatLun(): ERROR: Could not open "
                ".dat\r\n");
        // f_close(&filesystemState.fileObject);
        return false;
    }

    // Formatting successful
    // f_close(&filesystemState.fileObject);
    if (debugFlag_filesystem)
        debugPrintf("File system: filesystemFormatLun(): Successful\r\n");
    return true;
}

// Functions for reading and writing LUN images
// ---------------------------------------------------------------------------------------------------------------

// Function to open a LUN ready for reading
// Note: The read functions use a multi-sector buffer to lower the number of
// required reads from the physical media.  This is to allow more efficient
// (larger) reads of data.
bool filesystemOpenLunForRead(uint8_t lunNumber, uint32_t startSector,
                              uint32_t requiredNumberOfSectors) {
    uint32_t sectorsToRead = 0;
    bool fastSeeking = false;

    // Is the correct LUN already open?
    if (lunOpenFlag && (filesystemState.lunNumber == lunNumber)) {
        // Move to the correct point in the DAT file
        // This is * 256 as each block is 256 bytes
        filesystemState.fsResult =
            -1;  // f_lseek(&filesystemState.fileObject, startSector * 256);
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemOpenLunForRead(): Using existing open "
                "LUN image\r\n");
    } else {
        // Required LUN is not open, so open it
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemOpenLunForRead(): Requested LUN not "
                "open.  Flushing current LUN\r\n");
        filesystemFlush();

        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemOpenLunForRead(): Opening requested "
                "LUN\r\n");

        // Assemble the .dat file name
        sprintf(fileName, "/BeebSCSI%d/scsi%d.dat",
                filesystemState.lunDirectory, lunNumber);

        // Open the DAT file
        filesystemState.fsResult = -1;  // f_open(&filesystemState.fileObject,
                                        // fileName, FA_READ | FA_WRITE);
        if (filesystemState.fsResult == 0) {
            // Move to the correct point in the DAT file
            // This is * 256 as each block is 256 bytes
            filesystemState.fsResult =
                -1;  // f_lseek(&filesystemState.fileObject, startSector * 256);
            filesystemState.lunNumber = lunNumber;
            // Check that the file seek was OK
            if (filesystemState.fsResult != 0) {
                // Something went wrong with seeking, do not retry
                if (debugFlag_filesystem && !fastSeeking)
                    debugPrintf(
                        "File system: filesystemOpenLunForRead(): ERROR: "
                        "Unable to slow seek to required sector in LUN image "
                        "file!\r\n");
                if (debugFlag_filesystem && fastSeeking)
                    debugPrintf(
                        "File system: filesystemOpenLunForRead(): ERROR: "
                        "Unable to fast seek to required sector in LUN image "
                        "file!\r\n");
                // f_close(&filesystemState.fileObject);
                return false;
            }
        }
    }

    // Fill the file system sector buffer
    sectorsToRead = requiredNumberOfSectors;
    if (sectorsToRead > SECTOR_BUFFER_LENGTH)
        sectorsToRead = SECTOR_BUFFER_LENGTH;

    sectorsInBuffer = sectorsToRead;
    currentBufferSector = 0;
    sectorsRemaining = requiredNumberOfSectors - sectorsInBuffer;

    // Read the required data into the sector buffer
    filesystemState.fsResult =
        -1;  // f_read(&filesystemState.fileObject, sectorBuffer, sectorsToRead
             // * 256, &filesystemState.fsCounter);

    // Check that the file was read OK
    if (filesystemState.fsResult != 0) {
        // Something went wrong
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemReadNextSector(): ERROR: Cannot read "
                "from LUN image!\r\n");
        // f_close(&filesystemState.fileObject);
        return false;
    }

    // Exit with success
    lunOpenFlag = true;
    if (debugFlag_filesystem && fastSeeking)
        debugPrintf(
            "File system: filesystemOpenLunForRead(): Successful (with fast "
            "seeking)\r\n");
    if (debugFlag_filesystem && !fastSeeking)
        debugPrintf(
            "File system: filesystemOpenLunForRead(): Successful (with slow "
            "seeking)\r\n");
    return true;
}

// Function to read next sector from a LUN
bool filesystemReadNextSector(uint8_t buffer[]) {
    uint32_t sectorsToRead = 0;

    // Ensure there is a LUN image open
    if (!lunOpenFlag) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemReadNextSector(): ERROR: No LUN image "
                "open!\r\n");
        return false;
    }

    // Is the required sector already in the sector buffer?
    if (currentBufferSector < sectorsInBuffer) {
        // Fill the function buffer from the sector buffer
        memcpy(buffer, sectorBuffer + (currentBufferSector * 256), 256);

        // Move to the next sector
        currentBufferSector++;
    }

    // Refill the sector buffer?
    if (currentBufferSector == sectorsInBuffer) {
        // Ensure we have sectors remaining to be read
        if (sectorsRemaining != 0) {
            sectorsToRead = sectorsRemaining;
            if (sectorsRemaining > SECTOR_BUFFER_LENGTH)
                sectorsToRead = SECTOR_BUFFER_LENGTH;

            sectorsInBuffer = sectorsToRead;
            currentBufferSector = 0;
            sectorsRemaining = sectorsRemaining - sectorsInBuffer;

            // Read the required data into the sector buffer
            filesystemState.fsResult =
                -1;  // f_read(&filesystemState.fileObject, sectorBuffer,
                     // sectorsToRead * 256, &filesystemState.fsCounter);

            // Check that the file was read OK
            if (filesystemState.fsResult != 0) {
                // Something went wrong
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemReadNextSector(): ERROR: "
                        "Cannot read from LUN image!\r\n");
                // f_close(&filesystemState.fileObject);
                return false;
            }
        }
    }

    // Exit with success
    return true;
}

// Function to close a LUN for reading
bool filesystemCloseLunForRead(void) {
    // Ensure there is a LUN image open
    if (!lunOpenFlag) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCloseLunForRead(): ERROR: No LUN image "
                "open!\r\n");
    }
    return false;
}

// Function to open a LUN ready for writing
bool filesystemOpenLunForWrite(uint8_t lunNumber, uint32_t startSector,
                               uint32_t requiredNumberOfSectors) {
    bool fastSeeking = false;

    // Ensure there isn't already a LUN image open
    if (lunOpenFlag) {
        // check that it is the same LUN Number
        if (filesystemState.lunNumber != lunNumber) {
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemOpenLunForWrite(): Requested LUN "
                    "not open.  Flushing current LUN\r\n");
            filesystemFlush();
        } else {
            if (debugFlag_filesystem)
                debugPrintf(
                    "File system: filesystemOpenLunForWrite(): Using existing "
                    "open LUN image\r\n");
        }
    }

    if (!lunOpenFlag) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemOpenLunForWrite(): Opening requested "
                "LUN\r\n");
        // Assemble the .dat file name
        sprintf(fileName, "/BeebSCSI%d/scsi%d.dat",
                filesystemState.lunDirectory, lunNumber);

        // Open the DAT file
        filesystemState.fsResult = -1;  // f_open(&filesystemState.fileObject,
                                        // fileName,  FA_READ | FA_WRITE);
        if (filesystemState.fsResult == 0) {
            // Move to the correct point in the DAT file
            // This is * 256 as each block is 256 bytes
            filesystemState.fsResult =
                -1;  // f_lseek(&filesystemState.fileObject, startSector * 256);
            filesystemState.lunNumber = lunNumber;
            // Check that the file seek was OK
            if (filesystemState.fsResult != 0) {
                // Something went wrong with seeking, do not retry
                if (debugFlag_filesystem)
                    debugPrintf(
                        "File system: filesystemOpenLunForWrite(): ERROR: "
                        "Unable to seek to required sector in LUN image "
                        "file!\r\n");
                // f_close(&filesystemState.fileObject);
                return false;
            }
        }
    } else
        filesystemState.fsResult =
            -1;  // f_lseek(&filesystemState.fileObject, startSector * 256);

    // Exit with success
    lunOpenFlag = true;
    if (debugFlag_filesystem && fastSeeking)
        debugPrintf(
            "File system: filesystemOpenLunForWrite(): Successful (with fast "
            "seeking)\r\n");
    if (debugFlag_filesystem && !fastSeeking)
        debugPrintf(
            "File system: filesystemOpenLunForWrite(): Successful (with slow "
            "seeking)\r\n");
    return true;
}

// Function to write next sector to a LUN
bool filesystemWriteNextSector(uint8_t buffer[]) {
    // Ensure there is a LUN image open
    if (!lunOpenFlag) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemWriteNextSector(): ERROR: No LUN image "
                "open!\r\n");
        return false;
    }

    // Write the required data
    filesystemState.fsResult = -1;  // f_write(&filesystemState.fileObject,
                                    // buffer, 256, &filesystemState.fsCounter);

    // Check that the file was written OK
    if (filesystemState.fsResult != 0) {
        // Something went wrong
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemWriteNextSector(): ERROR: Cannot write "
                "to LUN image!\r\n");
        // f_close(&filesystemState.fileObject);
        return false;
    }

    // Exit with success
    return true;
}

// Function to close a LUN for writing
bool filesystemCloseLunForWrite(void) {
    // Ensure there is a LUN image open
    if (!lunOpenFlag) {
        if (debugFlag_filesystem)
            debugPrintf(
                "File system: filesystemCloseLunForWrite(): ERROR: No LUN "
                "image open!\r\n");
    }
    return false;
}