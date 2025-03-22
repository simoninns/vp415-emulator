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

// Global includes
#include <pico/stdlib.h>
#include <stdbool.h>
#include <stdio.h>

// Local includes
#include "debug.h"
#include "hostadapter.h"

// Timeout counter (used when interrupts are not available to ensure
// DMA read and writes do not hang the AVR waiting for host response
// Note: This is an unsigned 32 bit integer and should therefore be
// smaller than 4,294,967,295
#define TOC_MAX 100000

// Globals for the interrupt service routines
volatile bool nrstFlag = false;

// Interrupt service functions to handle host adapter input signals
// ---------------------

// Function to handle ReSeT signal interrupt
void nrst_isr(uint gpio, uint32_t events) {
    // Here we just set a flag to show the main code that the
    // ISR was serviced
    nrstFlag = true;
}

// Initialise the host adapter hardware (called on a cold-start of the AVR)
void hostadapterInitialise(void) {
    // Initialise the host adapter input/output pins
    gpio_init(NRST_PORT);
    gpio_init(NACK_PORT);
    gpio_init(NSEL_PORT);
    gpio_init(STATUS_NMSG_PORT);
    gpio_init(STATUS_NBSY_PORT);
    gpio_init(STATUS_NREQ_PORT);
    gpio_init(STATUS_INO_PORT);
    gpio_init(STATUS_CND_PORT);
    gpio_init(DATABUS_NDB0);
    gpio_init(DATABUS_NDB1);
    gpio_init(DATABUS_NDB2);
    gpio_init(DATABUS_NDB3);
    gpio_init(DATABUS_NDB4);
    gpio_init(DATABUS_NDB5);
    gpio_init(DATABUS_NDB6);
    gpio_init(DATABUS_NDB7);

    // Set the host adapter databus to input
    hostadapterDatabusInput();

    // Configure the status byte output pins to output

    // gpio_set_dir(GPIO0, GPIO_OUT);

    gpio_set_dir(STATUS_NMSG_PORT, GPIO_OUT);
    gpio_set_dir(STATUS_NBSY_PORT, GPIO_OUT);
    gpio_set_dir(STATUS_NREQ_PORT, GPIO_OUT);
    gpio_set_dir(STATUS_INO_PORT, GPIO_OUT);
    gpio_set_dir(STATUS_CND_PORT, GPIO_OUT);

    gpio_put(STATUS_NMSG_PORT, 1);  // Pin = 1 (inactive)
    gpio_put(STATUS_NBSY_PORT, 1);  // Pin = 1 (inactive)
    gpio_put(STATUS_NREQ_PORT, 1);  // Pin = 1 (inactive)
    gpio_put(STATUS_INO_PORT, 1);   // Pin = 1 (inactive)
    gpio_put(STATUS_CND_PORT, 1);   // Pin = 1 (inactive)

    // Configure the SCSI signal input pins to input
    gpio_set_dir(NRST_PORT, GPIO_IN);
    gpio_set_dir(NACK_PORT, GPIO_IN);
    gpio_set_dir(NSEL_PORT, GPIO_IN);

    // Set up an interrupt on the NRST_PORT if the port goes from 1 to 0
    gpio_set_irq_enabled_with_callback(NRST_PORT, GPIO_IRQ_EDGE_FALL, true,
                                       &nrst_isr);
}

// Reset the host adapter (called when the host signals reset)
void hostadapterReset(void) {
    // Set the host adapter databus to input
    hostadapterDatabusInput();

    // Turn off all host adapter signals
    gpio_put(STATUS_NMSG_PORT, 1);  // Pin = 1 (inactive)
    gpio_put(STATUS_NBSY_PORT, 1);  // Pin = 1 (inactive)
    gpio_put(STATUS_NREQ_PORT, 1);  // Pin = 1 (inactive)
    gpio_put(STATUS_INO_PORT, 1);   // Pin = 1 (inactive)
    gpio_put(STATUS_CND_PORT, 1);   // Pin = 1 (inactive)

    debugPrintf("Host adapter has been reset.\r\n");
}

// Databus manipulation functions
// -------------------------------------------------------

