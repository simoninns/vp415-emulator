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
    input pixelClockX1_en,
    input nReset,

    input [5:0] redIn0,
    input [5:0] greenIn0,
    input [5:0] blueIn0,

    input [5:0] redIn1,
    input [5:0] greenIn1,
    input [5:0] blueIn1,

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
                // Key on black
                if (redIn1 == 0 && greenIn1 == 0 && blueIn1 == 0) begin
                    redOut_r <= redIn0;
                    greenOut_r <= greenIn0;
                    blueOut_r <= blueIn0;
                end
                else begin
                    redOut_r <= redIn1;
                    greenOut_r <= greenIn1;
                    blueOut_r <= blueIn1;
                end
            end
        end
    end

endmodule