/************************************************************************
	
	syncsignals.v
	Synchronize async signals to the system clock
	
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

module sync_signals (
    input wire clk,          // 81 MHz clock
    input wire [2:0] rgb_111,
    input wire csync,

    output wire [2:0] rgb_sync_111,
    output wire csync_sync
);

    wire red;
    wire green;
    wire blue;
    wire red_sync;
    wire green_sync;
    wire blue_sync;

    assign {red, green, blue} = rgb_111;
    assign rgb_sync_111 = {red_sync, green_sync, blue_sync};

    // Synchronize the async signals to the 81 MHz clock
    sync2 sync_red (
        .clk(clk),
        .async_in(red),
        .sync_out(red_sync)
    );

    sync2 sync_green (
        .clk(clk),
        .async_in(green),
        .sync_out(green_sync)
    );

    sync2 sync_blue (
        .clk(clk),
        .async_in(blue),
        .sync_out(blue_sync)
    );

    sync2 sync_csync (
        .clk(clk),
        .async_in(csync),
        .sync_out(csync_sync)
    );
endmodule

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