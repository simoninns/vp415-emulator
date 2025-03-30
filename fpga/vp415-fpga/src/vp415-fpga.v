/************************************************************************
	
	vp415-fpga.v
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
    // Raspberry Pi GPIOs
    input [27:0] pi_gpio,

    // SCART RGB666 SCART output with composite sync
    output [5:0] red_scartOut,
    output [5:0] green_scartOut,
    output [5:0] blue_scartOut,
    output csync_scartOut,

    // RGB111 DIN input with composite sync from BBC Master AIV
    input aiv_redIn,
    input aiv_greenIn,
    input aiv_blueIn,
    input aiv_csyncIn,

    // iCE40HX8K-EVB LEDs
    output [1:0] leds,

    // PicoScope MSO
    output [15:0] picoScope,

    // Samsung K6R4016V1D-TC10 512K SRAM 
    output [17:0] SRAM0_A,
    inout [15:0] SRAM0_D,
    output SRAM0_nOE,
    output SRAM0_nWE,
    output SRAM0_nCS
);

    // -----------------------------------------------------------
    // Picoscope debug output mapping
    assign picoScope[0] = csync_scartOut;
    assign picoScope[1] = isFieldOdd;
    assign picoScope[2] = displayEnable_aiv;
    assign picoScope[3] = redOut;
    assign picoScope[4] = greenOut;
    assign picoScope[5] = blueOut;
    assign picoScope[6] = 0;
    assign picoScope[7] = 0;
    assign picoScope[8] = 0;
    assign picoScope[9] = 0;
    assign picoScope[10] = 0;
    assign picoScope[11] = 0;
    assign picoScope[12] = 0;
    assign picoScope[13] = 0;
    assign picoScope[14] = 0;
    assign picoScope[15] = 0;

    // -----------------------------------------------------------
    // SRAM framebuffer
    // framebuffer framebuffer0 (
    //     // Inputs
    //     .clk(sysClk),
    //     .nReset(nReset),

    //     // Outputs
    //     .SRAM0_A(SRAM0_A),
    //     .SRAM0_D(SRAM0_D),
    //     .SRAM0_nOE(SRAM0_nOE),
    //     .SRAM0_nWE(SRAM0_nWE),
    //     .SRAM0_nCS(SRAM0_nCS)
    // );


    // -----------------------------------------------------------
    // Pi5 Pixel clock generation PLL

    // We use the Pi's DPI pixel clock as a base and multiply it
    // by 6 (=81 MHz).  The module also produces a /6 enable signal running
    // at the original pixel clock's rate.  This is to keep everything
    // in phase with the Pi 5's pixel clock.
    wire pixelClock_piIn;
    assign pixelClock_piIn = pi_gpio[0];

    wire sysClk;
    wire pixelClockX1_en;

    pipixelclockpll pipixelclockpll0 (
        // Inputs
        .pixelClockIn(pixelClock_piIn),
        
        // Outputs
        .pixelClockX6_out(sysClk),
        .pixelClockX1_en(pixelClockX1_en)
    );

    // -----------------------------------------------------------
    // Syncronize the incoming async signals to the Pi's pixel clock
    // This is done using a 2-stage synchronizer to avoid metastability
    // issues.
    wire aiv_redIn_sync;
    wire aiv_greenIn_sync;
    wire aiv_blueIn_sync;
    wire aiv_csyncIn_sync;

    sync_signals sync_signals0 (
        // Inputs (asynchronous)
        .clk(sysClk),
        .red(aiv_redIn),
        .green(aiv_greenIn),
        .blue(aiv_blueIn),
        .csync(aiv_csyncIn),

        // Outputs (synchronous to clk)
        .red_sync(aiv_redIn_sync),
        .green_sync(aiv_greenIn_sync),
        .blue_sync(aiv_blueIn_sync),
        .csync_sync(aiv_csyncIn_sync)
    );

    // -----------------------------------------------------------
    // PAL 576i hsync/vsync regeneration from incoming AIV composite sync
    wire hsync;
    wire vsync;
    wire isFieldOdd;

    sync_regenerator_pal576i sync_regenerator_pal576i0 (
        // Inputs
        .clk(sysClk),
        .csync(aiv_csyncIn_sync),

        // Outputs
        .hsync(hsync),
        .vsync(vsync),
        .isFieldOdd(isFieldOdd)
    );

    // -----------------------------------------------------------
    // Generate AIV pixel x,y and display enable signals
    wire [9:0] pixelX_aiv;
    wire [9:0] pixelY_aiv;
    wire displayEnable_aiv; // Active high when in the active display area

    active_frame_tracker active_frame_tracker0 (
        // Inputs
        .clk(sysClk),
        .nReset(nReset),
        .hsync(hsync),
        .vsync(vsync),
        .isFieldOdd(isFieldOdd),

        // Outputs
        .active_frame_dot(pixelX_aiv),
        .active_frame_line(pixelY_aiv),
        .display_enable(displayEnable_aiv)
    );

    // -----------------------------------------------------------
    // Generate a RGB111 test card
    wire redOut_tc;
    wire greenOut_tc;
    wire blueOut_tc;

    testcard1bit testcard1bit0 (
        // Inputs
        .clk(sysClk),
        .nReset(nReset),
        .pixelX(pixelX_aiv),
        .pixelY(pixelY_aiv),
        .displayEnable(displayEnable_aiv),

        // Outputs
        .redOut(redOut_tc),
        .greenOut(greenOut_tc),
        .blueOut(blueOut_tc)
    );

    // -----------------------------------------------------------
    // Mix the test card and AIV RGB111 signals together
    wire redOut;
    wire greenOut;
    wire blueOut;

    videomixer videomixer0 (
        // Inputs
        .clk(sysClk),
        .nReset(nReset),

        .redIn1(redOut_tc),
        .greenIn1(greenOut_tc),
        .blueIn1(blueOut_tc),

        .redIn0(aiv_redIn_sync),
        .greenIn0(aiv_greenIn_sync),
        .blueIn0(aiv_blueIn_sync),

        // Outputs
        .redOut(redOut),
        .greenOut(greenOut),
        .blueOut(blueOut)
    );

    // -----------------------------------------------------------
    // Convert the test card RGB111 to RGB666 and output to SCART
    rgb111to666 rgb111to6660 (
        // Inputs
        .clk(sysClk),
        .red_in(redOut),
        .green_in(greenOut),
        .blue_in(blueOut),

        // Outputs
        .red_out(red_scartOut),
        .green_out(green_scartOut),
        .blue_out(blue_scartOut),
    );

    // -----------------------------------------------------------
    // Generate the composite sync signal for the SCART output
    csyncgenerator csyncgenerator0 (
        // Inputs
        .clk(sysClk),
        .hsync(hsync),
        .vsync(vsync),

        // Outputs
        .csync(csync_scartOut)
    );

    // -----------------------------------------------------------
    // nReset signal generation (as the iCE40 board doesn't have one)
    wire nReset;

    nreset nreset0 (
        .sysClock(sysClk),
        .nReset(nReset)
    );

    // -----------------------------------------------------------
    // Status LED - Flashes the LEDs to show we are running and
    // clock is present
    statusleds statusleds0 (
        // Inputs
        .sysClock(sysClk),
        .nReset(nReset),
        
        // Outputs
        .leds(leds)
    );

endmodule