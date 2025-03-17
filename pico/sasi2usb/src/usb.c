/************************************************************************

    usb.c

    Raspberry Pico SASI2USB adapter
    VP415-Emulator
    Copyright (C) 2025 Simon Inns

    This file is part of VP415-Emulator.

    This is free software: you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Email: simon.inns@gmail.com

************************************************************************/

#include <stdio.h>
#include "pico/stdlib.h"

#include "usb.h"
#include "usb_eps.h"

void initialise_usb(void) {
    usb_device_init();

    // Wait until configured
    printf("Waiting for USB device configuration...\n");
    while (!isConfigured()) {
        sleep_ms(100);
    }
    printf("USB device configured\n");

    // Get ready to rx from host
    usb_start_transfer(usb_get_endpoint_configuration(EP1_OUT_ADDR), NULL, 64);
}