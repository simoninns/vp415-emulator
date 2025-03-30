/************************************************************************
	
	pipixelclk.v
	Pixel clock x10 PLL with phase tracking
	
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

// Note: This module is used to generate a system clock that is in phase
// with the incoming pixel clock.  The incoming pixel clock is multiplied
// by 10 to provide a system clock that is 10 times faster.  The module
// also provides a /10 enable signal that is used to generate a 1 clock
// wide pulse every 10 system clocks.  This is used to generate a phase
// signal that is in phase with the original incoming pixel clock.

// Inbound pixel clock is: 13.500 MHz (x10 = 135.000 MHz)
//
// PLL configuration:
// Given input frequency:         13.500 MHz
// Requested output frequency:    135.000 MHz
// Achieved output frequency:     135.000 MHz
//
// 135.000 provides a 7.41 ns clock period
// pixelClockX1_en provides a /10 enable pulse (i.e. at 13.500 MHz)

// Note: This module is used to generate a system clock that is in phase
// with the incoming pixel clock.  The incoming pixel clock is multiplied
// by 6 to provide a system clock that is 6 times faster.  The module
// also provides a /6 enable signal that is used to generate a 1 clock
// wide pulse every 6 system clocks.  This is used to generate a phase
// signal that is in phase with the original incoming pixel clock.

// Inbound pixel clock is: 13.500 MHz (x6 = 81.000 MHz)
//
// PLL configuration:
// Given input frequency:         13.500 MHz
// Requested output frequency:    81.000 MHz
// Achieved output frequency:     81.000 MHz
//
// 81.000 provides a 12.35 ns clock period
// pixelClockX1_en provides a /6 enable pulse (i.e. at 13.500 MHz)

module pixelclockpll(
	input pixelClockIn,
	
	output pixelClockX6_out,
	output pixelClockX1_en
	);

	// Input pixel clock x6
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
		.REFERENCECLK(pixelClockIn),
		.PLLOUTCORE(pixelClockX6_out)
	);

	// Count the clock phases (since the pixel clock is x6)
	reg [2:0] currentPhase_r;
	assign pixelClockX1_en = (currentPhase_r == 3'b011) ? 1'b1 : 1'b0;

	initial begin
		currentPhase_r <= 3'b000;
	end

	always @(posedge pixelClockX6_out) begin
		currentPhase_r <= currentPhase_r + 3'b001;
		if (currentPhase_r == 3'b101) begin
			currentPhase_r <= 3'b000;
		end
	end

endmodule