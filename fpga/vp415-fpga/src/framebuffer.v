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

module framebuffer(
    input wire clk,                 // System clock
    input wire [2:0] clkPhase,      // Clock phase input
    input wire reset_n,             // Active low reset

    input display_en_in,            // Display enable input
    input frame_start_flag_in,      // Input frame start flag

    input display_en_out,           // Display enable output
    input frame_start_flag_out,     // Output frame start flag

    input wire [2:0] rgb_111_in,    // 3-bit RGB111 input to framebuffer
    output wire [2:0] rgb_111_out,  // 3-bit RGB111 output from framebuffer

    
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
    localparam STATE_READ0 = 3'd3;
    localparam STATE_READ1 = 3'd4;
    localparam STATE_READ2 = 3'd5;
    localparam STATE_WRITE0 = 3'd0;
    localparam STATE_WRITE1 = 3'd1;
    localparam STATE_WRITE2 = 3'd2;

    // Framebuffer input buffers
    reg [15:0] input_buffer0;
    reg [15:0] input_buffer1;
    reg input_buffer_current;
    reg [17:0] input_framebuffer_addr;
    reg [2:0] input_pixel_counter;

    // Frame buffer output buffer
    reg [15:0] output_buffer0;
    reg [15:0] output_buffer1;
    reg output_buffer_current;
    reg [17:0] output_framebuffer_addr;
    reg [2:0] output_pixel_counter;

    reg [2:0] rgb_111_out_r;
    assign rgb_111_out = rgb_111_out_r;

    // Input processing
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset input state
            input_buffer0 <= 16'b0;
            input_buffer1 <= 16'b0;
            input_buffer_current <= 1'b0;
            input_framebuffer_addr <= 18'b0;
            input_pixel_counter <= 3'b0;

            // Reset output state
            output_buffer0 <= 16'b0;
            output_buffer1 <= 16'b0;
            output_buffer_current <= 1'b0;
            output_framebuffer_addr <= 18'b0;
            output_pixel_counter <= 3'b0;
            rgb_111_out_r <= 3'b0;

            sram_ce_n <= 1'b1; // Deactivate SRAM
            sram_oe_n <= 1'b1; // Deactivate output
            sram_we_n <= 1'b1; // Deactivate write

            sram_ce_n <= 1'b0; // Activate SRAM via Chip Enable
        end else begin
            // ----------------------------------------------------------------------------------
            // SRAM address reset handling
            // Input address reset?
            if (frame_start_flag_in) begin
                // Reset input state
                input_buffer0 <= 16'd0;
                input_buffer1 <= 16'd0;
                input_buffer_current <= 1'd0;
                input_framebuffer_addr <= 18'd0;
                input_pixel_counter <= 3'd0;
            end

            // Output address reset?
            if (frame_start_flag_out) begin
                // Reset output state
                output_buffer0 <= 16'd0;
                output_buffer1 <= 16'd0;
                output_buffer_current <= 1'd0;
                output_framebuffer_addr <= 18'd0;
                output_pixel_counter <= 3'd0;

                rgb_111_out_r <= 3'd0;
            end

            // ----------------------------------------------------------------------------------
            // Pixel processing
            if (clkPhase == 3'd0) begin
                // Input display enabled?
                if (display_en_in) begin
                    // Store the current pixel data
                    if (input_buffer_current) begin
                        // Use input buffer 0 and write the 3 bits according to the pixel counter
                        input_buffer0[input_pixel_counter * 3 +: 3] <= rgb_111_in;
                    end else begin
                        // Use input buffer 1 and write the 3 bits according to the pixel counter
                        input_buffer1[input_pixel_counter * 3 +: 3] <= rgb_111_in;
                    end

                    // Increment the pixel counter
                    input_pixel_counter <= input_pixel_counter + 3'd1;

                    // Check if we need to switch buffers
                    if (input_pixel_counter == 3'd4) begin
                        // Switch buffers
                        input_buffer_current <= ~input_buffer_current;
                        input_pixel_counter <= 3'b0; // Reset input pixel counter
                    end
                end

                // Output display enabled?
                if (display_en_out) begin
                    // Get the current pixel data from the output buffer
                    if (output_buffer_current) begin
                        // Use output buffer 0 and read the 3 bits according to the pixel counter
                        rgb_111_out_r <= output_buffer0[output_pixel_counter * 3 +: 3];
                    end else begin
                        // Use output buffer 1 and read the 3 bits according to the pixel counter
                        rgb_111_out_r <= output_buffer1[output_pixel_counter * 3 +: 3];
                    end

                    // Increment the pixel counter
                    output_pixel_counter <= output_pixel_counter + 3'd1;

                    // Check if we need to switch buffers
                    if (output_pixel_counter == 3'd4) begin
                        // Switch buffers
                        output_buffer_current <= ~output_buffer_current;
                        output_pixel_counter <= 3'b0; // Reset input pixel counter
                    end
                end
            end

            // --------------------------------------------------------------------------------
            // SRAM handling

            // If no SRAM access is taking place, keep the SRAM in a idle state
            if (output_pixel_counter != 1 && input_pixel_counter != 1) begin
                sram_oe_n <= 1'b1; // Deactivate output
                sram_we_n <= 1'b1; // Deactivate write
                sram_data_out_en <= 1'b0; // Set data bus to input
            end

            // Only perform SRAM read once per 5 pixels
            if (output_pixel_counter == 1 && display_en_out) begin
                case (clkPhase)
                    STATE_READ0: begin
                        // SRAM access - read - set the address and enable the chip
                        sram_addr <= output_framebuffer_addr;
                        sram_oe_n <= 1'b0; // Activate output
                        sram_we_n <= 1'b1; // Deactivate write
                        sram_data_out_en <= 1'b0; // Set data bus to input
                    end

                    STATE_READ1: begin
                        // SRAM READ wait for stable data
                    end

                    STATE_READ2: begin
                        // SRAM access - read - get the data from the SRAM

                        // Use the currently inactive output buffer
                        if (output_buffer_current) begin
                            // Use output buffer 1
                            output_buffer1 <= sram_data_in;
                        end else begin
                            // Use output buffer 0
                            output_buffer0 <= sram_data_in;
                        end

                        // Increment the output framebuffer address
                        output_framebuffer_addr <= output_framebuffer_addr + 1;
                    end
                endcase
            end

            // Only perform SRAM write once per 5 pixels
            if (input_pixel_counter == 1 && display_en_in) begin
                case (clkPhase)
                    STATE_WRITE0: begin
                        // Set the unused 16th bit to zero
                        input_buffer0[15] <= 1'b0;
                        input_buffer1[15] <= 1'b0;

                        // Prepare to write data to SRAM
                        sram_data_out_en <= 1'b1;

                        if (input_buffer_current) begin
                            // Use input buffer 1
                            sram_data_out <= input_buffer1;
                        end else begin
                            // Use input buffer 0
                            sram_data_out <= input_buffer0;
                        end
                        
                        sram_addr <= input_framebuffer_addr;
                        sram_we_n <= 1'b0; // Enable write
                        sram_oe_n <= 1'b1; // Disable output during write
                    end

                    STATE_WRITE1: begin
                        // SRAM WRITE wait for stable data
                    end

                    STATE_WRITE2: begin
                        sram_we_n <= 1'b1; // Disable write
                        sram_oe_n <= 1'b1; // Disable output
                        sram_data_out_en <= 1'b0; // Disable data output

                        // Increment the input framebuffer address
                        input_framebuffer_addr <= input_framebuffer_addr + 1;
                    end
                endcase
            end
        end
    end

endmodule
