/************************************************************************
	
	syncseperator.v
	Csync seperator
	
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

module sync_extractor(
    input wire clk,         // 100 MHz FPGA clock
    input wire sync_in,     // Composite sync signal
    output reg h_sync,      // Extracted horizontal sync
    output reg v_sync       // Extracted vertical sync
);

reg [15:0] counter;
reg prev_sync;

always @(posedge clk) begin
    prev_sync <= sync_in;
    
    if (prev_sync && !sync_in) begin  // Detect falling edge
        counter <= 0;
    end else if (!sync_in) begin
        counter <= counter + 1;
    end

    // H-Sync detection (4.7 µs pulse)
    if (counter > 300 && counter < 800)  // Safe range around 470 clocks
        h_sync <= 1;
    else
        h_sync <= 0;

    // V-Sync detection (27-32 µs pulse)
    if (counter > 2000 && counter < 4000) // Safe range around 2700-3200 clocks
        v_sync <= 1;
    else
        v_sync <= 0;
end

endmodule