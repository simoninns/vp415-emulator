/************************************************************************
    
    aiv_input_sync.v
    Synchronize async AIV input signals to the system clock
    
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

// This module synchronizes the async AIV input signals to the system clock
// using a 2-stage synchronizer (to avoid metastability issues).
module aiv_input_sync (
    input wire clk,
    input wire [2:0] rgb_111,
    input wire csync,

    output wire [2:0] rgb_111_sync,
    output wire csync_sync
);

    reg [1:0] red_sync_reg, green_sync_reg, blue_sync_reg, csync_sync_reg;

    // Synchronize the RGB signals
    always @(posedge clk) begin
        red_sync_reg <= {red_sync_reg[0], rgb_111[2]};
        green_sync_reg <= {green_sync_reg[0], rgb_111[1]};
        blue_sync_reg <= {blue_sync_reg[0], rgb_111[0]};
    end

    assign rgb_111_sync = {red_sync_reg[1], green_sync_reg[1], blue_sync_reg[1]};

    // Synchronize the composite sync signal
    always @(posedge clk) begin
        csync_sync_reg <= {csync_sync_reg[0], csync};
    end

    assign csync_sync = csync_sync_reg[1];

endmodule