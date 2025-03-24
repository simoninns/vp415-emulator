/************************************************************************

    picom.c

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

void picomInitialise(void) {
    // Pi communication is via UART1 to the Raspberry Pi 5
    uart_init(uart1, 115200);
    gpio_set_function(4, GPIO_FUNC_UART);
    gpio_set_function(5, GPIO_FUNC_UART);
}

// The underlying communication function is simple.  First 2 bytes are sent representing
// a uint16_t length of the data to be sent.  Then the data is sent.  The Pi will then
// respond with a uint16_t length of the data to be received.  The data is then received.
// The function returns true if the data was received successfully and false if there was
// a timeout.
//
// Note: The maximum length of data that can be sent or received is 512 bytes.
// Note: The txLength and rxLength do not include the 2 bytes used to represent the length.
//
bool picomSendToPi(uint8_t *txData, uint16_t txLength, uint8_t *rxData, uint16_t *rxLength) {
    // Send the length of the txData
    uart_putc_raw(uart1, (txLength >> 8) & 0xFF);
    uart_putc_raw(uart1, txLength & 0xFF);

    // Send the txData
    for (uint8_t i = 0; i < txLength; i++) {
        uart_putc_raw(uart1, txData[i]);
    }

    // Wait for the length of the rxData
    uint16_t rxLengthTemp = 0;
    uint16_t timeout = 0;
    while (uart_is_readable(uart1) == false) {
        sleep_ms(1);
        timeout++;
        if (timeout > 1000) {
            *rxLength = 0;
            debugPrintf("picomSendToPi() - Timeout waiting for rxLength byte 0\n");
            return false;
        }
    }
    rxLengthTemp = uart_getc(uart1) << 8;
    while (uart_is_readable(uart1) == false) {
        sleep_ms(1);
        timeout++;
        if (timeout > 1000) {
            *rxLength = 0;
            debugPrintf("picomSendToPi() - Timeout waiting for rxLength byte 1\n");
            return false;
        }
    }
    rxLengthTemp |= uart_getc(uart1);
    *rxLength = rxLengthTemp;

    // Receive the rxData
    for (uint16_t i = 0; i < rxLengthTemp; i++) {
        while (uart_is_readable(uart1) == false) {
            sleep_ms(1);
            timeout++;
            if (timeout > 1000) {
                *rxLength = 0;
                debugPrintf("picomSendToPi() - Timeout waiting for rxData byte %d of %d\n", i, rxLengthTemp);
                return false;
            }
        }
        rxData[i] = uart_getc(uart1);
    }

    // Data received successfully
    return true; 
}

// Commands ---------------------------------------------------------------

// Returns PIR_TRUE if the file system is mounted and PIR_FALSE if it is not
uint8_t picomGetMountState(void) {
    uint8_t txData[1] = {PIC_GET_MOUNT_STATE};
    uint8_t rxData[1];
    uint16_t rxLength;

    if (!picomSendToPi(txData, 1, rxData, &rxLength)) return PIR_TIMEOUT;

    if (rxData[0] == 0) return PIR_FALSE;
    return PIR_TRUE;
}

// Mounts the file system
uint8_t picomSetMountState(bool mountState) {
    uint8_t txData[2] = {PIC_SET_MOUNT_STATE, mountState};
    uint8_t rxData[1];
    uint16_t rxLength;

    if (!picomSendToPi(txData, 2, rxData, &rxLength)) return PIR_TIMEOUT;

    if (rxData[0] == 0) return PIR_FALSE;
    return PIR_TRUE;
}

// Check if the disc image has EFM data
uint8_t picomGetEfmDataPresent(void) {
    uint8_t txData[1] = {PIC_GET_EFM_DATA_PRESENT};
    uint8_t rxData[1];
    uint16_t rxLength;

    if (!picomSendToPi(txData, 1, rxData, &rxLength)) return PIR_TIMEOUT;

    if (rxData[0] == 0) return PIR_FALSE;
    return PIR_TRUE;
}

// Get the user code
void picomGetUserCode(uint8_t userCode[5]) {
    uint8_t txData[1] = {PIC_GET_USER_CODE};
    uint8_t rxData[5];
    uint16_t rxLength;

    if (!picomSendToPi(txData, 1, rxData, &rxLength)) {
        userCode[0] = 0;
        userCode[1] = 0;
        userCode[2] = 0;
        userCode[3] = 0;
        userCode[4] = 0;
        return;
    }

    userCode[0] = rxData[0];
    userCode[1] = rxData[1];
    userCode[2] = rxData[2];
    userCode[3] = rxData[3];
    userCode[4] = rxData[4];
}