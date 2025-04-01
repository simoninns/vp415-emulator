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
    assign picoScope[0] = 0;
    assign picoScope[1] = 0;
    assign picoScope[2] = 0;
    assign picoScope[3] = 0;
    assign picoScope[4] = 0;
    assign picoScope[5] = 0;
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
    // Pi5 Pixel clock generation PLL

    // We use the Pi's DPI pixel clock as a base and multiply it
    // by 6 (=81 MHz). This is to keep everything in phase with
    // the Pi 5's pixel clock.
    wire pixelClock_pi;
    assign pixelClock_pi = pi_gpio[0];

    wire sysClk;
    wire [2:0] sysClkPhase;

    pipixelclockpll pipixelclockpll0 (
        // Inputs
        .pixelClockIn(pixelClock_pi),
        
        // Outputs
        .pixelClockX6_out(sysClk),
        .pixelClockPhase(sysClkPhase)
    );

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
    wire [5:0] red_pi;   // Red video from Pi (6-bit mapped to 8-bit)
    wire [5:0] green_pi; // Green video from Pi (6-bit mapped to 8-bit)
    wire [5:0] blue_pi;  // Blue video from Pi (6-bit mapped to 8-bit)

    wire vsync_pi;
    wire hsync_pi;
    wire displayEnable_pi;

    assign red_pi[5:0] = pi_gpio[21:16]; // Red
    assign green_pi[5:0] = pi_gpio[15:10]; // Green
    assign blue_pi[5:0] = pi_gpio[9:4]; // Blue 

    assign vsync_pi = pi_gpio[2];
    assign hsync_pi = pi_gpio[3];
    assign pixelClock_pi = pi_gpio[0];
    assign displayEnable_pi = pi_gpio[1];

    // -----------------------------------------------------------
    // Track the frame line and dot from the Pi
    wire [9:0] pixelX_pi;
    wire [9:0] pixelY_pi;
    wire isFieldOdd_pi;

    pi_tracker pi_tracker0 (
        // Inputs
        .pixelClockX6(sysClk),
        .pixelClockPhase(sysClkPhase),
        .nReset(nReset),
        .hsync_pi(hsync_pi),
        .vsync_pi(vsync_pi),
        .displayEnabled_pi(displayEnable_pi),

        // Outputs
        .fieldLineDot_pi(pixelX_pi),
        .frameLine_pi(pixelY_pi),
        .isFieldOdd_pi(isFieldOdd_pi)
    );

    // -----------------------------------------------------------
    // Syncronize the incoming AIV async signals to the Pi's pixel clock
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
    wire hsync_aiv;
    wire vsync_aiv;
    wire isFieldOdd_aiv;

    sync_regenerator_pal576i sync_regenerator_pal576i0 (
        // Inputs
        .clk(sysClk),
        .csync(aiv_csyncIn_sync),

        // Outputs
        .hsync(hsync_aiv),
        .vsync(vsync_aiv),
        .isFieldOdd(isFieldOdd_aiv)
    );

    // -----------------------------------------------------------
    // Generate AIV pixel x,y and display enable signals
    wire [9:0] pixelX_aiv;
    wire [9:0] pixelY_aiv;
    wire displayEnable_aiv; // Active high when in the active display area

    aiv_active_frame_tracker aiv_active_frame_tracker0 (
        // Inputs
        .clk(sysClk),
        .nReset(nReset),
        .hsync(hsync_aiv),
        .vsync(vsync_aiv),
        .isFieldOdd(isFieldOdd_aiv),

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
    // Frame buffer for the RGB111 signals

    wire redOut_aivfb;
    wire greenOut_aivfb;
    wire blueOut_aivfb;

    wire [2:0] rgb111_in;
    //assign rgb111_in = {redOut_tc, greenOut_tc, blueOut_tc};
    assign rgb111_in = {aiv_redIn_sync, aiv_greenIn_sync, aiv_blueIn_sync};
    wire [2:0] rgb111_out;
    assign {redOut_aivfb, greenOut_aivfb, blueOut_aivfb} = rgb111_out;

    wire startOfFrame_pi;
    assign startOfFrame_pi = (pixelY_pi == 0) && (pixelX_pi == 0) && (displayEnable_pi == 1);

    wire startOfFrame_aiv;
    assign startOfFrame_aiv = (pixelY_aiv == 0) && (pixelX_aiv == 0) && (displayEnable_aiv == 1);

    framebuffer framebuffer0 (
        // Inputs
        .clk(sysClk),
        .clkPhase(sysClkPhase),
        .reset_n(nReset),

        .reset_in(startOfFrame_aiv),
        .reset_out(startOfFrame_pi),

        //.reset_in(1'b0),
        //.reset_out(1'b0),

        .data_in_en(displayEnable_aiv),
        .data_out_en(displayEnable_pi),

        .data_in(rgb111_in),

        // Outputs
        .data_out(rgb111_out),
        
        // SRAM interface signals
        .sram_addr(SRAM0_A),
        .sram_data(SRAM0_D),
        .sram_ce_n(SRAM0_nCS),
        .sram_oe_n(SRAM0_nOE),
        .sram_we_n(SRAM0_nWE)
    );

    // -----------------------------------------------------------
    // Convert the RGB111 output to RGB666 and output to SCART
    wire [5:0] redOut_aivfb_666;
    wire [5:0] greenOut_aivfb_666;
    wire [5:0] blueOut_aivfb_666;

    rgb111to666 rgb111to6660 (
        // Inputs
        .clk(sysClk),
        .red_in(redOut_aivfb),
        .green_in(greenOut_aivfb),
        .blue_in(blueOut_aivfb),

        // Outputs
        .red_out(redOut_aivfb_666),
        .green_out(greenOut_aivfb_666),
        .blue_out(blueOut_aivfb_666),
    );

    // -----------------------------------------------------------
    // Generate the composite sync signal for the SCART output
    // locked to the Pi5 video
    csyncgenerator csyncgenerator0 (
        // Inputs
        .clk(sysClk),
        .hsync(hsync_pi),
        .vsync(vsync_pi),

        // Outputs
        .csync(csync_scartOut)
    );

    // -----------------------------------------------------------
    // Video mixer (RGB666)
    videomixer videomixer0 (
        .pixelClockX6(sysClk),
        .pixelClockPhase(sysClkPhase),
        .nReset(nReset),

        // The AIV video is the foreground
        .red_fg(redOut_aivfb_666),
        .green_fg(greenOut_aivfb_666),
        .blue_fg(blueOut_aivfb_666),

        // The Pi video is the background
        .red_bg(red_pi),
        .green_bg(green_pi),
        .blue_bg(blue_pi),

        // .red_bg(6'b0),
        // .green_bg(6'b0),
        // .blue_bg(6'b0),

        // Video output
        .red_out(red_scartOut),
        .green_out(green_scartOut),
        .blue_out(blue_scartOut)
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