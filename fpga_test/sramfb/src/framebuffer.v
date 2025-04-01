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

    input wire [15:0] data_in,      // 16-bit input data from system
    output reg [15:0] data_out,     // 16-bit output data to system
    
    // SRAM interface signals
    output reg [17:0] sram_addr,    // SRAM address bus (18 bits to match top-level)
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

    // States for the state machine
    localparam STATE_PHASE0 = 3'd0;
    localparam STATE_PHASE1 = 3'd1;
    localparam STATE_PHASE2 = 3'd2;
    localparam STATE_PHASE3 = 3'd3;
    localparam STATE_PHASE4 = 3'd4;
    localparam STATE_PHASE5 = 3'd5;

    // Define the buffer size
    localparam BUFFER_SIZE = 1024; // Note 1024 * 16 bits = 2K bits

    // Registers
    reg [15:0] buffer_in_r;    // Buffer to hold the input data
    reg [15:0] buffer_out_r;   // Buffer to hold the output data

    reg [17:0] current_write_addr; // Current write address
    reg [17:0] current_read_addr;  // Current read address

    // State machine
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset buffers
            buffer_in_r <= 16'd0;
            buffer_out_r <= 16'd0;

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
                    // Phase zero - Getting and setting data
                    
                    // Read the input data
                    buffer_in_r <= data_in;

                    // Set the output data
                    data_out <= buffer_out_r;

                    // Handle address pointer reset signals
                    if (reset_in) begin
                        current_write_addr <= 18'd0; // Reset write address
                    end

                    if (reset_out) begin
                        current_read_addr <= 18'd0; // Reset read address
                    end
                end

                STATE_PHASE1: begin
                    // Phase one - Prepare to write data
                    sram_data_out_en <= 1'b1; // Enable data output
                    sram_data_out <= buffer_in_r; // Set the data to be written
                    sram_addr <= current_write_addr; // Set the address
                    sram_oe_n <= 1'b0; // Enable output
                    sram_we_n <= 1'b0; // Enable write
                end

                STATE_PHASE2: begin
                    // Phase two - Finalize write
                    sram_we_n <= 1'b1; // Disable write
                    sram_oe_n <= 1'b1; // Disable output
                    sram_data_out_en <= 1'b0; // Disable data output
                    current_write_addr <= current_write_addr + 1'b1; // Increment write address

                    // Range check the write address
                    if (current_write_addr >= BUFFER_SIZE) begin
                        current_write_addr <= 18'd0; // Reset to zero if overflow
                    end
                end

                STATE_PHASE3: begin
                    // Phase three - Idle
                end

                STATE_PHASE4: begin
                    // Phase four - Prepare to read data
                    sram_addr <= current_read_addr; // Set the address
                    sram_oe_n <= 1'b0; // Enable output
                    sram_we_n <= 1'b1; // Disable write
                    sram_data_out_en <= 1'b0; // Disable data output
                end

                STATE_PHASE5: begin
                    // Phase five - Finalize read
                    buffer_out_r <= sram_data_in; // Read the data
                    sram_oe_n <= 1'b1; // Disable output
                    sram_data_out_en <= 1'b0; // Disable data output
                    current_read_addr <= current_read_addr + 1'b1; // Increment read address

                    // Range check the read address
                    if (current_read_addr >= BUFFER_SIZE) begin
                        current_read_addr <= 18'd0; // Reset to zero if overflow
                    end
                end
            endcase
        end
    end

endmodule