/************************************************************************
	
	testgen.v
	Samsung K6R4016V1D-TC10 512K SRAM interface
	
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

module testgen (
    input wire clk,            // Clock input
    input wire [2:0] clkPhase, // Clock phase input
    input wire reset_n,        // Active low reset
    output reg [15:0] data     // 16-bit data output
);
    
    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            // Reset both counters
            data <= 16'h0000;
        end else begin
            // Increment data
            if (clkPhase == 3'b101) begin
                data <= data + 1'b1;
            end
        end
    end

endmodule