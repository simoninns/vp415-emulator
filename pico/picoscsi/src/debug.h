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

#ifndef DEBUG_H_
#define DEBUG_H_

// External globals
extern volatile bool debugFlag_filesystem;
extern volatile bool debugFlag_scsiCommands;
extern volatile bool debugFlag_scsiBlocks;
extern volatile bool debugFlag_scsiFcodes;
extern volatile bool debugFlag_scsiState;

// Function prototypes
void debugPrintf(const char *format, ...);

void debugSectorBufferHex(uint8_t *buffer, uint16_t numberOfBytes);
void debugLunDescriptor(uint8_t *buffer);

#endif /* DEBUG_H_ */