// Set the databus direction to input
inline void hostadapterDatabusInput(void) {
    gpio_set_dir(DATABUS_NDB0, GPIO_IN);
    gpio_set_dir(DATABUS_NDB1, GPIO_IN);
    gpio_set_dir(DATABUS_NDB2, GPIO_IN);
    gpio_set_dir(DATABUS_NDB3, GPIO_IN);
    gpio_set_dir(DATABUS_NDB4, GPIO_IN);
    gpio_set_dir(DATABUS_NDB5, GPIO_IN);
    gpio_set_dir(DATABUS_NDB6, GPIO_IN);
    gpio_set_dir(DATABUS_NDB7, GPIO_IN);
}

// Set the databus direction to output
inline void hostadapterDatabusOutput(void) {
    gpio_set_dir(DATABUS_NDB0, GPIO_OUT);
    gpio_set_dir(DATABUS_NDB1, GPIO_OUT);
    gpio_set_dir(DATABUS_NDB2, GPIO_OUT);
    gpio_set_dir(DATABUS_NDB3, GPIO_OUT);
    gpio_set_dir(DATABUS_NDB4, GPIO_OUT);
    gpio_set_dir(DATABUS_NDB5, GPIO_OUT);
    gpio_set_dir(DATABUS_NDB6, GPIO_OUT);
    gpio_set_dir(DATABUS_NDB7, GPIO_OUT);
}

// Read a byte from the databus (directly)
inline uint8_t hostadapterReadDatabus(void) {
    // Read the databus value and invert it
    uint8_t databusValue = 0;

    databusValue |= gpio_get(DATABUS_NDB0) << 0;
    databusValue |= gpio_get(DATABUS_NDB1) << 1;
    databusValue |= gpio_get(DATABUS_NDB2) << 2;
    databusValue |= gpio_get(DATABUS_NDB3) << 3;
    databusValue |= gpio_get(DATABUS_NDB4) << 4;
    databusValue |= gpio_get(DATABUS_NDB5) << 5;
    databusValue |= gpio_get(DATABUS_NDB6) << 6;
    databusValue |= gpio_get(DATABUS_NDB7) << 7;

    return ~databusValue;
}

// Write a byte to the databus (directly)
inline void hostadapterWritedatabus(uint8_t databusValue) {
    databusValue = ~databusValue;

    gpio_put(DATABUS_NDB0, (databusValue >> 0) & 1);
    gpio_put(DATABUS_NDB1, (databusValue >> 1) & 1);
    gpio_put(DATABUS_NDB2, (databusValue >> 2) & 1);
    gpio_put(DATABUS_NDB3, (databusValue >> 3) & 1);
    gpio_put(DATABUS_NDB4, (databusValue >> 4) & 1);
    gpio_put(DATABUS_NDB5, (databusValue >> 5) & 1);
    gpio_put(DATABUS_NDB6, (databusValue >> 6) & 1);
    gpio_put(DATABUS_NDB7, (databusValue >> 7) & 1);
}

// SCSI Bus action functions
// ------------------------------------------------------------

// Function to read a byte from the host (using REQ/ACK)
inline uint8_t hostadapterReadByte(void) {
    uint8_t databusValue = 0;

    // Set the REQuest signal
    gpio_put(STATUS_NREQ_PORT, 0);  // REQ = 0 (active)

    // Wait for ACKnowledge
    while ((gpio_get(NACK_PORT) != 0) && nrstFlag == false);

    // Clear the REQuest signal
    gpio_put(STATUS_NREQ_PORT, 1);  // REQ = 1 (inactive)

    // Read the databus value
    return hostadapterReadDatabus();
}

// Function to write a byte to the host (using REQ/ACK)
inline void hostadapterWriteByte(uint8_t databusValue) {
    // Write the byte of data to the databus
    hostadapterWritedatabus(databusValue);

    // Set the REQuest signal
    gpio_put(STATUS_NREQ_PORT, 0);  // REQ = 0 (active)

    // Wait for ACKnowledge
    while ((gpio_get(NACK_PORT) != 0) && nrstFlag == false);

    // Clear the REQuest signal
    gpio_put(STATUS_NREQ_PORT, 1);  // REQ = 1 (inactive)
}

// Host DMA transfer functions
// ----------------------------------------------------------

