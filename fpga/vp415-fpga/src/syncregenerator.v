/************************************************************************
	
	syncregenerator.v
	PAL 576i sync regenerator
	
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

module sync_regenerator_pal576i (
	input wire clk,		// 81 MHz clock
	input wire csync,	// composite sync input

	output hsync,		// horizontal sync output
	output vsync,		// vertical sync output
	output isFieldOdd	// 1 = odd field, 0 = even
);
	wire csync_falling;	// falling edge of csync
	wire csync_rising;	// rising edge of csync

	// Generate the falling and rising edges of the csync signal
	csync_edges csync_edges_inst (
		.clk(clk),
		.csync(csync),
		.csync_falling(csync_falling),
		.csync_rising(csync_rising)
	);

	// Generate the hsync pulse from the csync edges
	csync_to_hsync csync_to_hsync_inst (
		.clk(clk),
		.csync_falling(csync_falling),
		.csync_rising(csync_rising),
		.hsync(hsync)
	);

	// Strip the hsync from the csync signal to get the vsync signal
	strip_hsync_from_csync strip_hsync_from_csync_inst (
		.clk(clk),
		.csync(csync),
		.hsync_pulse(hsync),
		.vsync_only(vsync)
	);

	// Detect field type (odd/even) based on vsync pulse
	detect_field_type_pal detect_field_type_pal_inst (
		.clk(clk),
		.hsync_pulse(hsync),
		.vsync_pulse(vsync),
		.field_is_odd(isFieldOdd)
	);

endmodule

// This module takes the csync and outputs two pulse-trains, one containing
// all the falling edges of csync and the other containing all the rising edges.
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

// This module takes the csync edges and outputs a hsync pulse.
module csync_to_hsync (
    input wire clk,                // 81 MHz clock
    input wire csync_falling,      // single-cycle pulse from csync_edges
    input wire csync_rising,       // additional input for rising edge during vsync
    output reg hsync               // horizontal sync output
);

    reg [15:0] time_since_last_hsync = 16'hFFFF;
    reg [1:0] startup_counter = 2'd3;
    reg locked = 0;

    localparam HSYNC_PERIOD_MIN  = 5000;  // ~61.7 us
    localparam HSYNC_PERIOD_MAX  = 5400;  // ~66.6 us
    localparam TIMEOUT           = HSYNC_PERIOD_MAX + 2000;

	// When unlocked, the csync_falling edge is used to detect the start of a hsync
	// When locked, the csync_rising and falling edges are used to detect the start
	// of a hsync (in order to detect hsync during vsync)
    wire csync_edge = (locked) ? (csync_falling || csync_rising) : csync_falling;

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
                if (startup_counter == 1) locked <= 1;  // Lock after final startup sync
            end else if (time_since_last_hsync >= HSYNC_PERIOD_MIN && time_since_last_hsync <= HSYNC_PERIOD_MAX) begin
                time_since_last_hsync <= 0;
                hsync <= 1;
            end
            // Do not reset time_since_last_hsync if the pulse was rejected
        end

        // Recover if signal was lost and regained
        if (time_since_last_hsync > TIMEOUT) begin
            startup_counter <= 2'd3;
            locked <= 0;
        end
    end

endmodule

// This module uses the hsync pulse as a mask to strip the hsync from the csync signal
// which leaves the vsync signal intact.  The vsync signal is then used to generate a
// one-cycle pulse at the start of the vsync period.
module strip_hsync_from_csync (
    input wire clk,
    input wire csync,
    input wire hsync_pulse,    // single-cycle pulse at start of hsync
    output reg vsync_only      // one-cycle pulse at vsync start
);

    reg [15:0] counter = 16'hFFFF;
    reg vsync_active = 0;
    reg csync_d = 1'b1;        // delayed csync
    wire csync_falling;

    // Timing constants (at 81 MHz)
    localparam HSYNC_DELAY     = 648;    // 8us
    localparam VSYNC_DURATION  = 3564;   // 44us
    localparam ACTIVE_START    = HSYNC_DELAY;
    localparam ACTIVE_END      = HSYNC_DELAY + VSYNC_DURATION;

    // Falling edge: high to low
    assign csync_falling = (csync_d == 1'b1 && csync == 1'b0);

    always @(posedge clk) begin
        csync_d <= csync;

        // Reset counter on hsync pulse
        if (hsync_pulse) begin
            counter <= 0;
        end else if (counter < ACTIVE_END) begin
            counter <= counter + 1;
        end

        // Generate a one-cycle pulse at falling edge of csync,
        // but only during the expected vsync window
        if (!vsync_active && csync_falling && counter >= ACTIVE_START && counter < ACTIVE_END) begin
            vsync_only <= 1'b1;
            vsync_active <= 1'b1;
        end else begin
            vsync_only <= 1'b0;
        end

        // Reset vsync_active when we leave the vsync mask window
        if (counter >= ACTIVE_END) begin
            vsync_active <= 1'b0;
        end
    end

endmodule

module detect_field_type_pal (
    input  wire clk,
    input  wire hsync_pulse,    // single-cycle
    input  wire vsync_pulse,    // single-cycle
    output reg  field_is_odd    // 1 = odd field, 0 = even
);

    reg [15:0] counter = 0;

    // 20 us = 1620 cycles at 81 MHz
    localparam THRESHOLD_20US = 1620;

    always @(posedge clk) begin
        // Reset/start the counter on each hsync
        if (hsync_pulse) begin
            counter <= 0;
        end else if (counter < 16'hFFFF) begin
            counter <= counter + 1;
        end

        // Sample counter on vsync pulse
        if (vsync_pulse) begin
            field_is_odd <= ~(counter <= THRESHOLD_20US);
        end
    end

endmodule
