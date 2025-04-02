/************************************************************************
	
	framebuffer.v
	Samsung K6R4016V1D-TC10 512K SRAM framebuffer
	
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

module framebuffer (
    input wire clk,                 // System clock
    input wire [2:0] clkPhase,      // Clock phase input
    input wire reset_n,             // Active low reset

    input wire reset_in,
    input wire reset_out,

    input wire data_in_en,
    input wire data_out_en,

    input wire [2:0] data_in,      // 3-bit RGB111 input to framebuffer
    output wire [2:0] data_out,     // 3-bit RGB111 output from framebuffer
    
    // SRAM interface signals
    output reg [17:0] sram_addr,    // SRAM address bus (18 bits)
    inout wire [15:0] sram_data,    // SRAM data bus (16 bits)
    output reg sram_ce_n,           // Chip enable (active low)
    output reg sram_oe_n,           // Output enable (active low)
    output reg sram_we_n            // Write enable (active low)
);

    // SRAM bidirectional data bus control
    reg [15:0] sram_data_in;
    reg [15:0] sram_data_out;
    reg sram_data_out_en;

    SB_IO #(
        .PIN_TYPE(6'b1010_01)
    ) sram_data_pins [15:0] (
        .PACKAGE_PIN(sram_data),
        .OUTPUT_ENABLE(sram_data_out_en),
        .D_OUT_0(sram_data_out),
        .D_IN_0(sram_data_in)
    );

    // Phases for the state machine
    //
    // Note: We are dealing with pixels and the pixel clock is 13.5 MHz
    // The pixel clock is multiplied by 6 to get the system clock which
    // gives us 6 phases per pixel clock cycle to perform operations.
    localparam STATE_PHASE0 = 3'd0;
    localparam STATE_PHASE1 = 3'd1;
    localparam STATE_PHASE2 = 3'd2;
    localparam STATE_PHASE3 = 3'd3;
    localparam STATE_PHASE4 = 3'd4;
    localparam STATE_PHASE5 = 3'd5;

    // Define the buffer size
    // Note: Each buffer word stores 5 pixels
    //
    // 720 pixels * 576 lines = 414720 pixels
    // 414720 pixels / 5 pixels per word = 82944 words
    localparam BUFFER_SIZE = 82944;

    // Registers
    reg [2:0] data_in_pos_r; // Data in position register
    reg [2:0] data_out_pos_r; // Data out position register

    reg [2:0] data_out_r; // Data out register

    reg data_in_ready; // Flag to indicate if data is ready to be read
    reg data_out_ready; // Flag to indicate if data is ready to be written

    reg [15:0] buffer_in_r;    // Buffer to hold the packed 16-bit input data
    reg [15:0] buffer_out_r;   // Buffer to hold the packed 16-bit output data

    reg [17:0] current_write_addr; // Current write address
    reg [17:0] current_read_addr;  // Current read address

    reg data_out_en_r; // Data out enable register
    reg data_in_en_r;  // Data in enable register

    // State machine
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset buffers
            buffer_in_r <= 16'd0;
            buffer_out_r <= 16'd0;

            data_in_pos_r <= 3'd0;
            data_out_pos_r <= 3'd0;

            data_out_r <= 3'd0; // Reset output data

            data_in_ready <= 1'b0; // Reset data ready flag
            data_out_ready <= 1'b0; // Reset data out ready flag

            data_out_en_r <= 1'b0; // Reset data out enable
            data_in_en_r <= 1'b0;  // Reset data in enable

            // Reset address counters
            current_write_addr <= 18'd0;
            current_read_addr <= 18'd0;
            
            // Set SRAM control signals to idle
            sram_addr <= 18'd0;
            sram_data_out_en <= 1'b0;  // Disable data output
            sram_oe_n <= 1'b1;         // Disabled
            sram_we_n <= 1'b1;         // Disabled

            // As we only have one SRAM chip, we can keep it enabled
            sram_ce_n <= 1'b0; // Enable chip
        end
        else begin
            case (clkPhase)
                STATE_PHASE0: begin
                    // Phase zero - Getting and setting data from our interface

                    // Pack the 3 bits of data from data_in into the 16-bit buffer_in_r 
                    // at the correct position based on data_in_pos_r
                    buffer_in_r[data_in_pos_r * 3 +: 3] <= data_in; 

                    // Unpack the 3 bits of data from buffer_out_r to data_out_r
                    data_out_r <= buffer_out_r[data_out_pos_r * 3 +: 3];

                    // Read the enable flags
                    data_out_en_r <= data_out_en;
                    data_in_en_r <= data_in_en;

                    // Do we have 5 pixels in the input buffer?
                    if (data_in_pos_r == 3'd4) begin
                        data_in_pos_r <= 3'd0;
                        data_in_ready <= 1'b1;  // Mark buffer as ready for writint to SRAM
                    end else begin
                        if (data_in_en_r) data_in_pos_r <= data_in_pos_r + 1'b1;
                        data_in_ready <= 1'b0;  // Clear the data ready flag
                    end

                    // Have we output 5 pixels from the output buffer?
                    if (data_out_pos_r == 3'd4) begin
                        data_out_pos_r <= 3'd0;
                        data_out_ready <= 1'b1; // Mark that we need new data from SRAM
                    end else begin
                        if (data_out_en_r) data_out_pos_r <= data_out_pos_r + 1'b1;
                        data_out_ready <= 1'b0; // Clear the data out ready flag
                    end

                    // Handle address pointer reset signals
                    if (reset_in) begin
                        current_write_addr <= 18'd0; // Reset write address
                    end

                    if (reset_out) begin
                        current_read_addr <= 18'd0; // Reset read address
                    end
                end

                STATE_PHASE1: begin
                    // Phase one - Prepare to write data to SRAM

                    // Check if data is ready to be written
                    if (data_in_ready && data_in_en_r) begin
                        // Set the unused 16th bit to zero (for clarity)
                        buffer_in_r[15] <= 1'b0;

                        // Prepare to write data to SRAM
                        sram_data_out_en <= 1'b1;
                        sram_data_out <= buffer_in_r;
                        sram_addr <= current_write_addr;
                        sram_we_n <= 1'b0; // Enable write
                        sram_oe_n <= 1'b1; // Disable output during write
                    end else begin
                        // Idle state
                        sram_data_out_en <= 1'b0;
                        sram_oe_n <= 1'b1;
                        sram_we_n <= 1'b1;
                    end
                end

                STATE_PHASE2: begin
                    // Phase two - Finalize write

                    // Check if data is ready to be written
                    if (data_in_ready && data_in_en_r) begin
                        sram_we_n <= 1'b1; // Disable write
                        sram_oe_n <= 1'b1; // Disable output
                        sram_data_out_en <= 1'b0; // Disable data output
                        current_write_addr <= current_write_addr + 1'b1; // Increment write address

                        // Range check the write address
                        if (current_write_addr >= BUFFER_SIZE) begin
                            current_write_addr <= 18'd0; // Reset to zero if overflow
                        end

                        // Clear the data ready flag
                        data_in_ready <= 1'b0;
                    end else begin
                        // If not ready, disable data output and set SRAM control signals to idle
                        sram_data_out_en <= 1'b0;
                        sram_oe_n <= 1'b1; // Disable output
                        sram_we_n <= 1'b1; // Disable write
                    end
                end

                STATE_PHASE3: begin
                    // Phase three - Idle
                end

                STATE_PHASE4: begin
                    // Phase four - Prepare to read data from SRAM

                    // Check if data is ready to be read
                    if (data_out_ready && data_out_en_r) begin
                        sram_addr <= current_read_addr;
                        sram_oe_n <= 1'b0; // Enable output
                        sram_we_n <= 1'b1; // Disable write
                        sram_data_out_en <= 1'b0; // Disable data output (we're reading)
                    end else begin
                        // Idle state
                        sram_data_out_en <= 1'b0;
                        sram_oe_n <= 1'b1;
                        sram_we_n <= 1'b1;
                    end
                end

                STATE_PHASE5: begin
                    // Phase five - Finalize read

                    // Check if data is ready to be read
                    if (data_out_ready && data_out_en_r) begin
                        buffer_out_r <= sram_data_in; // Capture the data from SRAM
                        sram_oe_n <= 1'b1; // Disable output
                        current_read_addr <= current_read_addr + 1'b1;

                        // Range check the read address
                        if (current_read_addr >= BUFFER_SIZE - 1) begin
                            current_read_addr <= 18'd0;
                        end

                        // We've handled the read request
                        data_out_ready <= 1'b0;
                    end else begin
                        // Idle state
                        sram_data_out_en <= 1'b0;
                        sram_oe_n <= 1'b1;
                        sram_we_n <= 1'b1;
                    end
                end
            endcase
        end
    end

    // Output the data register to the output port
    assign data_out = data_out_r;

endmodule