// Host reads data from SCSI device using DMA transfer (reads a 256 byte block)
// Returns number of bytes transferred (for debug in case of DMA failure)
uint16_t hostadapterPerformReadDMA(uint8_t *dataBuffer) {
    uint16_t currentByte = 0;
    uint32_t timeoutCounter = 0;

    // Loop to write bytes (unless a reset condition is detected)
    while (currentByte < 256 && timeoutCounter != TOC_MAX) {
        // Write the current byte to the databus and point to the next byte
        hostadapterWritedatabus(dataBuffer[currentByte++]);

        // Set the REQuest signal
        gpio_put(STATUS_NREQ_PORT, 0);  // REQ = 0 (active)

        // Wait for ACKnowledge
        timeoutCounter = 0;  // Reset timeout counter

        while ((gpio_get(NACK_PORT) != 0) != 0) {
            if (++timeoutCounter == TOC_MAX) {
                // Set the host reset flag and quit
                nrstFlag = true;
                return currentByte - 1;
            }
        }

        // Clear the REQuest signal
        gpio_put(STATUS_NREQ_PORT, 1);  // REQ = 1 (inactive)
    }

    return currentByte - 1;
}

// Host writes data to SCSI device using DMA transfer (writes a 256 byte block)
// Returns number of bytes transferred (for debug in case of DMA failure)
uint16_t hostadapterPerformWriteDMA(uint8_t *dataBuffer) {
    uint16_t currentByte = 0;
    uint32_t timeoutCounter = 0;

    // Loop to read bytes (unless a reset condition is detected)
    while (currentByte < 256 && timeoutCounter != TOC_MAX) {
        // Set the REQuest signal
        gpio_put(STATUS_NREQ_PORT, 0);  // REQ = 0 (active)

        // Wait for ACKnowledge
        timeoutCounter = 0;  // Reset timeout counter

        while ((gpio_get(NACK_PORT) != 0) != 0) {
            if (++timeoutCounter == TOC_MAX) {
                // Set the host reset flag and quit
                nrstFlag = true;
                return currentByte;
            }
        }

        // Read the current byte from the databus and point to the next byte
        dataBuffer[currentByte++] = hostadapterReadDatabus();

        // Clear the REQuest signal
        gpio_put(STATUS_NREQ_PORT, 1);  // REQ = 1 (inactive)
    }

    return currentByte - 1;
}

// Host adapter signal control and detection functions
// ------------------------------------

// Function to write the host reset flag
void hostadapterWriteResetFlag(bool flagState) { nrstFlag = flagState; }

// Function to return the state of the host reset flag
bool hostadapterReadResetFlag(void) { return nrstFlag; }

// Function to write the data phase flags and control databus direction
// Note: all SCSI signals are inverted logic
void hostadapterWriteDataPhaseFlags(bool message, bool commandNotData,
                                    bool inputNotOutput) {
    if (message)
        gpio_put(STATUS_NMSG_PORT, 0);  // MSG = active
    else
        gpio_put(STATUS_NMSG_PORT, 1);  // MSG = inactive

    if (commandNotData)
        gpio_put(STATUS_CND_PORT, 0);  //  CD = active
    else
        gpio_put(STATUS_CND_PORT, 1);  //  CD = inactive

    if (inputNotOutput) {
        gpio_put(STATUS_INO_PORT, 0);  //  IO = active
        hostadapterDatabusOutput();
    } else {
        gpio_put(STATUS_INO_PORT, 1);  //  IO = inactive
        hostadapterDatabusInput();
    }
}

// Function to write the host busy flag
// Note: all SCSI signals are inverted logic
void hostadapterWriteBusyFlag(bool flagState) {
    if (flagState)
        gpio_put(STATUS_NBSY_PORT, 0);  // BSY = inactive
    else
        gpio_put(STATUS_NBSY_PORT, 1);  // BSY = active
}

// Function to write the host request flag
// Note: all SCSI signals are inverted logic
void hostadapterWriteRequestFlag(bool flagState) {
    if (flagState)
        gpio_put(STATUS_NREQ_PORT, 0);  // REQ = inactive
    else
        gpio_put(STATUS_NREQ_PORT, 1);  // REQ = active
}

// Function to read the state of the host select flag
// Note: all SCSI signals are inverted logic
bool hostadapterReadSelectFlag(void) {
    // Check the state of the NSEL signal
    if (gpio_get(NSEL_PORT) != 0) return false;

    return true;
}