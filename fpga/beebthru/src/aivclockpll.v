/************************************************************************
	
	aivclockpll.v
	AIV Csync Clock PLL
	
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

module csync_to_pixel_clock (
    input wire clk_100mhz,  // External 100 MHz clock
    input wire csync,       // 15.625 kHz Composite Sync input
    output wire pixel_clk,  // 13.5 MHz output clock
	output wire ref_clk	    // Scaled CSYNC, used as PLL input
);

    //wire ref_clk;  // Scaled CSYNC clock

    // Generate a reference clock (~250-500 kHz) from CSYNC
    csync_prescaler prescaler_inst (
        .clk_100mhz(clk_100mhz),
        .csync(csync),
        .ref_clk(ref_clk)  // Scaled CSYNC, used as PLL input
    );

    wire clk_pll;

    // PLL Configuration for generating 13.5 MHz from scaled CSYNC
    SB_PLL40_CORE #(
        .FEEDBACK_PATH("SIMPLE"),
        .DIVR(4'b0000),       // No pre-division (divide by 1)
        .DIVF(7'b1000111),    // Multiply by 71
        .DIVQ(3'b100),        // Divide by 16
        .FILTER_RANGE(3'b001) // PLL Filter
    ) pll_inst (
        .REFERENCECLK(ref_clk), // Feed scaled CSYNC clock into PLL
        .PLLOUTGLOBAL(clk_pll),
        .RESETB(1'b1),
        .BYPASS(1'b0)
    );

    assign pixel_clk = clk_pll;

endmodule