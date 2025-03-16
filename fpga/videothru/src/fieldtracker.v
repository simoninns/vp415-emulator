/************************************************************************
	
	fieldTracker.v
	Raspberry Pi DPI interlaced field sync generator
	
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

module fieldTracker (
    input pixelClockX6,
    input pixelClockX1_en,
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
            if (pixelClockX1_en) begin
                // On the falling edge of the vSync sample the hSync
                // If hSync is high then we are in the even field and evenFieldSync is held high until the rising edge of the vSync
                // If hSync is low then we are in the odd field and oddFieldSync is held high until the rising edge of the vSync

                // Detect the falling edge of the vSync
                if (vSync == 0 && prevVSync_r == 1) begin
                    // Sample the hSync
                    if (hSync == 1) begin
                        // Even field
                        isFieldOdd_r <= 0;
                    end
                    else begin
                        // Odd field
                        isFieldOdd_r <= 1;
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