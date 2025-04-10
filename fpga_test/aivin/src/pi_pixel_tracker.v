/************************************************************************
    
    pi_pixel_tracker.v
    Track the Pi pixel position and generate pixel clock enable signal
    
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

module pi_pixel_tracker (
    input wire clk,             // 81 MHz clock
    input wire [2:0] clk_phase, // Clock phase input

    input wire hsync,           // horizontal sync signal
    input wire vsync,           // vertical sync signal
    input wire display_en,

    output pixel_ce,            // pixel clock enable signal
    output [9:0] pixel_x,       // active dot number (0-720)
    output [9:0] pixel_y,       // active line number (0-576)
);

    // Odd/Even Field tracker
    wire odd_field_pi;

    pi_fieldTracker pi_fieldTracker0 (
        .clk(clk),
        .clk_phase(clk_phase),
        .vSync(vsync),
        .hSync(hsync),
        
        .odd_field(odd_field_pi)
    );

    // Line and dot tracker
    wire [9:0] fieldLine_pi;
    wire [9:0] fieldLineDot_pi;

    pi_linetracker pi_linetracker0 (
        .clk(clk),
        .clk_phase(clk_phase),
        .displayEnabled(display_en),
        .vSync(vsync),
        
        .fieldLine(fieldLine_pi),
        .fieldLineDot(fieldLineDot_pi),
    );

    // Frame tracker
    wire [9:0] frameLine_pi;

    pi_frameTracker pi_frameTracker0 (
        .clk(clk),
        .clk_phase(clk_phase),
        .fieldLine(fieldLine_pi),
        .odd_field(odd_field_pi),
        
        .frameLine(frameLine_pi)
    );

    assign pixel_x = fieldLineDot_pi;
    assign pixel_y = frameLine_pi;

    // Generate the pixel clock enable signal
    reg pixel_ce_r = 1'b0;
    assign pixel_ce = pixel_ce_r;

    always @(posedge clk) begin
        if (clk_phase == 3'b0 && display_en) begin
            // Set the pixel clock enable signal
            pixel_ce_r <= 1'b1;
        end else begin
            pixel_ce_r <= 1'b0;
        end
    end

endmodule

module pi_frameTracker (
    input clk,
    input [2:0] clk_phase,
    input [9:0] fieldLine,
    input odd_field,
    
    output [9:0] frameLine
);

    reg [9:0] frameLine_r = 1'b0;
    assign frameLine = frameLine_r;

    always @(posedge clk) begin
        if (clk_phase == 3'b0) begin
            if (odd_field) begin
                frameLine_r <= (fieldLine * 2);
            end
            else begin
                frameLine_r <= (fieldLine * 2) + 1;
            end
        end
    end

endmodule

module pi_fieldTracker (
    input clk,
    input [2:0] clk_phase,
    input nReset,
    input vSync,
    input hSync,
    
    output odd_field
);

    // Note:
    //
    // The Pi DPI is interlaced which means we get two fields per frame
    // and therefore two vSync pulses per frame.  This logic detects
    // if the vSync is for the odd or even field and outputs a flag
    // following the vSync pulse to indicate which field is being displayed.
    //
    // Odd fields are rendered first, even fields are rendered second

    reg odd_field_r = 1'b0;
    assign odd_field = odd_field_r;
    reg prevVSync_r = 1'b1;

    always @(posedge clk) begin
        if (clk_phase == 3'b0) begin
            // On the falling edge of the vSync sample the hSync
            // If hSync is high then we are in the odd field and oddFieldSync is held high until the rising edge of the vSync
            // If hSync is low then we are in the even field and evenFieldSync is held high until the rising edge of the vSync

            // Detect the falling edge of the vSync
            if (vSync == 0 && prevVSync_r == 1) begin
                // Sample the hSync
                if (hSync == 1) begin
                    // Odd field
                    odd_field_r <= 1;
                end
                else begin
                    // Even field
                    odd_field_r <= 0;
                end
                prevVSync_r <= 0;
            end

            // Detect the rising edge of the vSync
            if (vSync == 1 && prevVSync_r == 0) begin
                prevVSync_r <= 1;
            end
        end
    end

endmodule

module pi_linetracker (
    input clk,
    input [2:0] clk_phase,

    input displayEnabled,
    input vSync,

    output [9:0] fieldLine,
    output [9:0] fieldLineDot,
);

    // displayEnabled is true when the pixel clock is in the visible area of a field line
    // So we need to count the pixel clock when displayEnabled is true to track the 720 dots per line
    // Each field has 288 lines which are also counted

    reg [9:0] fieldLine_r = 1'b0; // Current field line (0-287)
    reg [9:0] fieldLineDot_r = 1'b0; // Current field line dot (0-719)

    assign fieldLine = fieldLine_r;
    assign fieldLineDot = fieldLineDot_r - 1;

    always @(posedge clk) begin
        if (clk_phase == 3'b0) begin
            if (displayEnabled) begin
                fieldLineDot_r <= fieldLineDot_r + 1;

                // Check for end of line
                if (fieldLineDot_r == 719) begin
                    fieldLineDot_r <= 0;
                    fieldLine_r <= fieldLine_r + 1;
                end
            end

            if (!vSync) begin
                fieldLine_r <= 0;
                fieldLineDot_r <= 0;
            end
        end
    end

endmodule