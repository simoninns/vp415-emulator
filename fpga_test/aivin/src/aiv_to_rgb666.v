/************************************************************************
    
    aiv_to_rgb666.v
    Convert RGB111 to RGB666
    
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

module aiv_to_rgb666 (
    input wire clk,          // 81 MHz clock
    input wire [2:0] rgb_111,

    output reg [17:0] rgb_666
);

    // Convert RGB111 to RGB666
    always @(posedge clk) begin
        if (rgb_111[2]) begin
            rgb_666[17:12] <= 6'b111111;
        end else begin
            rgb_666[17:12] <= 6'b000000;
        end
        if (rgb_111[1]) begin
            rgb_666[11:6] <= 6'b111111;
        end else begin
            rgb_666[11:6] <= 6'b000000;
        end
        if (rgb_111[0]) begin
            rgb_666[5:0] <= 6'b111111;
        end else begin
            rgb_666[5:0] <= 6'b000000;
        end
    end

endmodule