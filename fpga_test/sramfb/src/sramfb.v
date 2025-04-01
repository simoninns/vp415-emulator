/************************************************************************
	
	sramfb.v
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

    // // Picoscope output
    // assign picoScope[0] = 0;
    // assign picoScope[1] = 0;
    // assign picoScope[2] = 0;
    // assign picoScope[3] = 0;
    // assign picoScope[4] = 0;
    // assign picoScope[5] = 0;
    // assign picoScope[15:6] = 0;

    // -----------------------------------------------------------
    // Pixel clock generation PLL

    // We use the Pi's DPI pixel clock as a base and multiply it
    // by 10.  The module also produces a /6 enable signal running
    // at the original pixel clock's rate.
    wire pixelClock_piIn;
    assign pixelClock_piIn = pi_gpio[0];
    wire clk;
    wire [2:0] clkPhase;

    pixelclockpll pixelclockpll0 (
        // Inputs
        .pixelClockIn(pixelClock_piIn),
        
        // Outputs
        .pixelClockX6_out(clk),
        .pixelClockPhase(clkPhase)
    );

    // -----------------------------------------------------------
    // Basic hardware functions

    // nReset signal generation (as the iCE40 board doesn't have one)
    wire nReset;

    nreset nreset0 (
        .sysClock(clk),
        .nReset(nReset)
    );

    // Status LED control
    wire [1:0] leds;

    statusleds statusleds0 (
        // Inputs
        .sysClock(clk),
        .nReset(nReset),
        
        // Outputs
        .leds(leds)
    );

    // -----------------------------------------------------------
    // Generate the test data
    wire [15:0] testData;

    testgen testgen0 (
        .clk(clk),
        .clkPhase(clkPhase),
        .reset_n(nReset),
        .data(testData)
    );

    // -----------------------------------------------------------
    // Framebuffer SRAM interface
    framebuffer frameBuffer0 (
        // Inputs
        .clk(clk),
        .clkPhase(clkPhase),
        .reset_n(nReset),

        .reset_in(1'd0),
        .reset_out(1'd0),

        .data_in(testData),
        .data_out(picoScope[15:0]),

        // SRAM
        .sram_addr(SRAM0_A),
        .sram_data(SRAM0_D),
        .sram_oe_n(SRAM0_nOE),
        .sram_we_n(SRAM0_nWE),
        .sram_ce_n(SRAM0_nCS)
    );
    

endmodule