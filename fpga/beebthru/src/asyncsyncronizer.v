/************************************************************************
	
	asyncsynchronizer.v
	async signal synchronizer
	
	VP415-Emulator FPGA
	Copyright (C) 2025 Simon Inns
	
	This file is part of VP415-Emulator.
	
	Domesday Duplicator is free software: you can redistribute it and/or
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

// Synchronizer module for async signals
// Note: This introduces a 2 clock cycle delay to the signal
module sync2 (
    input wire clk,
    input wire async_in,
    output reg sync_out
);

    reg [1:0] sync_reg;

    always @(posedge clk) begin
        sync_reg <= {sync_reg[0], async_in};
        sync_out <= sync_reg[1];
    end

endmodule