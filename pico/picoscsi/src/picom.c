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

bool picomSendToPi(uint8_t *txData, uint8_t txLength, uint8_t *rxData, uint8_t rxLength) {
    // Send the txData
    for (uint8_t i = 0; i < txLength; i++) {
        uart_putc_raw(uart1, txData[i]);
    }

    // Wait for the rxData
    absolute_time_t timeout = make_timeout_time_ms(5000);
    for (uint8_t i = 0; i < rxLength; i++) {
        while (!uart_is_readable_within_us(uart1, 1000)) {
            if (get_absolute_time() > timeout) {
                return false; // Timeout
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

    if (!picomSendToPi(txData, 1, rxData, 1)) return PIR_TIMEOUT;

    if (rxData[0] == 0) return PIR_FALSE;
    return PIR_TRUE;
}

// Mounts the file system
uint8_t picomSetMountState(bool mountState) {
    uint8_t txData[2] = {PIC_SET_MOUNT_STATE, mountState};
    uint8_t rxData[1];

    if (!picomSendToPi(txData, 2, rxData, 1)) return PIR_TIMEOUT;

    if (rxData[0] == 0) return PIR_FALSE;
    return PIR_TRUE;
}
