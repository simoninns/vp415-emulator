/************************************************************************

    debug.h

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
#include <stdio.h>

// Local includes
#include "debug.h"

// Define default debug output flags
volatile bool debugFlag_filesystem = true;
volatile bool debugFlag_scsiCommands = true;
volatile bool debugFlag_scsiBlocks = false;
volatile bool debugFlag_scsiFcodes = true;
volatile bool debugFlag_scsiState = true;

void debugInitialise(void) {
    stdio_init_all();
}

void debugPrintf(const char *format, ...) {
    va_list args;
    va_start(args, format);
    vprintf(format, args);
    va_end(args);
}

// This function outputs a hex dump of the passed buffer
void debugSectorBufferHex(uint8_t *buffer, uint16_t numberOfBytes) {
    uint16_t i = 0;
    uint16_t index = 16;
    uint16_t width = 16;  // Width of output in bytes

    for (uint16_t byteNumber = 0; byteNumber < numberOfBytes;
         byteNumber += 16) {
        for (i = 0; i < index; i++) {
            printf("%02x ", buffer[i + byteNumber]);
        }
        for (uint16_t spacer = index; spacer < width; spacer++)
            printf("	");

        printf(": ");

        for (i = 0; i < index; i++) {
            if (buffer[i + byteNumber] < 32 || buffer[i + byteNumber] > 126)
                printf(".");
            else
                printf("%c", buffer[i + byteNumber]);
        }

        printf("\r\n");
    }

    printf("\r\n");
}

// This function decodes the contents of the LUN descriptor and outputs it to
// debug
void debugLunDescriptor(uint8_t *buffer) {
    debugPrintf("File system: LUN Descriptor contents:\r\n");

    // The first 4 bytes are the Mode Select Parameter List (ACB-4000 manual
    // figure 5-18)
    debugPrintf("File system: Mode Select Parameter List:\r\n");
    debugPrintf("File system:   Reserved (0) = %d\r\n", buffer[0]);
    debugPrintf("File system:   Reserved (0) = %d\r\n", buffer[1]);
    debugPrintf("File system:   Reserved (0) = %d\r\n", buffer[2]);
    debugPrintf("File system:   Length of Extent Descriptor List (8) = %d\r\n",
                buffer[3]);

    // The next 8 bytes are the Extent Descriptor list (there can only be one of
    // these and it's always 8 bytes) (ACB-4000 manual figure 5-19)
    debugPrintf("File system: Extent Descriptor List:\r\n");
    debugPrintf("File system:   Density code = %d\r\n", buffer[4]);
    debugPrintf("File system:   Reserved (0) = %d\r\n", buffer[5]);
    debugPrintf("File system:   Reserved (0) = %d\r\n", buffer[6]);
    debugPrintf("File system:   Reserved (0) = %d\r\n", buffer[7]);
    debugPrintf("File system:   Reserved (0) = %d\r\n", buffer[8]);
    debugPrintf("File system:   Block size = %d\r\n",
                ((uint32_t)buffer[9] << 16) + ((uint32_t)buffer[10] << 8) +
                    (uint32_t)buffer[11]);

    // The next 12 bytes are the Drive Parameter List (ACB-4000 manual figure
    // 5-20)
    debugPrintf("File system: Drive Parameter List:\r\n");
    debugPrintf("File system:   List format code = %d\r\n", buffer[12]);
    debugPrintf("File system:   Cylinder count = %d\r\n",
                (buffer[13] << 8) + buffer[14]);
    debugPrintf("File system:   Data head count = %d\r\n", buffer[15]);
    debugPrintf("File system:   Reduced write current cylinder = %d\r\n",
                (buffer[16] << 8) + buffer[17]);
    debugPrintf("File system:   Write pre-compensation cylinder = %d\r\n",
                (buffer[18] << 8) + buffer[19]);
    debugPrintf("File system:   Landing zone position = %d\r\n", buffer[20]);
    debugPrintf("File system:   Step pulse output rate code = %d\r\n",
                buffer[21]);

    // Note:
    //
    // The drive size (actual data storage) is calculated by the following
    // formula:
    //
    // tracks = heads * cylinders
    // sectors = tracks * 33
    // (the '33' is because SuperForm uses a 2:1 interleave format with 33
    // sectors per track (F-2 in the ACB-4000 manual)) bytes = sectors * block
    // size (block size is always 256 bytes)
}