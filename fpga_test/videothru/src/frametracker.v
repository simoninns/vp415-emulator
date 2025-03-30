/************************************************************************
	
	frameTracker.v
	Raspberry Pi DPI interlaced field sync generator
	
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

module frameTracker (
    input pixelClockX6,
    input pixelClockX1_en,
    input nReset,
    input [9:0] fieldLine,
    input isFieldOdd,
    
    output [9:0] frameLine
);

    reg [9:0] frameLine_r;
    assign frameLine = frameLine_r;

    always @(posedge pixelClockX6, negedge nReset) begin
        if (!nReset) begin
            // Reset
            frameLine_r <= 0;
        end
        else begin
            if (pixelClockX1_en) begin
                if (isFieldOdd) begin
                    frameLine_r <= (fieldLine * 2);
                end
                else begin
                    frameLine_r <= (fieldLine * 2) + 1;
                end
            end
        end
    end

endmodule