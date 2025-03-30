/************************************************************************
	
	framebuffer.v
	SRAM framebuffer for RGB111 PAL 576i video
	
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

// module framebuffer (
//     input wire clk,             // 81 MHz clock
//     input wire nReset,          // active low reset
    
//     // SRAM Interface (Samsung K6R4016V1D)
//     output wire [17:0] SRAM0_A,
//     inout wire [15:0] SRAM0_D,
//     output reg SRAM0_nOE,
//     output reg SRAM0_nWE,
//     output wire SRAM0_nCS
// );

//     // Internal SRAM data bus management
//     wire [15:0] data_pins_in;
//     reg [15:0] data_pins_out;
//     reg data_pins_out_en;

//     SB_IO #(
//         .PIN_TYPE(6'b1010_01)
//     ) sram_data_pins [15:0] (
//         .PACKAGE_PIN(SRAM0_D),
//         .OUTPUT_ENABLE(data_pins_out_en),
//         .D_OUT_0(data_pins_out),
//         .D_IN_0(data_pins_in)
//     );

//     assign SRAM0_nCS = 1'b0; // Always enabled
//     assign SRAM0_A = current_addr;

// endmodule