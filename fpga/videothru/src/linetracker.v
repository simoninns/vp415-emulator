/************************************************************************
	
	linetracker.v
	Raspberry Pi DPI video line and dot tracker
	
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

module linetracker (
    input pixelClockX6,
    input pixelClockX1_en,
    input nReset,

    input displayEnabled,
    input vSync,

    output [9:0] fieldLine,
    output [9:0] fieldLineDot,
);

    // displayEnabled is true when the pixel clock is in the visible area of a field line
    // So we need to count the pixel clock when displayEnabled is true to track the 720 dots per line
    // Each field has 288 lines which are also counted

    reg [9:0] fieldLine_r; // Current field line (0-287)
    reg [9:0] fieldLineDot_r; // Current field line dot (0-719)

    assign fieldLine = fieldLine_r;
    assign fieldLineDot = fieldLineDot_r;

    always @(posedge pixelClockX6 or negedge nReset) begin
        if (!nReset) begin
            fieldLine_r <= 0;
            fieldLineDot_r <= 0;
        end
        else begin 
            if (pixelClockX1_en) begin
                if (displayEnabled) begin
                    fieldLineDot_r <= fieldLineDot_r + 1;

                    // Check for end of line
                    if (fieldLineDot_r == 719) begin
                        fieldLineDot_r <= 0;
                        fieldLine_r <= fieldLine_r + 1;
                    end
                end

                if (!vSync) begin
                    fieldLine_r <= 0;
                    fieldLineDot_r <= 0;
                end
            end
        end
    end

endmodule