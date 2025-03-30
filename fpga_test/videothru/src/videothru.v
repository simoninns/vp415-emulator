/************************************************************************
	
	videothru.v
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
    // On-board inputs
    input [1:0] buttons,

    // Raspberry Pi GPIOs
    input [27:0] pi_gpio,

    // SCART RGB666 SCART output with composite sync
    output [5:0] red_scartOut,
    output [5:0] green_scartOut,
    output [5:0] blue_scartOut,
    output cSyncScart,

    // RGB111 DIN input with composite sync
    input redIn,
    input greenIn,
    input blueIn,
    input cSyncIn,

    // iCE40HX8K-EVB LEDs
    output [1:0] leds,

    // PicoScope MSO
    output [15:0] picoScope,
);
    // -----------------------------------------------------------
    // Clock generation PLL

    // We use the Pi's DPI pixel clock as a base and multiply it
    // by 6.  The module also produces a /6 enable signal running
    // at the original pixel clock's rate.
    wire pixelClock_piIn;
    assign pixelClock_piIn = pi_gpio[0];

    wire pixelClock;
    wire pixelClockX6;
    wire pixelClockX1_en;

    pixelclockpll pixelclockpll0 (
        // Inputs
        .pixelClockIn(pixelClock_piIn),
        
        // Outputs
        .pixelClockX6_out(pixelClockX6),
        .pixelClockX1_en(pixelClockX1_en)
    );

    // -----------------------------------------------------------
    // Basic hardware functions

    // nReset signal generation (as the iCE40 board doesn't have one)
    wire nReset;

    nreset nreset0 (
        .sysClock(pixelClockX6),
        .nReset(nReset)
    );

    // Status LED control
    wire [1:0] leds;

    statusleds statusleds0 (
        // Inputs
        .sysClock(pixelClockX6),
        .nReset(nReset),
        
        // Outputs
        .leds(leds)
    );

    // -----------------------------------------------------------
    // Odd/Even Field tracker
    wire isFieldOdd_pi;

    fieldTracker fieldTracker0 (
        .pixelClockX6(pixelClockX6),
        .pixelClockX1_en(pixelClockX1_en),
        .nReset(nReset),
        .vSync(vSync_piIn),
        .hSync(hSync_piIn),
        
        .isFieldOdd(isFieldOdd_pi)
    );

    // -----------------------------------------------------------
    // Frame tracker
    wire [9:0] frameLine_pi;

    frameTracker frameTracker0 (
        .pixelClockX6(pixelClockX6),
        .pixelClockX1_en(pixelClockX1_en),
        .nReset(nReset),
        .fieldLine(fieldLine_pi),
        .isFieldOdd(isFieldOdd_pi),
        
        .frameLine(frameLine_pi)
    );

    // -----------------------------------------------------------
    // Line and dot tracker
    wire [9:0] fieldLine_pi;
    wire [9:0] fieldLineDot_pi;

    linetracker linetracker0 (
        .pixelClockX6(pixelClockX6),
        .pixelClockX1_en(pixelClockX1_en),
        .nReset(nReset),
        .displayEnabled(displayEnabled_piIn),
        .vSync(vSync_piIn),
        
        .fieldLine(fieldLine_pi),
        .fieldLineDot(fieldLineDot_pi),
    );

    assign picoScope[0] = pixelClock_piIn;
    assign picoScope[1] = vSync_piIn;
    assign picoScope[15:2] = 0;

    // -----------------------------------------------------------
    // Incoming video from the Raspberry Pi
    // Note: Using video mode 6 (RGB666):
    //
    // Used GPIOs:
    //
    // 16-21 Red
    // 10-15 Green
    // 4-9 Blue
    //
    // 2 VSync
    // 3 HSync
    //
    // 0 Pixel clock (DPICLK)
    // 1 Display enable (DPIDE)

    // DPI video input signals from the Raspberry Pi's DPI video interface
    wire [5:0] red_piIn;   // Red video from Pi (6-bit mapped to 8-bit)
    wire [5:0] green_piIn; // Green video from Pi (6-bit mapped to 8-bit)
    wire [5:0] blue_piIn;  // Blue video from Pi (6-bit mapped to 8-bit)

    wire vSync_piIn;
    wire hSync_piIn;
    wire displayEnabled_piIn;

    assign red_piIn[5:0] = pi_gpio[21:16]; // Red
    assign green_piIn[5:0] = pi_gpio[15:10]; // Green
    assign blue_piIn[5:0] = pi_gpio[9:4]; // Blue 

    assign vSync_piIn = pi_gpio[2];
    assign hSync_piIn = pi_gpio[3];
    assign pixelClock_piIn = pi_gpio[0];
    assign displayEnabled_piIn = pi_gpio[1];

    // -----------------------------------------------------------
    // Generate test card
    wire [5:0] red_tcIn;
    wire [5:0] green_tcIn;
    wire [5:0] blue_tcIn;

    testcard576i testcard576i0 (
        .pixelClockX6(pixelClockX6),
        .pixelClockX1_en(pixelClockX1_en),
        .nReset(nReset),
        .frameLine(frameLine_pi),
        .fieldLineDot(fieldLineDot_pi),

        .redOut(red_tcIn),
        .greenOut(green_tcIn),
        .blueOut(blue_tcIn)
    );

    // -----------------------------------------------------------
    // Sync combiner (H and V syncs from Pi into SCART composite sync)
    synccombiner synccombiner0 (
        // Inputs
	    .hSync(hSync_piIn),
	    .vSync(vSync_piIn),

        .cSync(cSyncScart)
    );

    // -----------------------------------------------------------
    // Video mixer
    videomixer videomixer0 (
        .pixelClockX6(pixelClockX6),
        .pixelClockX1_en(pixelClockX1_en),
        .nReset(nReset),

        .redIn0(red_piIn),
        .greenIn0(green_piIn),
        .blueIn0(blue_piIn),

        .redIn1(red_tcIn),
        .greenIn1(green_tcIn),
        .blueIn1(blue_tcIn),

        .redOut(red_scartOut),
        .greenOut(green_scartOut),
        .blueOut(blue_scartOut)
    );

endmodule
