/************************************************************************
    
    rgb111to666.v
    Convert RGB111 to RGB666
    
    VP415-Emulator FPGA
    Copyright (C) 2025 Simon Inns
    
    This file is part of VP415-Emulator.
    
    Domesday Duplicator is free software: you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.
    
    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
    
    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Email: simon.inns@gmail.com
    
************************************************************************/

// Disable Verilog implicit definitions
`default_nettype none

module rgb111to666 (
    input wire clk,          // 81 MHz clock
    input wire red_in,
    input wire green_in,
    input wire blue_in,

    output reg [5:0] red_out,
    output reg [5:0] green_out,
    output reg [5:0] blue_out
);

    // Convert RGB111 to RGB666
    always @(posedge clk) begin
        if (red_in) begin
            red_out <= 6'b111111;
        end else begin
            red_out <= 6'b000000;
        end
        if (green_in) begin
            green_out <= 6'b111111;
        end else begin
            green_out <= 6'b000000;
        end
        if (blue_in) begin
            blue_out <= 6'b111111;
        end else begin
            blue_out <= 6'b000000;
        end
    end

endmodule