/************************************************************************
	
	csyncprescaler.v
	AIV Csync pre-scaler
	
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

module csync_prescaler (
    input wire clk_100mhz,  // 100 MHz system clock
    input wire csync,       // 15.625 kHz Negative Polarity PAL Composite Sync signal
    output reg ref_clk      // Reference clock for PLL (~250-500 kHz)
);



endmodule