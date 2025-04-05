/************************************************************************
	
	testcard1bit.v
	Test card for RGB111 PAL 576i video
	
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

module testcard1bit(
	input clk,
    input nReset,
    input [9:0] pixelX,
    input [9:0] pixelY,
    input displayEnable,

    output [2:0] rgb_111
);

    // Generate an RGB111 test card.
    // 720 active pixels per line. So we will output 8 bars of 
    // 90 pixels.

    reg [2:0] rgb_111_r;

    always @(posedge clk, negedge nReset) begin
        if (!nReset) begin
            rgb_111_r <= 3'b000;
        end else begin
            if (displayEnable) begin
                if (pixelY < 288) begin
                    // Colour bars for the top half of the screen
                    if (pixelX < (90 * 1)) begin
                        // Black
                        rgb_111_r <= 3'b000;
                    end else if (pixelX < (90 * 2)) begin
                        // Blue
                        rgb_111_r <= 3'b001;
                    end else if (pixelX < (90 * 3)) begin
                        // Green
                        rgb_111_r <= 3'b010;
                    end else if (pixelX < (90 * 4)) begin
                        // Cyan
                        rgb_111_r <= 3'b011;
                    end else if (pixelX < (90 * 5)) begin
                        // Red
                        rgb_111_r <= 3'b100;
                    end else if (pixelX < (90 * 6)) begin
                        // Magenta
                        rgb_111_r <= 3'b101;
                    end else if (pixelX < (90 * 7)) begin
                        // Yellow
                        rgb_111_r <= 3'b110;
                    end else if (pixelX < (90 * 8)) begin
                        // White
                        rgb_111_r <= 3'b111;
                    end else begin
                        // Black
                        rgb_111_r <= 3'b000;
                    end
                end else if (pixelY < 576) begin

                    // Draw a grid of while lines 20x20 pixels
                    if ((pixelX % 20) == 0 || (pixelY % 20) == 0) begin
                        rgb_111_r <= 3'b111; // White
                    end else begin
                        rgb_111_r <= 3'b000; // Black
                    end
                end else begin
                    rgb_111_r <= 3'b000;
                end
            end else begin
                // Display not enabled, set all outputs to 0
                rgb_111_r <= 3'b000;
            end
        end
    end

    // Connect internal registers to outputs
    assign rgb_111 = rgb_111_r;

endmodule