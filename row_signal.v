`timescale 1ns / 1ps
// =============================================================================
// Module  : row_signal
// Purpose : Drives the 4 keypad row lines with a rotating active-low scan.
//
// FIX: Original code updated 'row' using the OLD value of 'scan' inside the
//      same non-blocking block, so 'row' lagged 'scan' by one period and
//      row-0 was driven for twice as long after reset.
//      Fix: 'scan' is updated in the sequential block; 'row' is derived
//      combinatorially from 'scan' in a separate always @(*) block so they
//      are always in sync.
//
// Scan period: CLK_FREQ / 50000 per row.
//   At 100 MHz -> 0.5 ms/row -> 2 ms full scan  (comfortable for any keypad)
//   At  12 MHz -> ~4.2 ms/row
// =============================================================================

module row_signal (
    input            clk,
    input            rst,
    output reg [3:0] row    // active-low: one bit LOW = that row is being driven
);

    reg  [1:0]  scan;
    reg  [15:0] div;

    // -------------------------------------------------------------------------
    // Sequential: advance scan counter every 50 000 clock cycles
    // -------------------------------------------------------------------------
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            scan <= 2'd0;
            div  <= 16'd0;
        end else begin
            if (div == 16'd49999) begin
                div  <= 16'd0;
                scan <= scan + 1'b1;   // wraps 3->0 automatically (2-bit)
            end else begin
                div <= div + 1'b1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Combinatorial: row is directly decoded from scan (no lag)
    // -------------------------------------------------------------------------
    always @(*) begin
        case (scan)
            2'd0:    row = 4'b1110;
            2'd1:    row = 4'b1101;
            2'd2:    row = 4'b1011;
            2'd3:    row = 4'b0111;
            default: row = 4'b1110;
        endcase
    end

endmodule
