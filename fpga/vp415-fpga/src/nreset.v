/************************************************************************
	
	nreset.v
	Reset signal generation
	
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

// This module implements a simple Larson Scanner to show when the
// FPGA board is programmed and running.

module nreset(
    input sysClock,
    output nReset
);

    reg [7:0] resetTimer = 8'b0; 
    reg nReset_r = 1'b0;

    always @(posedge sysClock) begin
        // Generate nReset signal for 250 sysClock cycles
        if (resetTimer < 250) begin
            // We are in reset
            nReset_r <= 1'b1;
            resetTimer <= resetTimer + 1'b1;
        end else begin
            // We are not in reset
            nReset_r <= 1'b1;
        end
    end

    assign nReset = nReset_r;

endmodule