/************************************************************************
	
	testcard1bit.v
	Test card for RGB111 PAL 576i video
	
	VP415-Emulator FPGA
	Copyright (C) 2025 Simon Inns
	
	This file is part of VP415-Emulator.
	
	Domesday Duplicator is free software: you can redistribute it and/or
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
    input [8:0] pixelY,
    input displayEnable,

    output redOut,
    output greenOut,
    output blueOut
);

    // Generate an RGB111 test card.
    // We have 4 possible outputs, red, green, blue and black and
    // 720 active pixels per line. So we will output 8 bars of 
    // 90 pixels of red, green, blue and black repeated twice.

    // The test card is 720 pixels wide and 288 lines high.

    reg redOut_r;
    reg greenOut_r;
    reg blueOut_r;

    always @(posedge clk, negedge nReset) begin
        if (!nReset) begin
            redOut_r <= 1'b0;
            greenOut_r <= 1'b0;
            blueOut_r <= 1'b0;
        end else begin
            if (displayEnable) begin
                if (pixelY == 40 || pixelY == 41) begin // One line in each field for testing...
                    if (pixelX < (90 * 1)) begin
                        // Red
                        redOut_r <= 1'b1;
                        greenOut_r <= 1'b0;
                        blueOut_r <= 1'b0;
                    end else if (pixelX < (90 * 2)) begin
                        // Green
                        redOut_r <= 1'b0;
                        greenOut_r <= 1'b1;
                        blueOut_r <= 1'b0;
                    end else if (pixelX < (90 * 3)) begin
                        // Blue
                        redOut_r <= 1'b0;
                        greenOut_r <= 1'b0;
                        blueOut_r <= 1'b1;
                    end else if (pixelX < (90 * 4)) begin
                        // Black
                        redOut_r <= 1'b0;
                        greenOut_r <= 1'b0;
                        blueOut_r <= 1'b0;
                    end else if (pixelX < (90 * 5)) begin
                        // Red
                        redOut_r <= 1'b1;
                        greenOut_r <= 1'b0;
                        blueOut_r <= 1'b0;
                    end else if (pixelX < (90 * 6)) begin
                        // Green
                        redOut_r <= 1'b0;
                        greenOut_r <= 1'b1;
                        blueOut_r <= 1'b0;
                    end else if (pixelX < (90 * 7)) begin
                        // Blue
                        redOut_r <= 1'b0;
                        greenOut_r <= 1'b0;
                        blueOut_r <= 1'b1;
                    end else begin
                        redOut_r <= 1'b0;
                        greenOut_r <= 1'b0;
                        blueOut_r <= 1'b0;
                    end
                end else begin
                    redOut_r <= 1'b0;
                    greenOut_r <= 1'b0;
                    blueOut_r <= 1'b0;
                end
            end else begin
                // Display not enabled, set all outputs to 0
                redOut_r <= 1'b0;
                greenOut_r <= 1'b0;
                blueOut_r <= 1'b0;
            end
        end
    end

    // Connect internal registers to outputs
    assign redOut = redOut_r;
    assign greenOut = greenOut_r;
    assign blueOut = blueOut_r;

endmodule