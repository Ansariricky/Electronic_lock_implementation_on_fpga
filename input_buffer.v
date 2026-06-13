`timescale 1ns / 1ps
// =============================================================================
// Module  : input_buffer
// Purpose : Shift-register that collects exactly 4 nibbles into a 16-bit word.
//           Sets 'full' after the 4th keypress; 'clear' resets everything.
//
// NOTE: 'key_valid' fed into this module is gated by 'input_enable' from the
//       FSM in password_lock_top.v, so keys are only buffered in the correct
//       states (INPUT, ADMIN_ENTRY, NEW_PASS, CONFIRM_PASS).
//
// No logic changes - module was already functionally correct.
// Added timescale for simulation compatibility.
// =============================================================================

module input_buffer (
    input            clk,
    input            rst,
    input            clear,    // synchronous clear (also combined with rst)
    input      [3:0] key,
    input            key_valid,
    output reg [15:0] data_out,
    output reg        full
);

    reg [1:0] count;

    always @(posedge clk or posedge rst) begin
        if (rst || clear) begin
            data_out <= 16'h0000;
            count    <= 2'd0;
            full     <= 1'b0;
        end else if (key_valid && !full) begin
            data_out <= {data_out[11:0], key};  // shift left, append new nibble
            count    <= count + 1'b1;
            if (count == 2'd3)                  // 4th key completes the buffer
                full <= 1'b1;
        end
    end

endmodule
