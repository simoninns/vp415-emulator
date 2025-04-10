/************************************************************************
	
	pal_framestart.v
	Start of frame flag
	
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

module pal_framestart(
	input clk,
    input [9:0] pixel_x,
    input [9:0] pixel_y,
    input pixel_ce,

    output frame_start
);

    reg start_of_frame_r;
    assign frame_start = start_of_frame_r;

    always @(posedge clk) begin
        if (pixel_x == 10'b0 && pixel_y == 10'b0 && pixel_ce) begin
            start_of_frame_r <= 1'b1;
        end else begin
            start_of_frame_r <= 1'b0;
        end
    end

endmodule