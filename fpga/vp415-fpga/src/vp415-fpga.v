/************************************************************************
	
	vp415-fpga.v
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

module top(
    // Raspberry Pi GPIOs
    input [27:0] pi_gpio,

    // SCART RGB666 SCART output with composite sync
    output [17:0] rgb_scart_666,
    output csync_scart,

    // RGB111 DIN input with composite sync from BBC Master AIV
    input [2:0] rgb_aiv_111,
    input aiv_csync,

    // iCE40HX8K-EVB LEDs
    output [1:0] leds,

    // PicoScope MSO
    output [15:0] picoScope,

    // Samsung K6R4016V1D-TC10 512K SRAM 
    output [17:0] SRAM0_A,
    inout [15:0] SRAM0_D,
    output SRAM0_nOE,
    output SRAM0_nWE,
    output SRAM0_nCS
);

    // -----------------------------------------------------------
    // Picoscope debug output mapping
    // assign picoScope[0] = frame_start_flag_pi;
    // assign picoScope[1] = frame_start_flag_aiv;
    // assign picoScope[15:2] = 16'b0;

    // -----------------------------------------------------------
    // SCART output (ensures output is blanked when not in the active area)
    assign rgb_scart_666 = displayEnable_pi ? rgb_vm_666 : 18'b0;

    // -----------------------------------------------------------
    // Pi 5 DPI video input signals
    wire displayEnable_pi; // Active high when in the active display area
    assign displayEnable_pi = pi_gpio[1];

    wire [17:0] rgb_pi_666;
    assign rgb_pi_666[17:0] = {pi_gpio[21:16], pi_gpio[15:10], pi_gpio[9:4]};

    wire sysClk;
    wire [2:0] sysClkPhase;

    wire [9:0] pixelX_pi; // Pi pixel X coordinate
    wire [9:0] pixelY_pi; // Pi pixel Y coordinate

    wire frame_start_flag_pi;

    pivideo pivdeo0 (
        // Inputs
        .pixelClock(pi_gpio[0]),
        .nReset(nReset),
        .vsync(pi_gpio[2]),
        .hsync(pi_gpio[3]),
        .displayEnable(displayEnable_pi),

        // Outputs
        .clkX6(sysClk),
        .clkPhase(sysClkPhase),
        .csync(csync_scart),

        .pixelX(pixelX_pi),
        .pixelY(pixelY_pi),

        .frame_start_flag(frame_start_flag_pi)
    );

    // -----------------------------------------------------------
    // AIV video input signals
    wire [17:0] rgb_aiv_666;
    wire frame_start_flag_aiv;

    aivvideo aivvideo0 (
        // Inputs
        .sysClk(sysClk),
        .nReset(nReset),
        .sysClkPhase(sysClkPhase),

        // AIV video input signals
        .rgb_111(rgb_aiv_111),
        .csync(aiv_csync),

        .displayEnable_pi(displayEnable_pi),
        .frame_start_flag_pi(frame_start_flag_pi),

        // SRAM interface
        .SRAM0_A(SRAM0_A),
        .SRAM0_D(SRAM0_D),
        .SRAM0_nCS(SRAM0_nCS),
        .SRAM0_nOE(SRAM0_nOE),
        .SRAM0_nWE(SRAM0_nWE),

        // RGB666 Output
        .rgb_666(rgb_aiv_666),

        .frame_start_flag_aiv(frame_start_flag_aiv),
        .debug(picoScope)
    );
    
    // -----------------------------------------------------------
    // Video mixer (RGB666)
    wire [17:0] rgb_vm_666;

    videomixer videomixer0 (
        .pixelClockX6(sysClk),
        .pixelClockPhase(sysClkPhase),
        .nReset(nReset),

        // The AIV video is the foreground
        .rgb_fg(rgb_aiv_666),

        // The Pi video is the background
        .rgb_bg(rgb_pi_666),

        // Video output
        .rgb_out(rgb_vm_666)
    );

    // -----------------------------------------------------------
    // nReset signal generation (as the iCE40 board doesn't have one)
    wire nReset;

    nreset nreset0 (
        .sysClock(sysClk),
        .nReset(nReset)
    );

    // -----------------------------------------------------------
    // Status LED - Flashes the LEDs to show we are running and
    // clock is present
    statusleds statusleds0 (
        // Inputs
        .sysClock(sysClk),
        .nReset(nReset),
        
        // Outputs
        .leds(leds)
    );

endmodule