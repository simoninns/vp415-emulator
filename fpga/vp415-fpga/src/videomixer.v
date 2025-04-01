/************************************************************************
	
	videomixer.v
	PAL 576i video mixer
	
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

module videomixer(
	input pixelClockX6,
    input [2:0] pixelClockPhase,
    input nReset,

    input [5:0] red_fg,
    input [5:0] green_fg,
    input [5:0] blue_fg,

    input [5:0] red_bg,
    input [5:0] green_bg,
    input [5:0] blue_bg,

    output [5:0] red_out,
    output [5:0] green_out,
    output [5:0] blue_out
	);

    reg [5:0] red_out_r;
    reg [5:0] green_out_r;
    reg [5:0] blue_out_r;

    always @(posedge pixelClockX6, negedge nReset) begin
        if (!nReset) begin
            // Reset
            red_out_r <= 6'b000000;
            green_out_r <= 6'b000000;
            blue_out_r <= 6'b000000;
        end
        else begin
            if (pixelClockPhase == 3'b0) begin
                // If the foreground pixel is black, use the background pixel
                if (red_fg == 6'b0 && green_fg == 6'b0 && blue_fg == 6'b0) begin
                    red_out_r <= red_bg;
                    green_out_r <= green_bg;
                    blue_out_r <= blue_bg;
                end
                else begin
                    // Otherwise, use the foreground pixel
                    red_out_r <= red_fg;
                    green_out_r <= green_fg;
                    blue_out_r <= blue_fg;
                end
            end
        end
    end

    // Assign the output signals
    assign red_out = red_out_r;
    assign green_out = green_out_r;
    assign blue_out = blue_out_r;

endmodule