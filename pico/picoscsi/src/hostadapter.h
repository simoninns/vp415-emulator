/************************************************************************

    hostadapter.h

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

#ifndef HOSTADAPTER_H_
#define HOSTADAPTER_H_

// Host adapter hardware definitions

// SCSI control signals (inputs)
#define NRST_PORT 13
#define NACK_PORT 14
#define NSEL_PORT 1

// SCSI status signals (outputs)
#define STATUS_NMSG_PORT 12
#define STATUS_NBSY_PORT 15
#define STATUS_NREQ_PORT 9
#define STATUS_INO_PORT 8
#define STATUS_CND_PORT 10

// Host adapter data bus
#define DATABUS_NDB0 26
#define DATABUS_NDB1 22
#define DATABUS_NDB2 21
#define DATABUS_NDB3 20
#define DATABUS_NDB4 19
#define DATABUS_NDB5 18
#define DATABUS_NDB6 17
#define DATABUS_NDB7 16

// Function prototypes
void nrst_isr(uint gpio, uint32_t events);
void hostadapterInitialise(void);
void hostadapterReset(void);

uint8_t hostadapterReadDatabus(void);
void hostadapterWritedatabus(uint8_t databusValue);

void hostadapterDatabusInput(void);
void hostadapterDatabusOutput(void);

uint8_t hostadapterReadByte(void);
void hostadapterWriteByte(uint8_t databusValue);

uint16_t hostadapterPerformReadDMA(uint8_t *dataBuffer);
uint16_t hostadapterPerformWriteDMA(uint8_t *dataBuffer);

void hostadapterWriteResetFlag(bool flagState);
bool hostadapterReadResetFlag(void);
void hostadapterWriteDataPhaseFlags(bool message, bool commandNotData,
                                    bool inputNotOutput);

void hostadapterWriteBusyFlag(bool flagState);
void hostadapterWriteRequestFlag(bool flagState);
bool hostadapterReadSelectFlag(void);

#endif /* HOSTADAPTER_H_ */