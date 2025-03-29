/************************************************************************
	
	syncregenerator.v
	PAL 576i sync regenerator
	
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

module csync_edges (
    input wire clk,
    input wire csync,
    output reg csync_falling,
    output reg csync_rising
);

    reg csync_prev;

    always @(posedge clk) begin
        csync_prev <= csync;
        csync_falling <= csync_prev && ~csync;
        csync_rising  <= ~csync_prev && csync;
    end

endmodule

module csync_to_hsync (
    input wire clk,                 // 81 MHz clock
    input wire csync_falling,      // single-cycle pulse from csync_edges
    input wire csync_rising,       // additional input for rising edge during vsync
    output reg hsync               // horizontal sync output
);

    reg [15:0] time_since_last_hsync = 16'hFFFF;
    reg [1:0] startup_counter = 2'd3;

    localparam HSYNC_PERIOD_MIN  = 5000;  // ~61.7 us
    localparam HSYNC_PERIOD_MAX  = 5400;  // ~66.6 us
    localparam TIMEOUT           = HSYNC_PERIOD_MAX + 2000;

    wire csync_edge = csync_falling || csync_rising;

    always @(posedge clk) begin
        // Increment time since last accepted hsync
        if (time_since_last_hsync < 16'hFFFF)
            time_since_last_hsync <= time_since_last_hsync + 1;

        hsync <= 0;

        if (csync_edge) begin
            if (startup_counter != 0) begin
                startup_counter <= startup_counter - 1;
                time_since_last_hsync <= 0;
                hsync <= 1;
            end else if (time_since_last_hsync >= HSYNC_PERIOD_MIN && time_since_last_hsync <= HSYNC_PERIOD_MAX) begin
                time_since_last_hsync <= 0;
                hsync <= 1;
            end
            // Do not reset time_since_last_hsync if the pulse was rejected
        end

        // Recover if signal was lost and regained
        if (time_since_last_hsync > TIMEOUT) begin
            startup_counter <= 2'd3;
        end
    end

endmodule

// module csync_to_hsync (
//     input wire clk,                 // 81 MHz clock
//     input wire csync_falling,      // single-cycle pulse from csync_edges
//     output reg hsync               // horizontal sync output
// );

//     reg [8:0] hsync_stretch = 0;
//     localparam HSYNC_WIDTH = 380;  // ~4.7 us at 81 MHz

//     always @(posedge clk) begin
//         // Start stretching pulse on falling edge
//         if (csync_falling) begin
//             hsync_stretch <= HSYNC_WIDTH;
//         end else if (hsync_stretch != 0) begin
//             hsync_stretch <= hsync_stretch - 1;
//         end

//         hsync <= (hsync_stretch != 0);
//     end

// endmodule

module csync_to_vsync (
    input wire clk,            // 81 MHz clock
    input wire csync,
    input wire hsync,
    output reg vsync
);

    always @(posedge clk) begin
        vsync <= csync ^ hsync;
    end

endmodule
