/************************************************************************
	
	statusleds.v
	Status LEDs control
	
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

// Flash two LEDs on and off to show the FPGA is running
module statusleds(
    input nReset,
    input sysClock,

    output [1:0] leds
);

    // Delay counter for PWM
    reg [25:0] cnt;
    always @(posedge sysClock, negedge nReset) begin
        if (!nReset) begin
            cnt <= 26'b0000000000000000000000000;
        end else begin
            cnt <= cnt+1;
        end
    end

    // Ramp up and down the intensity
    reg [4:0] pwm;
    wire [3:0] intensity = cnt[25] ? cnt[24:21] : ~cnt[24:21];
    always @(posedge sysClock, negedge nReset) begin
        if (!nReset) begin
            pwm <= 5'b00000;
        end else begin
            pwm <= pwm[3:0] + intensity;
        end
    end

    // Drive the LEDs
    assign leds[0] = pwm[4];
    assign leds[1] = 5'b11111 - pwm[4];

endmodule