/************************************************************************

    statusled.c

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
#include "statusled.h"

// Initialise status LED
void statusledInitialise(void) {
    // Initialize the onboard LED on GPIO25
    gpio_init(25);
    gpio_set_dir(25, GPIO_OUT);

    statusledActivity(0);
}

// Reset the status LED
void statusledReset(void) { gpio_put(25, 0); }

// Show activity using the status LED
void statusledActivity(uint8_t state) {
    if (state == 0)
        gpio_put(25, 0);
    else
        gpio_put(25, 1);
}