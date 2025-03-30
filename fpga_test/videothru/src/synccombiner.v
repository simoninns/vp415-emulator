/************************************************************************
	
	synccombiner.v
	Horizontal and vertical sync combiner
	
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

module synccombiner(
	input hSync,
	input vSync,

    output cSync
);
	
    // EXOR the H and V syncs to combine
    //
    // Note: I think this needs XOR with +ve sync and XNOR with -ve sync...
    // needs some testing
    // Use XOR if both syncs are positive
    // Use XNOR if both syncs are negative

    assign cSync = hSync ~^ vSync;
    //assign cSync = hSync ^ vSync;

endmodule