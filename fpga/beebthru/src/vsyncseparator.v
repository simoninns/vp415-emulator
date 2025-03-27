/************************************************************************
    
    vsyncseparator.v
    Csync to Vsync separator
    
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

module vsync_separator (
    input  wire clk,          // 100 MHz system clock
    input  wire comp_sync,    // Composite sync input (HSYNC XOR VSYNC)
    output reg  vsync_out     // Active-high VSYNC signal (held during VSYNC)
);

    // === Edge detection
    reg cs_d1, cs_d2;
    wire rising_edge  = (cs_d2 == 0 && cs_d1 == 1);
    wire falling_edge = (cs_d2 == 1 && cs_d1 == 0);

    always @(posedge clk) begin
        cs_d1 <= comp_sync;
        cs_d2 <= cs_d1;
    end

    // === Pulse width measurement
    reg [15:0] pulse_counter = 0;
    reg [3:0]  short_pulse_count = 0;
    reg in_low = 0;

    localparam SHORT_PULSE_MAX = 700;   // <7us (HSYNC or serration)
    localparam VSYNC_MIN_EDGES = 6;     // 6+ short pulses in a row → VSYNC

    always @(posedge clk) begin
        if (!comp_sync) begin
            pulse_counter <= pulse_counter + 1;
            in_low <= 1;
        end else begin
            if (in_low) begin
                // End of low pulse
                if (pulse_counter <= SHORT_PULSE_MAX) begin
                    short_pulse_count <= short_pulse_count + 1;
                end else begin
                    short_pulse_count <= 0;
                end
                pulse_counter <= 0;
                in_low <= 0;
            end
        end

        // VSYNC activation
        if (short_pulse_count >= VSYNC_MIN_EDGES)
            vsync_out <= 1;

        // Reset when no short pulses are seen for a while
        if (pulse_counter > 8000) begin  // ~80us timeout with no serrations
            short_pulse_count <= 0;
            vsync_out <= 0;
        end
    end

endmodule