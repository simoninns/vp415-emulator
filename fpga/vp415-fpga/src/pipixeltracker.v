/************************************************************************
	
	pipixeltracker.v
	Generate pixel x,y and display enable signals for the Pi5 source
	
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

module pi_tracker (
    input pixelClockX6,
    input [2:0] pixelClockPhase,
    input nReset,

    input vsync_pi,
    input hsync_pi,
    input displayEnabled_pi,

    output [9:0] fieldLineDot_pi,
    output [9:0] frameLine_pi,
    output isFieldOdd_pi
);

    // Odd/Even Field tracker
    wire isFieldOdd_pi;

    pi_fieldTracker pi_fieldTracker0 (
        .pixelClockX6(pixelClockX6),
        .pixelClockPhase(pixelClockPhase),
        .nReset(nReset),
        .vSync(vsync_pi),
        .hSync(hsync_pi),
        
        .isFieldOdd(isFieldOdd_pi)
    );

    // Line and dot tracker
    wire [9:0] fieldLine_pi;
    wire [9:0] fieldLineDot_pi;

    pi_linetracker pi_linetracker0 (
        .pixelClockX6(pixelClockX6),
        .pixelClockPhase(pixelClockPhase),
        .nReset(nReset),
        .displayEnabled(displayEnabled_pi),
        .vSync(vsync_pi),
        
        .fieldLine(fieldLine_pi),
        .fieldLineDot(fieldLineDot_pi),
    );

    // Frame tracker
    wire [9:0] frameLine_pi;

    pi_frameTracker pi_frameTracker0 (
        .pixelClockX6(pixelClockX6),
        .pixelClockPhase(pixelClockPhase),
        .nReset(nReset),
        .fieldLine(fieldLine_pi),
        .isFieldOdd(isFieldOdd_pi),
        
        .frameLine(frameLine_pi)
    );

endmodule

module pi_frameTracker (
    input pixelClockX6,
    input [2:0] pixelClockPhase,
    input nReset,
    input [9:0] fieldLine,
    input isFieldOdd,
    
    output [9:0] frameLine
);

    reg [9:0] frameLine_r;
    assign frameLine = frameLine_r;

    always @(posedge pixelClockX6, negedge nReset) begin
        if (!nReset) begin
            // Reset
            frameLine_r <= 0;
        end
        else begin
            if (pixelClockPhase == 3'b0) begin
                if (isFieldOdd) begin
                    frameLine_r <= (fieldLine * 2);
                end
                else begin
                    frameLine_r <= (fieldLine * 2) + 1;
                end
            end
        end
    end

endmodule

module pi_fieldTracker (
    input pixelClockX6,
    input [2:0] pixelClockPhase,
    input nReset,
    input vSync,
    input hSync,
    
    output isFieldOdd
);

    // Note:
    //
    // The Pi DPI is interlaced which means we get two fields per frame
    // and therefore two vSync pulses per frame.  This logic detects
    // if the vSync is for the odd or even field and outputs a flag
    // following the vSync pulse to indicate which field is being displayed.
    //
    // Odd fields are rendered first, even fields are rendered second

    reg isFieldOdd_r;
    assign isFieldOdd = isFieldOdd_r;

    reg prevVSync_r;

    always @(posedge pixelClockX6, negedge nReset) begin
        if (!nReset) begin
            // Reset
            isFieldOdd_r <= 0;
            prevVSync_r <= 1;
        end
        else begin
            if (pixelClockPhase == 3'b0) begin
                // On the falling edge of the vSync sample the hSync
                // If hSync is high then we are in the odd field and oddFieldSync is held high until the rising edge of the vSync
                // If hSync is low then we are in the even field and evenFieldSync is held high until the rising edge of the vSync

                // Detect the falling edge of the vSync
                if (vSync == 0 && prevVSync_r == 1) begin
                    // Sample the hSync
                    if (hSync == 1) begin
                        // Odd field
                        isFieldOdd_r <= 1;
                    end
                    else begin
                        // Even field
                        isFieldOdd_r <= 0;
                    end
                    prevVSync_r <= 0;
                end

                // Detect the rising edge of the vSync
                if (vSync == 1 && prevVSync_r == 0) begin
                    prevVSync_r <= 1;
                end
            end
        end
    end

endmodule

module pi_linetracker (
    input pixelClockX6,
    input [2:0] pixelClockPhase,
    input nReset,

    input displayEnabled,
    input vSync,

    output [9:0] fieldLine,
    output [9:0] fieldLineDot,
);

    // displayEnabled is true when the pixel clock is in the visible area of a field line
    // So we need to count the pixel clock when displayEnabled is true to track the 720 dots per line
    // Each field has 288 lines which are also counted

    reg [9:0] fieldLine_r; // Current field line (0-287)
    reg [9:0] fieldLineDot_r; // Current field line dot (0-719)

    assign fieldLine = fieldLine_r;
    assign fieldLineDot = fieldLineDot_r;

    always @(posedge pixelClockX6 or negedge nReset) begin
        if (!nReset) begin
            fieldLine_r <= 0;
            fieldLineDot_r <= 0;
        end
        else begin 
            if (pixelClockPhase == 3'b0) begin
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
    end

endmodule