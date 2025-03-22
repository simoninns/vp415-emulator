/************************************************************************

    main.c

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
#include "filesystem.h"
#include "hostadapter.h"
#include "scsi.h"
#include "statusled.h"
#include "picom.h"

int main(void) {
    // Initilalise the debug output
    debugInitialise();

    // Initialise the host adapter interface
    hostadapterInitialise();

    // Initialise the Pi 5 communication interface
    picomInitialise();

    // Initialise the filesystem functions
    filesystemInitialise();

    // Initialise the status LED
    statusledInitialise();

    // Initialise the SCSI emulation
    scsiInitialise();

    // Main processing loop
    while (1) {
        // Process the SCSI emulation
        scsiProcessEmulation();

        // Did the host reset?
        if (hostadapterReadResetFlag()) {
            // Reset the host adapter
            hostadapterReset();

            // Reset the file system
            filesystemReset();

            // Reset the status LED
            statusledReset();

            // Reset the SCSI emulation
            scsiReset();

            // Clear the reset condition in the host adapter
            hostadapterWriteResetFlag(false);
        }
    }
}
