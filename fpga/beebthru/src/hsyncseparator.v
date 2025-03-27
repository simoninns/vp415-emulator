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

// The PAL line rate is 15.625 kHz, so the horizontal sync period is 64 µs.
// We therefore expect the csync signal to be high for 60 µs and low for 4 µs.

module hsync_separator (
    input wire clk,           // 100 MHz clock
    input wire comp_sync,     // Composite sync input (XOR'd HSYNC/VSYNC)
    output reg hsync_out,     // Reconstructed HSYNC
);

    // Edge Detection
    reg cs_d1, cs_d2;
    wire falling_edge = (cs_d2 == 1 && cs_d1 == 0);

    always @(posedge clk) begin
        cs_d1 <= comp_sync;
        cs_d2 <= cs_d1;
    end

    // Simple HSYNC detector based on falling edges
    reg [12:0] hsync_timer = 0;
    reg [12:0] hsync_period_counter = 0;
    localparam HSYNC_PERIOD_CYCLES = 6400; // ~64 us at 100 MHz
    localparam HSYNC_PULSE_WIDTH = 470;    // ~4.7 us pulse width
    localparam HSYNC_MIN_PERIOD = 5500;    // ~55 us minimum between pulses to ignore serrations

    always @(posedge clk) begin
        if (hsync_timer < HSYNC_PERIOD_CYCLES)
            hsync_timer <= hsync_timer + 1;

        if (hsync_period_counter < HSYNC_PERIOD_CYCLES)
            hsync_period_counter <= hsync_period_counter + 1;

        if (falling_edge && hsync_period_counter >= HSYNC_MIN_PERIOD) begin
            hsync_timer <= 0;
            hsync_period_counter <= 0;
        end

        hsync_out <= (hsync_timer < HSYNC_PULSE_WIDTH) ? 1'b0 : 1'b1; // active low
    end

endmodule