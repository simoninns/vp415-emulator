/************************************************************************
	
	beebthru.v
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
    // On-board clock
    input clock100Mhz,

    // On-board inputs
    input [1:0] buttons,

    // Raspberry Pi GPIOs
    input [27:0] pi_gpio,

    // SCART RGB666 SCART output with composite sync
    output [5:0] red_scartOut,
    output [5:0] green_scartOut,
    output [5:0] blue_scartOut,
    output csync_scartOut,

    // RGB111 DIN input with composite sync from BBC Master AIV
    input aiv_redIn,
    input aiv_greenIn,
    input aiv_blueIn,
    input aiv_csyncIn,

    // iCE40HX8K-EVB LEDs
    output [1:0] leds,

    // PicoScope MSO
    output [15:0] picoScope,
);

    // Picoscope output

    // Stretch the hsync pulse for debugging
    wire stretched_hsync;
    pulse_stretch pulse_stretch0 (
        .clk(pixelClockX6_out),
        .in_pulse(hsync),
        .out_pulse(stretched_hsync)
    );

    // Stretch the vsync pulse for debugging
    wire stretched_vsync;
    pulse_stretch pulse_stretch1 (
        .clk(pixelClockX6_out),
        .in_pulse(vsync),
        .out_pulse(stretched_vsync)
    );

    assign picoScope[0] = aiv_csyncIn_sync;
    assign picoScope[1] = stretched_hsync;
    assign picoScope[2] = stretched_vsync;
    assign picoScope[3] = 0;
    assign picoScope[4] = 0;
    assign picoScope[5] = 0;
    assign picoScope[15:6] = 0;

    // -----------------------------------------------------------
    // Pixel clock generation PLL

    // We use the Pi's DPI pixel clock as a base and multiply it
    // by 10.  The module also produces a /6 enable signal running
    // at the original pixel clock's rate.
    wire pixelClock_piIn;
    assign pixelClock_piIn = pi_gpio[0];

    wire pixelClock;
    wire pixelClockX6_out;
    wire pixelClockX1_en;

    pixelclockpll pixelclockpll0 (
        // Inputs
        .pixelClockIn(pixelClock_piIn),
        
        // Outputs
        .pixelClockX6_out(pixelClockX6_out),
        .pixelClockX1_en(pixelClockX1_en)
    );

    // -----------------------------------------------------------
    // Syncronize the incoming async signals to the pixel clock
    // This is done using a 2-stage synchronizer to avoid metastability

    wire aiv_redIn_sync;
    wire aiv_greenIn_sync;
    wire aiv_blueIn_sync;
    wire aiv_csyncIn_sync;

    sync2 sync_aiv_redIn (
        .clk(pixelClockX6_out),
        .async_in(aiv_redIn),
        .sync_out(aiv_redIn_sync)
    );
    sync2 sync_aiv_greenIn (
        .clk(pixelClockX6_out),
        .async_in(aiv_greenIn),
        .sync_out(aiv_greenIn_sync)
    );
    sync2 sync_aiv_blueIn (
        .clk(pixelClockX6_out),
        .async_in(aiv_blueIn),
        .sync_out(aiv_blueIn_sync)
    );
    sync2 sync_aiv_csyncIn (
        .clk(pixelClockX6_out),
        .async_in(aiv_csyncIn),
        .sync_out(aiv_csyncIn_sync)
    );

    // -----------------------------------------------------------
    // Composite sync to horizontal sync regenerator

    wire csync_falling;
    wire csync_rising;

    csync_edges csync_edges0 (
        .clk(pixelClockX6_out),
        .csync(aiv_csyncIn_sync),
        .csync_falling(csync_falling),
        .csync_rising(csync_rising)
    );

    wire hsync;
    csync_to_hsync csync_to_hsync0 (
        .clk(pixelClockX6_out),
        .csync_falling(csync_falling),
        .csync_rising(csync_rising),
        .hsync(hsync)
    );

    wire vsync;
    strip_hsync_from_csync strip_hsync_from_csync0 (
        .clk(pixelClockX6_out),
        .csync(aiv_csyncIn_sync),
        .hsync_pulse(hsync),
        .vsync_only(vsync)
    );

    // -----------------------------------------------------------
    // Basic hardware functions

    // nReset signal generation (as the iCE40 board doesn't have one)
    wire nReset;

    nreset nreset0 (
        .sysClock(pixelClockX6_out),
        .nReset(nReset)
    );

    // Status LED control
    wire [1:0] leds;

    statusleds statusleds0 (
        // Inputs
        .sysClock(pixelClockX6_out),
        .nReset(nReset),
        
        // Outputs
        .leds(leds)
    );

endmodule