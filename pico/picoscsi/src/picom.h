/************************************************************************

    picom.h

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

#ifndef PICOM_H_
#define PICOM_H_

// Command responses
#define PIR_OK 0x00
#define PIR_TRUE 0x01
#define PIR_FALSE 0x02
#define PIR_ERROR 0x03
#define PIR_TIMEOUT 0x04

// Command codes
#define PIC_RESET 0x00
#define PIC_SET_MOUNT_STATE 0x01
#define PIC_GET_MOUNT_STATE 0x02
#define PIC_GET_EFM_DATA_PRESENT 0x03
#define PIC_GET_USER_CODE 0x04

// Function prototypes
void picomInitialise(void);
bool picomSendToPi(uint8_t *txData, uint16_t txLength, uint8_t *rxData, uint16_t *rxLength);

// Commands
uint8_t picomGetMountState(void);
uint8_t picomSetMountState(bool mountState);
uint8_t picomGetEfmDataPresent(void);
void picomGetUserCode(uint8_t userCode[5]);

#endif /* PICOM_H_ */