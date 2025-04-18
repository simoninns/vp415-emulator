/************************************************************************
	
	csyncgenerator.v
	PAL 576i sync generator
	
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

// This module takes the horizontal and vertical sync pulses from the
// sync regenerator and combines them back into a composite sync signal.
// The horizontal sync pulse is 4us wide and the vertical sync pulse
// is 128us wide. The composite sync signal is generated by XORing the
// horizontal and vertical sync signals together. The output is inverted
// to create the final composite sync signal.

module csyncgenerator(
    input wire clk,		// 81 MHz clock
    input wire hsync,	// horizontal sync input
    input wire vsync,	// vertical sync input

    output wire csync	// composite sync output
);

    // Generate the hsync and vsync and then XOR them
    // to create the composite sync signal
    wire hsync_out;
    wire vsync_out;

    // Generate the hsync pulse
    hsync_pulse_generator hsync_gen (
        .clk(clk),
        .hsync_pulse(hsync),
        .hsync_out(hsync_out)
    );
    // Generate the vsync pulse
    vsync_pulse_generator vsync_gen (
        .clk(clk),
        .vsync_pulse(vsync),
        .vsync_out(vsync_out)
    );
    // Combine the hsync and vsync signals and invert
    // to create the composite sync signal
    assign csync = ~(hsync_out ^ vsync_out);
endmodule

module hsync_pulse_generator (
    input  wire clk,           // 81 MHz clock
    input  wire hsync_pulse,   // single-cycle pulse input
    output reg  hsync_out      // output pulse, 4us wide
);

    localparam integer PULSE_WIDTH = 324;  // 4us at 81 MHz

    reg [8:0] counter = 0;                 // 9 bits enough for up to 512
    reg active = 0;

    always @(posedge clk) begin
        if (hsync_pulse) begin
            hsync_out <= 1'b1;
            counter <= 1;
            active <= 1;
        end else if (active) begin
            if (counter < PULSE_WIDTH) begin
                counter <= counter + 1;
            end else begin
                hsync_out <= 1'b0;
                active <= 0;
            end
        end
    end

endmodule

module vsync_pulse_generator (
    input  wire clk,           // 81 MHz clock
    input  wire vsync_pulse,   // single-cycle pulse input (start of vsync)
    output reg  vsync_out      // output pulse, 128us wide
);

    localparam integer PULSE_WIDTH = 10368;  // 128us at 81 MHz

    reg [13:0] counter = 0;                  // 14 bits = up to 16,384
    reg active = 0;

    always @(posedge clk) begin
        if (vsync_pulse) begin
            vsync_out <= 1'b1;
            counter <= 1;
            active <= 1;
        end else if (active) begin
            if (counter < PULSE_WIDTH) begin
                counter <= counter + 1;
            end else begin
                vsync_out <= 1'b0;
                active <= 0;
            end
        end
    end

endmodule
