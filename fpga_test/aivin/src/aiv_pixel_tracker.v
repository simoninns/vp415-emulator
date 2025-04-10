/************************************************************************
    
    aiv_pixel_tracker.v
    Track the AIV pixel position and generate pixel clock enable signal
    
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

module aiv_pixel_tracker (
    input wire clk,             // 81 MHz clock

    input wire hsync,           // horizontal sync signal
    input wire vsync,           // vertical sync signal
    input wire odd_field,       // 1 = odd field, 0 = even field

    output pixel_ce,            // pixel clock enable signal
    output [9:0] pixel_x,       // active dot number (0-720)
    output [9:0] pixel_y,       // active line number (0-576)
);

    // Track the active field lines
    wire [9:0] active_pos_y;
    wire active_line_flag;
    aiv_active_line_tracker line_tracker (
        .clk(clk),
        .vsync(vsync),
        .hsync(hsync),
        .active_pos_y(active_pos_y),
        .active_flag(active_line_flag)
    );

    // Track the active field dots
    wire [9:0] active_pos_x;
    wire active_dot_flag;
    wire dot_pixel_ce;
    aiv_active_dot_tracker dot_tracker (
        .clk(clk),
        .hsync(hsync),
        .active_pos_x(active_pos_x),
        .active_flag(active_dot_flag),
        .pixel_ce(dot_pixel_ce)
    );

    // Generate the pixel clock enable signal by combining the active line flag with the dot pixel clock enable signal
    assign pixel_ce = dot_pixel_ce & active_line_flag;

    // Generate the active frame line based on the field line and field odd signal
    reg [9:0] active_frame_pos_y_r = 10'b0; // 0-511
    reg [9:0] active_frame_pos_x_r = 10'b0; // 0-719

    always @(posedge clk) begin
        // Are we in an active region?
        if (active_line_flag & active_dot_flag) begin
            // Set the active frame line and dot based on the field odd signal
            if (odd_field) begin
                active_frame_pos_y_r <= (active_pos_y * 2) + 1;
            end else begin
                active_frame_pos_y_r <= (active_pos_y * 2);
            end

            // Set the active frame dot (which is the same as the active field dot)
            active_frame_pos_x_r <= active_pos_x;
        end else begin
            // Not in an active region
            active_frame_pos_y_r <= 10'b0;
            active_frame_pos_x_r <= 10'b0;
        end
    end

    // Connect internal registers to outputs
    assign pixel_y = active_frame_pos_y_r;
    assign pixel_x = active_frame_pos_x_r;

endmodule

module aiv_active_line_tracker (
    input wire clk,             // 81 MHz clock

    input wire vsync,           // vertical sync signal
    input wire hsync,           // horizontal sync signal

    output [9:0] active_pos_y,  // active line number (0-287)
    output active_flag          // line is active flag
);

    // Constants for active region
    localparam ACTIVE_V_START = 10'd23;  // Start of active vertical region
    localparam ACTIVE_V_END = ACTIVE_V_START + 10'd288;   // End of active vertical region

    // Registers for tracking lines
    reg [9:0] line_r = 10'b0;         // current line in field (0-311)
    reg [9:0] active_pos_y_r = 10'b0;  // active line (0-287)
    reg active_flag_r = 1'b0;            // display enable signal

    always @(posedge clk) begin
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
            active_pos_y_r <= line_r - ACTIVE_V_START;
            active_flag_r <= 1'b1;
        end else begin
            // Not an active line
            active_pos_y_r <= 10'b0;
            active_flag_r <= 1'b0;
        end
    end

    // Connect internal registers to outputs
    assign active_pos_y = active_pos_y_r;
    assign active_flag = active_flag_r;

endmodule

// A field is 864 dots and 312 lines (0-863, 0-311)
// The active region is 720 dots and 288 lines (0-719, 0-287)

// Active lines are from 23 to 311
// Active dots are from 72 to 792

module aiv_active_dot_tracker (
    input wire clk,             // 81 MHz clock
    input wire hsync,           // horizontal sync signal

    output [9:0] active_pos_x,  // active dot number (0-719)
    output active_flag,         // dot is active flag
    output pixel_ce             // pixel clock enable signal
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
    reg [9:0] dot_r = 10'b0;           // current dot in line (0-863)
    reg [9:0] active_pos_x_r = 10'b0;  // active pixel (0-719)
    reg active_flag_r = 1'b0;          // display enable signal
    reg pixel_ce_r = 1'b0;             // pixel clock enable signal
    reg [2:0] phase_tracker_r = 3'b000;  // clock phase

    always @(posedge clk) begin
        // Reset dot counter if hsync is asserted
        if (hsync) begin
            dot_r <= 10'b0;
            phase_tracker_r <= 3'b000;
        end else begin
            // Increment the phase tracker
            phase_tracker_r <= phase_tracker_r + 3'b001;

            if (phase_tracker_r == 3'b101) begin
                // Reset the phase tracker
                phase_tracker_r <= 3'b000;
            end

            // Update the dot counter
            if (phase_tracker_r == 3'b000) begin
                dot_r <= dot_r + 1;
                pixel_ce_r <= 1'b1; // Enable pixel clock
            end else begin
                pixel_ce_r <= 1'b0; // Disable pixel clock
            end
        end

        // Check if we are in the active part of the line
        if (dot_r >= ACTIVE_H_START && dot_r < ACTIVE_H_END) begin
            // Active dot
            active_pos_x_r <= dot_r - ACTIVE_H_START;
            active_flag_r <= 1'b1;
        end else begin
            // Not an active dot
            active_pos_x_r <= 10'b0;
            active_flag_r <= 1'b0;
            pixel_ce_r <= 1'b0; // Keep low when not in active region
        end
    end

    // Connect internal registers to outputs
    assign active_pos_x = active_pos_x_r;
    assign active_flag = active_flag_r;
    assign pixel_ce = pixel_ce_r;

endmodule