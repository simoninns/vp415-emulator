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

    input [17:0] rgb_fg,
    input [17:0] rgb_bg,

    output [17:0] rgb_out
	);

    reg [17:0] rgb_out_r;

    always @(posedge pixelClockX6, negedge nReset) begin
        if (!nReset) begin
            // Reset
            rgb_out_r <= 18'b0;
        end
        else begin
            if (pixelClockPhase == 3'b0) begin
                // If the foreground pixel is black, use the background pixel
                if (rgb_fg == 18'b0) begin
                    rgb_out_r <= rgb_bg;
                end
                else begin
                    // Otherwise, use the foreground pixel
                    rgb_out_r <= rgb_fg;
                end
            end
        end
    end

    // Assign the output signals
    assign rgb_out = rgb_out_r;

endmodule