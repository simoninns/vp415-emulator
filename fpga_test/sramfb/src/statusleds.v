/************************************************************************
	
	statusleds.v
	Status LEDs control
	
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

// Flash two LEDs on and off to show the FPGA is running
module statusleds (
    // Inputs
    input sysClock,
    input nReset,
    input [1:0] test_result,  // Added test result input
    
    // Outputs
    output reg [1:0] leds
);

    always @(posedge sysClock or negedge nReset) begin
        if (!nReset) begin
            leds <= 2'b00;
        end else begin
            leds <= test_result;  // Show test results on LEDs
        end
    end

endmodule