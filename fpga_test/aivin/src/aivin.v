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
    // Raspberry Pi 5 GPIOs
    input [27:0] pi_gpio,

    // RGB111 DIN input with composite sync from BBC Master AIV
    input [2:0] aiv_rgb_111,
    input aiv_csync,

    // iCE40HX8K-EVB LEDs
    output [1:0] evb_leds,

    // Picoscope MSO debug
    output [15:0] picoscope,

    // Samsung K6R4016V1D-TC10 512K SRAM 
    output [17:0] SRAM0_A,
    inout [15:0] SRAM0_D,
    output SRAM0_nOE,
    output SRAM0_nWE,
    output SRAM0_nCS,

    // SCART RGB666 SCART output with composite sync
    output [17:0] scart_rgb_666,
    output scart_csync,
);

    // Pi 5 DPI video input signals
    wire pi_display_en; // Active high when in the active display area
    assign pi_display_en = pi_gpio[1];

    wire [17:0] pi_rgb_666; // RGB666 pixel data from the Pi 5
    assign pi_rgb_666[17:0] = {pi_gpio[21:16], pi_gpio[15:10], pi_gpio[9:4]};

    wire pi_hsync; // Horizontal sync signal from the Pi 5
    wire pi_vsync; // Vertical sync signal from the Pi 5
    assign pi_hsync = pi_gpio[3];
    assign pi_vsync = pi_gpio[2];

    // -----------------------------------------------------------
    // Status LED control
    status_leds status_leds0 (
        // Inputs
        .clk(clk),
        
        // Outputs
        .leds(evb_leds)
    );

    // -----------------------------------------------------------
    // Pixel clock PLL
    wire clk;
    wire [2:0] clk_phase;

    pi_pixel_clock_pll pi_pixel_clock_pll0 (
        // Inputs
        .clk(pi_gpio[0]),
        
        // Outputs
        .clk_out(clk),
        .clk_out_phase(clk_phase)
    );

    // -----------------------------------------------------------
    // Synchronize async AIV input signals to the system clock
    wire [2:0] aiv_rgb_111_sync;
    wire aiv_csync_sync;
    aiv_input_sync aiv_input_sync0 (
        // Inputs
        .clk(clk),
        .rgb_111(aiv_rgb_111),
        .csync(aiv_csync),
        
        // Outputs
        .rgb_111_sync(aiv_rgb_111_sync),
        .csync_sync(aiv_csync_sync)
    );

    // -----------------------------------------------------------
    // Separate the sync signals
    wire aiv_hsync;
    wire aiv_vsync;
    wire aiv_odd_field;
    aiv_sync_separator aiv_sync_separator0 (
        // Inputs
        .clk(clk),
        .csync(aiv_csync_sync),
        
        // Outputs
        .hsync(aiv_hsync),
        .vsync(aiv_vsync),
        .odd_field(aiv_odd_field)
    );

    // -----------------------------------------------------------
    // AIV pixel tracker
    wire [9:0] aiv_pixel_x;
    wire [9:0] aiv_pixel_y;
    wire aiv_pixel_ce;

    aiv_pixel_tracker aiv_pixel_tracker0 (
        // Inputs
        .clk(clk),
        .hsync(aiv_hsync),
        .vsync(aiv_vsync),
        .odd_field(aiv_odd_field),
        
        // Outputs
        .pixel_ce(aiv_pixel_ce),
        .pixel_x(aiv_pixel_x),
        .pixel_y(aiv_pixel_y)
    );

    // -----------------------------------------------------------
    // AIV Frame start flag
    wire aiv_frame_start;

    pal_framestart aiv_framestart0 (
        // Inputs
        .clk(clk),
        .pixel_ce(aiv_pixel_ce),
        .pixel_x(aiv_pixel_x),
        .pixel_y(aiv_pixel_y),
        
        // Outputs
        .frame_start(aiv_frame_start)
    );

    // -----------------------------------------------------------
    // AIV framebuffer
    wire [2:0] aiv_rgb_111_fb_out;

    aiv_framebuffer aiv_framebuffer0 (
        // Inputs
        .clk(clk),
        .clk_phase(clk_phase),
        .pixel_ce_in(aiv_pixel_ce),
        .frame_start_flag_in(aiv_frame_start),
        .pixel_ce_out(pi_pixel_ce),
        .frame_start_flag_out(pi_frame_start),
        //.rgb_111_in(aiv_rgb_111_sync),
        .rgb_111_in(test_rgb_111),
        .rgb_111_out(aiv_rgb_111_fb_out),

        .sram_addr(SRAM0_A),
        .sram_data(SRAM0_D),
        .sram_ce_n(SRAM0_nCS),
        .sram_oe_n(SRAM0_nOE),
        .sram_we_n(SRAM0_nWE),
    );

    // -----------------------------------------------------------
    // Convert the AIV RGB to RGB666
    wire [17:0] aiv_rgb_666_fb_out;

    aiv_to_rgb666 aiv_to_rgb6660 (
        // Inputs
        .clk(clk),
        .rgb_111(aiv_rgb_111_fb_out),
        //.rgb_111(test_rgb_111),
        
        // Outputs
        .rgb_666(aiv_rgb_666_fb_out)
    );

    // -----------------------------------------------------------
    // Pi5 pixel tracker
    wire [9:0] pi_pixel_x;
    wire [9:0] pi_pixel_y;
    wire pi_pixel_ce;

    pi_pixel_tracker pi_pixel_tracker0 (
        // Inputs
        .clk(clk),
        .clk_phase(clk_phase),
        .hsync(pi_hsync),
        .vsync(pi_vsync),
        .display_en(pi_display_en),
        
        // Outputs
        .pixel_ce(pi_pixel_ce),
        .pixel_x(pi_pixel_x),
        .pixel_y(pi_pixel_y)
    );

    // -----------------------------------------------------------
    // Generate Pi5 composite sync
    wire pi_csync;
    assign pi_csync = pi_hsync ~^ pi_vsync;

    // -----------------------------------------------------------
    // Generate Pi 5 frame start signal 
    wire pi_frame_start;
    
    pal_framestart pi_framestart0 (
        // Inputs
        .clk(clk),
        .pixel_ce(pi_pixel_ce),
        .pixel_x(pi_pixel_x),
        .pixel_y(pi_pixel_y),
        
        // Outputs
        .frame_start(pi_frame_start)
    );

    // -----------------------------------------------------------
    // Debugging output to Picoscope
    // assign picoscope[0] = aiv_csync;
    // assign picoscope[1] = aiv_pixel_ce;
    // assign picoscope[2] = aiv_frame_start;
    // assign picoscope[5:3] = clk_phase;
    // assign picoscope[15:6] = 8'b0;

    assign picoscope[0] = pi_csync;
    assign picoscope[1] = pi_display_en;
    assign picoscope[2] = pi_hsync;
    assign picoscope[3] = pi_vsync;
    assign picoscope[4] = pi_frame_start;
    assign picoscope[5] = pi_pixel_ce;
    assign picoscope[15:6] = 10'b0;

    // -----------------------------------------------------------
    // PAL 576i test pattern
    wire [2:0] test_rgb_111;

    pal_testcard pal_testcard0 (
        // Inputs
        .clk(clk),
        .pixel_x(pi_pixel_x),
        .pixel_y(pi_pixel_y),
        
        // Outputs
        .rgb_111(test_rgb_111)
    );   

    // -----------------------------------------------------------
    // SCART output

    assign scart_rgb_666 = aiv_rgb_666_fb_out;
    assign scart_csync = pi_csync;

endmodule