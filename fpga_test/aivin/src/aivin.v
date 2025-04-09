/************************************************************************
	
	aivin.v
	Top module
	
	VP415-Emulator FPGA
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

// Disable Verilog implicit definitions
`default_nettype none

module top(
    // On-board clock
    input clock100Mhz,

    // iCE40HX8K-EVB LEDs
    output [1:0] leds,

    // PicoScope MSO
    output [15:0] picoScope,
);

    // -----------------------------------------------------------
    // Basic hardware functions

    // nReset signal generation (as the iCE40 board doesn't have one)
    wire nReset;

    nreset nreset0 (
        .sysClock(clock100Mhz),
        .nReset(nReset)
    );

    // Status LED control
    wire [1:0] leds;

    statusleds statusleds0 (
        // Inputs
        .sysClock(clock100Mhz),
        .nReset(nReset),
        
        // Outputs
        .leds(leds)
    );

endmodule