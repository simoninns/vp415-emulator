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

    // -----------------------------------------------------------
    // Generate the test data
    wire [2:0] testData;

    testgen testgen0 (
        .clk(clk),
        .clkPhase(clkPhase),
        .reset_n(nReset),
        .data(testData)
    );

    // -----------------------------------------------------------
    // Framebuffer SRAM interface
    wire [2:0] fb_out;
    wire compare_result;
    
    framebuffer frameBuffer0 (
        // Inputs
        .clk(clk),
        .clkPhase(clkPhase),
        .reset_n(nReset),

        .reset_in(1'd0),
        .reset_out(1'd0),

        .data_in(testData),
        .data_out(fb_out),

        // SRAM
        .sram_addr(SRAM0_A),
        .sram_data(SRAM0_D),
        .sram_oe_n(SRAM0_nOE),
        .sram_we_n(SRAM0_nWE),
        .sram_ce_n(SRAM0_nCS)
    );
    
    // -----------------------------------------------------------
    // Framebuffer verification
    
    // Compare test data with framebuffer output
    // The framebuffer has a pipeline delay that we need to account for
    // Based on the design, data takes multiple cycles to go through the framebuffer
    // Each 3-bit value gets packed into 16-bit words (5 values per word)
    // Need to delay by roughly (BUFFER_SIZE * 5 * 2) clock cycles (write + read time)
    
    // Create a longer delay line for test data to match framebuffer latency
    // Using a 256-entry delay line should be sufficient based on the buffer size
    localparam DELAY_LENGTH = 256;
    reg [2:0] test_data_delay_line [0:DELAY_LENGTH-1];
    integer i;
    
    always @(posedge clk) begin
        if (!nReset) begin
            for (i = 0; i < DELAY_LENGTH; i = i + 1) begin
                test_data_delay_line[i] <= 3'b000;
            end
        end else if (clkPhase == 3'b000) begin
            // Shift the delay line
            for (i = DELAY_LENGTH-1; i > 0; i = i - 1) begin
                test_data_delay_line[i] <= test_data_delay_line[i-1];
            end
            test_data_delay_line[0] <= testData;
        end
    end
    
    // Use the appropriately delayed test data for comparison
    // The exact delay value might need adjustment based on testing
    wire [2:0] properly_delayed_data = test_data_delay_line[DELAY_LENGTH-1];
    
    // Simple comparison with properly delayed data
    assign compare_result = (fb_out == properly_delayed_data);
    
    // Error detection - stays high if ever an error is detected
    reg test_error;
    always @(posedge clk) begin
        if (!nReset) begin
            test_error <= 1'b0;
        end else if (clkPhase == 3'b000 && !compare_result) begin
            test_error <= 1'b1;
        end
    end
    
    // Status LED control - indicate test results
    statusleds statusleds0 (
        // Inputs
        .sysClock(clk),
        .nReset(nReset),
        .test_result({compare_result, !test_error}), // LED[1] = current comparison, LED[0] = overall test status
        
        // Outputs
        .leds(leds)
    );
    
    // Picoscope debug outputs
    assign picoScope[2:0] = properly_delayed_data;    // Delayed test data we're comparing against
    assign picoScope[5:3] = fb_out;                   // Framebuffer output
    assign picoScope[6] = compare_result;             // Current comparison result
    assign picoScope[7] = test_error;                // Error detection flag
    assign picoScope[15:11] = 5'b0;                   // Unused bits
    

endmodule