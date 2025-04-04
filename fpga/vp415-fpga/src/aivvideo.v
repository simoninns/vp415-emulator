/************************************************************************
	
	aivvideo.v
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

module aivvideo (
    input sysClk,
    input nReset,
    input [2:0] sysClkPhase,

    input [2:0] rgb_111,
    input csync,

    input [9:0] pixelX_pi,
    input [9:0] pixelY_pi,
    input displayEnable_pi,

    // SRAM interface
    output [17:0] SRAM0_A,
    inout [15:0] SRAM0_D,
    output SRAM0_nCS,
    output SRAM0_nOE,
    output SRAM0_nWE,

    output [17:0] rgb_666, // 18-bit RGB666 output
);

    // -----------------------------------------------------------
    // PAL 576i hsync/vsync regeneration from incoming AIV composite sync
    wire hsync_aiv;
    wire vsync_aiv;
    wire isFieldOdd_aiv;

    sync_regenerator_pal576i sync_regenerator_pal576i0 (
        // Inputs
        .clk(sysClk),
        .csync(csync),

        // Outputs
        .hsync(hsync_aiv),
        .vsync(vsync_aiv),
        .isFieldOdd(isFieldOdd_aiv)
    );

    // -----------------------------------------------------------
    // Syncronize the incoming AIV async signals to the Pi's pixel clock
    // This is done using a 2-stage synchronizer to avoid metastability
    // issues.
    wire [2:0] rgb_sync_111;
    wire aiv_csyncIn_sync;

    sync_signals sync_signals0 (
        // Inputs (asynchronous)
        .clk(sysClk),
        .rgb_111(rgb_111),
        .csync(csync),

        // Outputs (synchronous to clk)
        .rgb_sync_111(rgb_sync_111),
        .csync_sync(aiv_csyncIn_sync)
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
    // Test card generator
    wire [2:0] rgb_testcard_111;

    testcard1bit testcard1bit0 (
        // Inputs
        .clk(sysClk),
        .nReset(nReset),
        .pixelX(pixelX_aiv),
        .pixelY(pixelY_aiv),
        .displayEnable(displayEnable_aiv),

        // Outputs
        .rgb_111(rgb_testcard_111)
    );

    // -----------------------------------------------------------
    // Frame buffer for the RGB111 signals
    wire [2:0] rgb_fb_111;

    // Start of frame flags
    wire startOfFrame_in;
    wire startOfFrame_out;

    assign startOfFrame_in = (pixelX_aiv == 10'd0 && pixelY_aiv == 10'd0 && displayEnable_aiv == 1'b1) ? 1'b1 : 1'b0;
    assign startOfFrame_out = (pixelX_pi == 10'd0 && pixelY_pi == 10'd0 && displayEnable_pi == 1'b1) ? 1'b1 : 1'b0;

    framebuffer framebuffer0 (
        // Inputs
        .clk(sysClk),
        .clkPhase(sysClkPhase),
        .reset_n(nReset),

        .display_en_in(displayEnable_aiv),
        .display_en_out(displayEnable_pi),

        .frame_start_flag_in(startOfFrame_in),
        .frame_start_flag_out(startOfFrame_out),

        //.rgb_111_in(rgb_sync_111),
        .rgb_111_in(rgb_testcard_111),
        .rgb_111_out(rgb_fb_111),
        
        // SRAM interface signals
        .sram_addr(SRAM0_A),
        .sram_data(SRAM0_D),
        .sram_ce_n(SRAM0_nCS),
        .sram_oe_n(SRAM0_nOE),
        .sram_we_n(SRAM0_nWE)
    );

    // -----------------------------------------------------------
    // Convert the RGB111 output to RGB666 and output to SCART
    rgb111to666 rgb111to6660 (
        // Inputs
        .clk(sysClk),
        .rgb_111(rgb_fb_111),

        // Outputs
        .rgb_666(rgb_666)
    );

endmodule