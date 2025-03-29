/************************************************************************
    
    pulsestretcher.v
    Pulse stretcher module
    
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

// This module is to assist with debug using the picoscope.  If the pulse
// is too short, the picoscope will not be able to capture it reliably, so 
// this module will stretch the pulse to a longer duration of at least 10 clock
// cycles.  The DSO should see the signals upto 1ms/div.
module pulse_stretch (
    input wire clk,
    input wire in_pulse,
    output reg out_pulse
);

reg [3:0] counter;
reg pulse_active;

always @(posedge clk) begin
    if (in_pulse && !pulse_active) begin
        // Detect rising edge of in_pulse
        pulse_active <= 1'b1;
        counter <= 4'd10;
    end else if (pulse_active) begin
        if (counter > 0) begin
            // Decrement counter while active
            counter <= counter - 1;
        end else begin
            // Deactivate pulse after 10 clock cycles
            pulse_active <= 1'b0;
        end
    end
end

always @(posedge clk) begin
    // Set out_pulse based on pulse_active
    out_pulse <= pulse_active;
end

endmodule