/************************************************************************
	
	beebthru.v
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

    // On-board inputs
    input [1:0] buttons,

    // Raspberry Pi GPIOs
    input [27:0] pi_gpio,

    // SCART RGB666 SCART output with composite sync
    output [5:0] red_scartOut,
    output [5:0] green_scartOut,
    output [5:0] blue_scartOut,
    output cSyncScart,

    // RGB111 DIN input with composite sync from BBC Master AIV
    input aivRedIn,
    input aivGreenIn,
    input aivBlueIn,
    input aivCSyncIn,

    // iCE40HX8K-EVB LEDs
    output [1:0] leds,

    // PicoScope MSO
    output [15:0] picoScope,
);

    // Initial test - output the csync to the picoscope
    assign picoScope[0] = aivCSyncIn;
    assign picoScope[1] = hsync;
    assign picoScope[2] = vsync;
    assign picoScope[15:3] = 0;

    // -----------------------------------------------------------
    // Csync separator

    wire hsync;
    wire vsync;

    sync_extractor sync_extractor0 (
        // Inputs
        .clk(clock100Mhz),
        .sync_in(aivCSyncIn),

        // Outputs
        .h_sync(hsync),
        .v_sync(vsync)
    );

    // -----------------------------------------------------------
    // Clock generation PLL

    // wire ref_clk;

    // csync_prescaler csync_prescaler0 (
    //     // Inputs
    //     .clk_100mhz(clock100Mhz),
    //     .csync(aivCSyncIn),

    //     // Outputs
    //     .pixel_clk(aivPixelClock),
    //     .ref_clk(ref_clk)
    // );

    // wire aivPixelClock;
    // wire ref_clk;

    // csync_to_pixel_clock csync_to_pixel_clock0 (
    //     // Inputs
    //     .clk_100mhz(clock100Mhz),
    //     .csync(aivCSyncIn),

    //     // Outputs
    //     .pixel_clk(aivPixelClock),
    //     .ref_clk(ref_clk)
    // );

    // -----------------------------------------------------------
    // Basic hardware functions

    // nReset signal generation (as the iCE40 board doesn't have one)
    // wire nReset;

    // nreset nreset0 (
    //     .sysClock(aivClockX6),
    //     .nReset(nReset)
    // );

    // // Status LED control
    // wire [1:0] leds;

    // statusleds statusleds0 (
    //     // Inputs
    //     .sysClock(aivClockX6),
    //     .nReset(nReset),
        
    //     // Outputs
    //     .leds(leds)
    // );

endmodule