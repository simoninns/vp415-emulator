/************************************************************************

    fcode.c

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
#include "fcode.h"
#include "filesystem.h"

// Global SCSI (LV-DOS) F-Code buffer (256 bytes)
uint8_t scsiFcodeBuffer[256];

// Function to handle F-Code buffer write actions
void fcodeWriteBuffer(uint8_t lunNumber) {
    uint16_t fcodeLength = 0;
    uint16_t byteCounter;
    uint8_t userCode[5];

    // Clear the serial read buffer (as we are sending a new F-Code)
    // uartFlush(); // Flushes the UART Rx buffer

    // Output the F-Code bytes to debug
    if (debugFlag_scsiFcodes) debugPrintf("F-Code: Received bytes:");

    // Write out the buffer until a CR character is found
    for (byteCounter = 0; byteCounter < 256; byteCounter++) {
        if (debugFlag_scsiFcodes)
            debugPrintf(" %02X", scsiFcodeBuffer[byteCounter]);
        if (scsiFcodeBuffer[byteCounter] == 0x0D) break;
        fcodeLength++;
    }
    if (debugFlag_scsiFcodes) debugPrintf("\r\n");

    // F-Code decoding for debug output
    if (debugFlag_scsiFcodes) {
        // Display the F-Code command value
        debugPrintf("F-Code: Received F-Code %02X", scsiFcodeBuffer[0]);

        // Display the F-Code command function
        switch (scsiFcodeBuffer[0]) {
            case 0x21:  // !xy
                debugPrintf(" = Sound insert (beep)\r\n");
                break;

            case 0x23:  // #xy
                debugPrintf(" = RC-5 command out via A/V EUROCONNECTOR\r\n");
                break;

            case 0x24:  // $0, $1
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Replay switch disable\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Replay switch enable\r\n");
                        break;

                    default:
                        debugPrintf(" = Replay switch (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x27:  // '
                debugPrintf(" = Eject (open the front-loader tray)\r\n");
                break;

            case 0x29:  // )0, )1
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Transmission delay off\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Transmission delay on\r\n");
                        break;

                    default:
                        debugPrintf(
                            " = Transmission delay (invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x2A:  // *
                switch (scsiFcodeBuffer[1]) {
                    case 0x0D:
                        // No parameter, assume default
                        debugPrintf(" = Halt (still mode)\r\n");
                        break;

                    default:
                        debugPrintf(" = Repetitive halt and jump\r\n");
                        break;
                }
                break;

            case 0x2B:  // +
                debugPrintf(" = Instant jump forwards\r\n");
                break;

            case 0x2C:  // ,
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Standby (unload)\r\n");
                        break;

                    case '1':
                        debugPrintf(" = On (load)\r\n");
                        break;

                    default:
                        debugPrintf(" = Standby/On (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x2D:  // -
                debugPrintf(" = Instant jump backwards\r\n");
                break;

            case 0x2F:  // /
                debugPrintf(" = Pause (halt + all muted)\r\n");
                break;

            case 0x3A:  // :
                debugPrintf(" = Reset to default values\r\n");
                break;

            case 0x3F:  // ?
                switch (scsiFcodeBuffer[1]) {
                    case 'F':
                        debugPrintf(" = Picture number request\r\n");
                        break;

                    case 'C':
                        debugPrintf(" = Chapter number request\r\n");
                        break;

                    case 'D':
                        debugPrintf(" = Disc program status request\r\n");
                        break;

                    case 'P':
                        debugPrintf(" = Player status request\r\n");
                        break;

                    case 'U':
                        debugPrintf(" = User code request\r\n");
                        break;

                    case '=':
                        debugPrintf(" = Revision level request\r\n");
                        break;

                    default:
                        debugPrintf(" = Request (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x41:  // A0, A1
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Audio-1 off\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Audio-1 on\r\n");
                        break;

                    default:
                        debugPrintf(" = Audio-1 (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x42:  // B0, B1
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Audio-2 off\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Audio-2 on\r\n");
                        break;

                    default:
                        debugPrintf(" = Audio-2 (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x43:  // C0, C1
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Chapter number display off\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Chapter number display on\r\n");
                        break;

                    default:
                        debugPrintf(
                            " = Chapter number display (Invalid "
                            "parameter)\r\n");
                        break;
                }
                break;

            case 0x44:  // D0, D1
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(
                            " = Picture number/time code display off\r\n");
                        break;

                    case '1':
                        debugPrintf(
                            " = Picture number/time code display on\r\n");
                        break;

                    default:
                        debugPrintf(
                            " = Picture number/time code display (Invalid "
                            "parameter)\r\n");
                        break;
                }
                break;

            case 0x45:  // E
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Video off\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Video on\r\n");
                        break;

                    default:
                        debugPrintf(" = Video (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x46:  // F
                debugPrintf(" = Load/Goto picture number\r\n");
                break;

            case 0x48:  // H
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(
                            " = Remote control not routed to computer\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Remote control routed to computer\r\n");
                        break;

                    default:
                        debugPrintf(
                            " = Remote control routed (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x49:  // I
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(
                            " = Local front panel buttons disabled\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Local front panel buttons enabled\r\n");
                        break;

                    default:
                        debugPrintf(
                            " = Local front panel buttons (Invalid "
                            "parameter)\r\n");
                        break;
                }
                break;

            case 0x4A:  // J
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(
                            " = Remote control disabled for player "
                            "control\r\n");
                        break;

                    case '1':
                        debugPrintf(
                            " = Remote control enabled for player control\r\n");
                        break;

                    default:
                        debugPrintf(
                            " = Remote control for player control (Invalid "
                            "parameter)\r\n");
                        break;
                }
                break;

            case 0x4C:  // L
                debugPrintf(" = Still forward\r\n");
                break;

            case 0x4D:  // M
                debugPrintf(" = Still reverse\r\n");
                break;

            case 0x4E:  // N
                debugPrintf(" = Play forward\r\n");
                break;

            case 0x4F:  // O
                debugPrintf(" = Play reverse\r\n");
                break;

            case 0x51:  // Q
                debugPrintf(" = Goto chapter and halt/play\r\n");
                break;

            case 0x52:  // R
                debugPrintf(" = Slow/Fast read\r\n");
                break;

            case 0x53:  // S
                debugPrintf(" = Set fast/slow speed value\r\n");
                break;

            case 0x54:  // T
                debugPrintf(" = Goto/Load time code register\r\n");
                break;

            case 0x55:  // U
                debugPrintf(" = Slow motion forward\r\n");
                break;

            case 0x56:  // V, VP
                switch (scsiFcodeBuffer[1]) {
                    case 'P':
                        switch (scsiFcodeBuffer[2]) {
                            case '1':
                                debugPrintf(
                                    " = Video overlay mode 1 (LaserVision "
                                    "video only)\r\n");
                                break;

                            case '2':
                                debugPrintf(
                                    " = Video overlay mode 2 (External "
                                    "(computer) RGB only)\r\n");
                                break;

                            case '3':
                                debugPrintf(
                                    " = Video overlay mode 3 (Hard-keyed)\r\n");
                                break;

                            case '4':
                                debugPrintf(
                                    " = Video overlay mode 4 (Mixed)\r\n");
                                break;

                            case '5':
                                debugPrintf(
                                    " = Video overlay mode 5 (Enhanced)\r\n");
                                break;

                            case 'X':
                                debugPrintf(
                                    " = Video overlay mode request\r\n");
                                break;

                            default:
                                debugPrintf(
                                    " = Video overlay mode (Invalid "
                                    "parameter)\r\n");
                                break;
                        }
                        break;

                    case 0x0D:
                        debugPrintf(" = Slow motion reverse\r\n");
                        break;

                    default:
                        debugPrintf(
                            " = Slow motion reverse (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x57:  // W
                debugPrintf(" = Fast forward\r\n");
                break;

            case 0x58:  // X
                debugPrintf(" = Clear\r\n");
                break;

            case 0x5A:  // Z
                debugPrintf(" = Fast reverse\r\n");
                break;

            case 0x5B:  // [0, [1
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Audio-1 from internal\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Audio-1 from external\r\n");
                        break;

                    default:
                        debugPrintf(" = Audio-1 from (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x5C:  // '\'
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Video from internal\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Video from external\r\n");
                        break;

                    default:
                        debugPrintf(" = Video from (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x5D:  // ]0, ]1
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Audio-2 from internal\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Audio-2 from external\r\n");
                        break;

                    default:
                        debugPrintf(" = Audio-2 from (Invalid parameter)\r\n");
                        break;
                }
                break;

            case 0x5F:  // _0, _1
                switch (scsiFcodeBuffer[1]) {
                    case '0':
                        debugPrintf(" = Teletext from disc off\r\n");
                        break;

                    case '1':
                        debugPrintf(" = Teletext from disc on\r\n");
                        break;

                    default:
                        debugPrintf(
                            " = Teletext from disc (Invalid parameter)\r\n");
                        break;
                }
                break;

            default:
                debugPrintf("Unknown!\r\n");
                break;
        }
    }

    // If the F-Code is a user code request (?U), we need to send the user-code
    // via the UART (as this is the only way the external F-Code emulation can
    // know the right code to send back
    if (scsiFcodeBuffer[0] == 0x3F && scsiFcodeBuffer[1] == 0x55) {
        // Get the user code for the target LUN
        filesystemReadLunUserCode(lunNumber, userCode);

        printf("<UCD>");
        for (byteCounter = 0; byteCounter < 5; byteCounter++)
            printf("%c", userCode[byteCounter]);
        printf("</UCD>\r\n");
    }

    // Send the F-Code to the serial UART
    // printf("<FCODE>");
    // for (byteCounter = 0; byteCounter < fcodeLength; byteCounter++)
    // 	printf("%c", scsiFcodeBuffer[byteCounter]);
    // printf("</FCODE>\r\n");
}

// Function to copy the UART serial buffer into the fcodeBuffer
void fcodeReadBuffer(void) {
    uint16_t byteCounter = 0;
    uint16_t availableBytes = 0;

    // Clear the F-code buffer
    for (byteCounter = 0; byteCounter < 256; byteCounter++)
        scsiFcodeBuffer[byteCounter] = 0;

    // Get the number of available bytes in the UART Rx buffer
    // availableBytes = uartAvailable();

    // if (debugFlag_scsiFcodes) debugPrintf("F-Code: Serial UART bytes waiting
    // = %d\r\n", availableBytes);

    // // Ensure we have a full F-code response terminated with
    // // 0x0D (CR) before we send it to the host
    // if (uartPeekForString()) {
    // 	if (debugFlag_scsiFcodes) debugPrintf("F-Code: Transmitting F-Code
    // bytes: ");

    // 	// Copy the UART Rx buffer to the F-Code buffer
    // 	for (byteCounter = 0; byteCounter < availableBytes; byteCounter++) {
    // 		scsiFcodeBuffer[byteCounter] = (char)(uartRead() & 0xFF);
    // 		if (debugFlag_scsiFcodes) debugPrintf(" %02X",
    // scsiFcodeBuffer[byteCounter]);
    // 	}
    // 	if (debugFlag_scsiFcodes) debugPrintf("\r\n");
    // }
    // // If there is nothing to send we should reply with only a CR according
    // // to page 40 of the VP415 operating instructions (C8H Read F-code reply)
    // else {
    // 	if (debugFlag_scsiFcodes) debugPrintf("F-Code: No response from host;
    // sending empty CR terminated response.\r\n"); 	scsiFcodeBuffer[0] = 0x0D;
    // }

    if (debugFlag_scsiFcodes)
        debugPrintf(
            "F-Code: No response from host; sending empty CR terminated "
            "response.\r\n");
    scsiFcodeBuffer[0] = 0x0D;
}