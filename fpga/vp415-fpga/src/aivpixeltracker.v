/************************************************************************
	
	aivpixeltracker.v
	Generate pixel x,y and display enable signals for the AIV source
	
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

// Track the active AIV frame.
// The output from this module is the active frame dot (0-719) and the
// active line number (0-576) and the display enable signal.
module aiv_active_frame_tracker (
    input wire clk,             // 81 MHz clock
    input wire nReset,          // active low reset

    input wire hsync,           // horizontal sync signal
    input wire vsync,           // vertical sync signal
    input wire isFieldOdd,       // 1 = odd field, 0 = even field

    output [9:0] active_frame_dot,  // active dot number (0-720)
    output [9:0] active_frame_line, // active line number (0-576)
    output display_enable,          // display enable signal
    output frame_start_flag,        // frame start flag
    output [15:0] debug           // debug output
);

    // Track the active field lines
    wire [9:0] active_field_line;
    wire isActiveFieldLine;
    aiv_active_line_tracker line_tracker (
        .clk(clk),
        .nReset(nReset),
        .vsync(vsync),
        .hsync(hsync),
        .active_line(active_field_line),
        .isActive(isActiveFieldLine)
    );

    // Track the active field dots
    wire [9:0] active_field_dot;
    wire isActiveFieldDot;
    aiv_active_dot_tracker dot_tracker (
        .clk(clk),
        .nReset(nReset),
        .hsync(hsync),
        .active_dot(active_field_dot),
        .isActive(isActiveFieldDot)
    );

    // Generate the active frame line based on the field line and field odd signal
    reg [9:0] active_frame_line_r = 10'b0; // 0-511
    reg [9:0] active_frame_dot_r = 10'b0; // 0-719
    reg display_enable_r = 1'b0;

    // Generate the frame start flag
    assign frame_start_flag = (active_field_line == 10'd0) & (active_field_dot == 10'd0) & (isActiveFieldLine & isActiveFieldDot) & isFieldOdd;

    // Debug output
    assign debug[0] = isFieldOdd;
    assign debug[1] = frame_start_flag;
    assign debug[2] = vsync;
    assign debug[3] = hsync;
    assign debug[4] = isActiveFieldLine & isActiveFieldDot;
    assign debug[15:5] = 14'b0;

    always @(posedge clk, negedge nReset) begin
        if (!nReset) begin
            active_frame_line_r <= 10'b0;
            active_frame_dot_r <= 10'b0;
            display_enable_r <= 1'b0;
        end else begin
            // Are we in an active region?
            if (isActiveFieldLine & isActiveFieldDot) begin
                // Set the display enable signal
                display_enable_r <= 1'b1;

                // Set the active frame line and dot based on the field odd signal
                if (isFieldOdd) begin
                    active_frame_line_r <= (active_field_line * 2) + 1;
                end else begin
                    active_frame_line_r <= (active_field_line * 2);
                end

                // Set the active frame dot (which is the same as the active field dot)
                active_frame_dot_r <= active_field_dot;
            end else begin
                // Not in an active region, clear the display enable signal
                display_enable_r <= 1'b0;
                active_frame_line_r <= 10'b0;
                active_frame_dot_r <= 10'b0;
            end
        end
    end

    // Connect internal registers to outputs
    assign active_frame_line = active_frame_line_r;
    assign active_frame_dot = active_frame_dot_r;
    assign display_enable = display_enable_r;

endmodule

// A field is 864 dots and 312 lines (0-863, 0-311)
// The active region is 720 dots and 288 lines (0-719, 0-287)

// Active lines are from 23 to 311
// Active dots are from 72 to 792

module aiv_active_dot_tracker (
    input wire clk,             // 81 MHz clock
    input wire nReset,          // active low reset

    input wire hsync,           // horizontal sync signal

    output [9:0] active_dot,    // active dot number (0-719)
    output isActive             // dot is active flag
);

    // Total period of the line is 64us which is 864 dots
    // So each dot is 74.074ns
    //
    // There are 12us of stuff before the active region starts
    // 12us is equivalent to 162 dots per line

    // Constants for active region
    localparam ACTIVE_H_START = 10'd72;  // Start of active horizontal region
    localparam ACTIVE_H_END = ACTIVE_H_START + 10'd720;   // End of active horizontal region

    // Registers for tracking dots
    reg [9:0] dot_r;        // current dot in line (0-863)
    reg [9:0] active_dot_r; // active dot (0-719)
    reg isActive_r;         // display enable signal

    // Clock divider for 13.5MHz dot clock (81MHz/6)
    reg [2:0] clk_div = 3'b0;

    always @(posedge clk, negedge nReset) begin
        if (!nReset) begin
            dot_r <= 10'b0;
            active_dot_r <= 10'b0;
            isActive_r <= 1'b0;
            clk_div <= 3'b0;
        end else begin
            // Reset dot counter if hsync is asserted
            if (hsync) begin
                dot_r <= 10'b0;
            end else begin
                // Increment the clock divider (dot clock is clk/6)
                clk_div <= clk_div + 1;

                // If we have a full clock cycle (divide by 6), update the dot counter
                if (clk_div == 3'b101) begin
                    dot_r <= dot_r + 1;
                    clk_div <= 3'b0; // Reset the clock divider
                end
            end

            // Check if we are in the active part of the line
            if (dot_r >= ACTIVE_H_START && dot_r < ACTIVE_H_END) begin
                // Active dot
                active_dot_r <= dot_r - ACTIVE_H_START;
                isActive_r <= 1'b1;
            end else begin
                // Not an active dot
                active_dot_r <= 10'b0;
                isActive_r <= 1'b0;
            end
        end
    end

    // Connect internal registers to outputs
    assign active_dot = active_dot_r;
    assign isActive = isActive_r;

endmodule

module aiv_active_line_tracker (
    input wire clk,             // 81 MHz clock
    input wire nReset,          // active low reset

    input wire vsync,           // vertical sync signal
    input wire hsync,           // horizontal sync signal

    output [9:0] active_line,   // active line number (0-287)
    output isActive             // line is active flag
);

    // Constants for active region
    localparam ACTIVE_V_START = 10'd23;  // Start of active vertical region
    localparam ACTIVE_V_END = ACTIVE_V_START + 10'd288;   // End of active vertical region

    // Registers for tracking lines
    reg [9:0] line_r;        // current line in field (0-311)
    reg [9:0] active_line_r; // active line (0-287)
    reg isActive_r;          // display enable signal

    always @(posedge clk, negedge nReset) begin
        if (!nReset) begin
            line_r <= 10'b0;
            active_line_r <= 10'b0;
            isActive_r <= 1'b0;
        end else begin
            // Reset line counter if vsync is asserted
            if (vsync) begin
                line_r <= 10'b0;
            end

            // Increment the line counter on hsync
            if (hsync) begin
                // Increment the line counter
                line_r <= line_r + 1;
            end

            // Check if we are in the active part of the field
            if (line_r >= ACTIVE_V_START && line_r < ACTIVE_V_END) begin
                // Active line
                active_line_r <= line_r - ACTIVE_V_START;
                isActive_r <= 1'b1;
            end else begin
                // Not an active line
                active_line_r <= 10'b0;
                isActive_r <= 1'b0;
            end
        end
    end

    // Connect internal registers to outputs
    assign active_line = active_line_r;
    assign isActive = isActive_r;

endmodule