/************************************************************************

    filesystem.h

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

#ifndef FILESYSTEM_H_
#define FILESYSTEM_H_

// Read/Write sector buffer (must be 256 bytes minimum)
// Testing shows that this is optimal when it matches the sector size of
// the SD card (which is 512 bytes).
#define SECTOR_BUFFER_SIZE 512

// Calculate the length of the sector buffer in 256 byte sectors
#define SECTOR_BUFFER_LENGTH (SECTOR_BUFFER_SIZE / 256)

// External prototypes
void filesystemInitialise(void);
void filesystemReset(void);

bool filesystemMount(void);
bool filesystemDismount(void);

void filesystemSetLunDirectory(uint8_t lunDirectoryNumber);
uint8_t filesystemGetLunDirectory(void);

bool filesystemSetLunStatus(uint8_t lunNumber, bool lunStatus);
bool filesystemReadLunStatus(uint8_t lunNumber);
bool filesystemTestLunStatus(uint8_t lunNumber);
void filesystemReadLunUserCode(uint8_t lunNumber, uint8_t userCode[5]);

bool filesystemCheckLunImage(uint8_t lunNumber);

uint32_t filesystemGetLunSizeFromDsc(uint8_t lunDirectory, uint8_t lunNumber);
bool filesystemCreateDscFromLunImage(uint8_t lunDirectory, uint8_t lunNumber,
                                     uint32_t lunFileSize);

void filesystemGetUserCodeFromUcd(uint8_t lunDirectoryNumber,
                                  uint8_t lunNumber);

bool filesystemCreateLunImage(uint8_t lunNumber);
bool filesystemCreateLunDescriptor(uint8_t lunNumber);
bool filesystemReadLunDescriptor(uint8_t lunNumber, uint8_t buffer[]);
bool filesystemWriteLunDescriptor(uint8_t lunNumber, uint8_t buffer[]);
bool filesystemFormatLun(uint8_t lunNumber, uint8_t dataPattern);

bool filesystemOpenLunForRead(uint8_t lunNumber, uint32_t startSector,
                              uint32_t requiredNumberOfSectors);
bool filesystemReadNextSector(uint8_t buffer[]);
bool filesystemCloseLunForRead(void);
bool filesystemOpenLunForWrite(uint8_t lunNumber, uint32_t startSector,
                               uint32_t requiredNumberOfSectors);
bool filesystemWriteNextSector(uint8_t buffer[]);
bool filesystemCloseLunForWrite(void);

#endif /* FILESYSTEM_H_ */