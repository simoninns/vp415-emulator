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
    input aiv_redIn,
    input aiv_greenIn,
    input aiv_blueIn,
    input aiv_cSyncIn,

    // iCE40HX8K-EVB LEDs
    output [1:0] leds,

    // PicoScope MSO
    output [15:0] picoScope,
);

    // Initial test - output the csync to the picoscope
    assign picoScope[0] = aiv_cSyncIn;
    assign picoScope[1] = hsync_out;
    assign picoScope[2] = vsync_out;
    assign picoScope[3] = pixelClockX6_out;
    assign picoScope[4] = pixelClockX1_en;
    assign picoScope[15:5] = 0;

    // -----------------------------------------------------------
    // Pixel clock generation PLL

    // We use the Pi's DPI pixel clock as a base and multiply it
    // by 10.  The module also produces a /6 enable signal running
    // at the original pixel clock's rate.
    wire pixelClock_piIn;
    assign pixelClock_piIn = pi_gpio[0];

    wire pixelClock;
    wire pixelClockX6_out;
    wire pixelClockX1_en;

    pixelclockpll pixelclockpll0 (
        // Inputs
        .pixelClockIn(pixelClock_piIn),
        
        // Outputs
        .pixelClockX6_out(pixelClockX6_out),
        .pixelClockX1_en(pixelClockX1_en)
    );

    // -----------------------------------------------------------
    // Csync to Hsync separator
    wire hsync_out;

    hsync_separator hsync_separator0 (
        // Inputs
        .clk(pixelClockX6_out),
        .comp_sync(aiv_cSyncIn),

        // Outputs
        .hsync_out(hsync_out)
    );

    // -----------------------------------------------------------
    // Csync to Vsync separator
    wire vsync_out;

    vsync_separator vsync_separator0 (
        // Inputs
        .clk(pixelClockX6_out),
        .comp_sync(aiv_cSyncIn),

        // Outputs
        .vsync_out(vsync_out)
    );

    // -----------------------------------------------------------
    // Clock generation PLL

    // wire pixel_clk;

    // aiv_pixelclk_pll aiv_pixelclk_pll0 (
    //     // Inputs
    //     .hsync_clk(hsync_out),

    //     // Outputs
    //     .pixel_clk(pixel_clk)
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