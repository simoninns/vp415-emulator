/************************************************************************
	
	pi_pixel_clock_pll.v
	Pixel clock x6 PLL with phase tracking
	
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

module pi_pixel_clock_pll(
	input clk,
	
	output clk_out,
	output [2:0] clk_out_phase,
	);

	// Use PLL to multiply clk by 6
	// Generated using: icepll -i 13.500 -o 81.000 -m
	SB_PLL40_CORE #(
		.FEEDBACK_PATH("SIMPLE"),
		.DIVR(4'b0000),		// DIVR =  0
		.DIVF(7'b0101111),	// DIVF = 47
		.DIVQ(3'b011),		// DIVQ =  3
		.FILTER_RANGE(3'b001)	// FILTER_RANGE = 1
	) uut (
		.LOCK(),
		.RESETB(1'b1),
		.BYPASS(1'b0),
		.REFERENCECLK(clk),
		.PLLOUTCORE(clk_out)
	);

	// Base clock is 13.5MHz, so we have 6 phases due
    // to the 81 MHz output clock
	reg [2:0] clk_out_phase_r = 3'b000;
    assign clk_out_phase = clk_out_phase_r;

	always @(posedge clk_out) begin
		clk_out_phase_r <= clk_out_phase_r + 3'b001;
		if (clk_out_phase_r == 3'b101) begin
			clk_out_phase_r <= 3'b000;
		end
	end

endmodule