`timescale 1ns / 1ps
// =============================================================================
// Module  : synchronizer
// Purpose : Two-stage flip-flop synchronizer for the 4 keypad column lines.
//           Prevents metastability from asynchronous column inputs.
// No logic changes - module was already correct.
// =============================================================================

module synchronizer (
    input            clk,
    input            rst,
    input      [3:0] col,
    output reg [3:0] col_sync
);

    reg [3:0] sync1;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync1    <= 4'b1111;
            col_sync <= 4'b1111;
        end else begin
            sync1    <= col;
            col_sync <= sync1;
        end
    end

endmodule
