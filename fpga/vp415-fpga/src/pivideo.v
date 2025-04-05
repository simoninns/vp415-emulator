/************************************************************************
	
	pivideo.v
	Top module
	
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

module pivideo (
    input pixelClock,
    input nReset,
    input vsync,
    input hsync,
    input displayEnable,

    output clkX6,
    output [2:0] clkPhase,
    output csync,

    output [9:0] pixelX,
    output [9:0] pixelY,

    output frame_start_flag
);

    // -----------------------------------------------------------
    // Pi5 Pixel clock generation PLL

    // We use the Pi's DPI pixel clock as a base and multiply it
    // by 6 (=81 MHz). This is to keep everything in phase with
    // the Pi 5's pixel clock.
    pipixelclockpll pipixelclockpll0 (
        // Inputs
        .pixelClockIn(pixelClock),
        
        // Outputs
        .pixelClockX6_out(clkX6),
        .pixelClockPhase(clkPhase)
    );


    // -----------------------------------------------------------
    // Track the frame line and dot from the Pi
    wire isFieldOdd_pi;

    pi_tracker pi_tracker0 (
        // Inputs
        .pixelClockX6(clkX6),
        .pixelClockPhase(clkPhase),
        .nReset(nReset),
        .hsync_pi(hsync),
        .vsync_pi(vsync),
        .displayEnabled_pi(displayEnable),

        // Outputs
        .fieldLineDot_pi(pixelX),
        .frameLine_pi(pixelY),
        .isFieldOdd_pi(isFieldOdd_pi),
        .frame_start_flag(frame_start_flag)
    );

    // -----------------------------------------------------------
    // Generate the composite sync signal for the SCART output
    // locked to the Pi5 video
    csyncgenerator csyncgenerator0 (
        // Inputs
        .clk(clkX6),
        .hsync(hsync),
        .vsync(vsync),

        // Outputs
        .csync(csync)
    );

endmodule