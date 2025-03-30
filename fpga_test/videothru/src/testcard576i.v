/************************************************************************
	
	testcard576i.v
	PAL 576i test card generator
	
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

module testcard576i(
	input pixelClockX6,
    input pixelClockX1_en,
    input nReset,
    input [9:0] frameLine,
    input [9:0] fieldLineDot,

    output [5:0] redOut,
    output [5:0] greenOut,
    output [5:0] blueOut
	);

    reg [5:0] redOut_r;
    reg [5:0] greenOut_r;
    reg [5:0] blueOut_r;
    assign redOut = redOut_r;
    assign greenOut = greenOut_r;
    assign blueOut = blueOut_r;

    always @(posedge pixelClockX6, negedge nReset) begin
        if (!nReset) begin
            // Reset
            redOut_r <= 6'b000000;
            greenOut_r <= 6'b000000;
            blueOut_r <= 6'b000000;
        end
        else begin
            if (pixelClockX1_en) begin
                // Colour bars
                if (frameLine < 300) begin
                    if (fieldLineDot < 90) begin
                        // White
                        redOut_r <= 6'b111111;
                        greenOut_r <= 6'b111111;
                        blueOut_r <= 6'b111111;
                    end
                    else if (fieldLineDot < 90*2) begin
                        // Yellow
                        redOut_r <= 6'b111111;
                        greenOut_r <= 6'b111111;
                        blueOut_r <= 6'b000000;
                    end
                    else if (fieldLineDot < 90*3) begin
                        // Cyan
                        redOut_r <= 6'b000000;
                        greenOut_r <= 6'b111111;
                        blueOut_r <= 6'b111111;
                    end
                    else if (fieldLineDot < 90*4) begin
                        // Green
                        redOut_r <= 6'b000000;
                        greenOut_r <= 6'b111111;
                        blueOut_r <= 6'b000000;
                    end
                    else if (fieldLineDot < 90*5) begin
                        // Magenta
                        redOut_r <= 6'b111111;
                        greenOut_r <= 6'b000000;
                        blueOut_r <= 6'b111111;
                    end
                    else if (fieldLineDot < 90*6) begin
                        // Red
                        redOut_r <= 6'b111111;
                        greenOut_r <= 6'b000000;
                        blueOut_r <= 6'b000000;
                    end
                    else if (fieldLineDot < 90*7) begin
                        // Blue
                        redOut_r <= 6'b000000;
                        greenOut_r <= 6'b000000;
                        blueOut_r <= 6'b111111;
                    end
                    else begin
                        // Black
                        redOut_r <= 6'b000000;
                        greenOut_r <= 6'b000000;
                        blueOut_r <= 6'b000000;
                    end
                end
                else begin
                    // Secondary colour bars (blue, black, magenta, black, cyan, black, white)
                    if (frameLine < 360) begin
                        if (fieldLineDot < 90) begin
                            // Blue
                            redOut_r <= 6'b000000;
                            greenOut_r <= 6'b000000;
                            blueOut_r <= 6'b111111;
                        end
                        else if (fieldLineDot < 90*2) begin
                            // Black
                            redOut_r <= 6'b000000;
                            greenOut_r <= 6'b000000;
                            blueOut_r <= 6'b000000;
                        end
                        else if (fieldLineDot < 90*3) begin
                            // Magenta
                            redOut_r <= 6'b111111;
                            greenOut_r <= 6'b000000;
                            blueOut_r <= 6'b111111;
                        end
                        else if (fieldLineDot < 90*4) begin
                            // Black
                            redOut_r <= 6'b000000;
                            greenOut_r <= 6'b000000;
                            blueOut_r <= 6'b000000;
                        end
                        else if (fieldLineDot < 90*5) begin
                            // Cyan
                            redOut_r <= 6'b000000;
                            greenOut_r <= 6'b111111;
                            blueOut_r <= 6'b111111;
                        end
                        else if (fieldLineDot < 90*6) begin
                            // Black
                            redOut_r <= 6'b000000;
                            greenOut_r <= 6'b000000;
                            blueOut_r <= 6'b000000;
                        end
                        else if (fieldLineDot < 90*7) begin
                            // White
                            redOut_r <= 6'b111111;
                            greenOut_r <= 6'b111111;
                            blueOut_r <= 6'b111111;
                        end
                        else begin
                            // Black
                            redOut_r <= 6'b000000;
                            greenOut_r <= 6'b000000;
                            blueOut_r <= 6'b000000;
                        end
                    end
                    else begin
                        // Black
                        redOut_r <= 6'b000000;
                        greenOut_r <= 6'b000000;
                        blueOut_r <= 6'b000000;
                    end
                end
            end
        end
    end

endmodule