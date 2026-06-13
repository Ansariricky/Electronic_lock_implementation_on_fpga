`timescale 1ns / 1ps
// =============================================================================
// Module  : hex_keypad_encoder
// Purpose : Decodes active-low row/col scan signals into a 4-bit hex key code.
//           Generates a single-cycle 'valid' pulse on each NEW keypress.
//
// FIX (was empty stub): Implemented from scratch.
//
// Keypad layout (active-low rows and columns):
//   Row\Col  COL3  COL2  COL1  COL0
//   ROW0      A     3     2     1
//   ROW1      B     6     5     4
//   ROW2      C     9     8     7
//   ROW3      D     #(F)  0    *(E)
//
// '#' encodes to 4'hF  -> used as admin-mode trigger in FSM.
// '*' encodes to 4'hE
// =============================================================================

module hex_keypad_encoder (
    input            clk,
    input            rst,
    input      [3:0] row,      // from row_signal (active-low, one bit low = active)
    input      [3:0] col,      // from synchronizer (active-low, one bit low = pressed)
    output reg [3:0] key,      // decoded key value 0-F
    output reg       valid     // one-cycle HIGH pulse on new keypress
);

    reg [3:0] col_prev;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            col_prev <= 4'b1111;
            key      <= 4'h0;
            valid    <= 1'b0;
        end else begin
            col_prev <= col;
            valid    <= 1'b0;  // default: no pulse

            // Rising edge of keypress: col just went from idle (all-high) to active
            // This guarantees exactly ONE valid pulse per physical keypress.
            if (col != 4'b1111 && col_prev == 4'b1111) begin
                case ({row, col})
                    // --- Row 0 active (row = 4'b1110) ---
                    8'b1110_1110: begin key <= 4'h1; valid <= 1'b1; end  // 1
                    8'b1110_1101: begin key <= 4'h2; valid <= 1'b1; end  // 2
                    8'b1110_1011: begin key <= 4'h3; valid <= 1'b1; end  // 3
                    8'b1110_0111: begin key <= 4'hA; valid <= 1'b1; end  // A
                    // --- Row 1 active (row = 4'b1101) ---
                    8'b1101_1110: begin key <= 4'h4; valid <= 1'b1; end  // 4
                    8'b1101_1101: begin key <= 4'h5; valid <= 1'b1; end  // 5
                    8'b1101_1011: begin key <= 4'h6; valid <= 1'b1; end  // 6
                    8'b1101_0111: begin key <= 4'hB; valid <= 1'b1; end  // B
                    // --- Row 2 active (row = 4'b1011) ---
                    8'b1011_1110: begin key <= 4'h7; valid <= 1'b1; end  // 7
                    8'b1011_1101: begin key <= 4'h8; valid <= 1'b1; end  // 8
                    8'b1011_1011: begin key <= 4'h9; valid <= 1'b1; end  // 9
                    8'b1011_0111: begin key <= 4'hC; valid <= 1'b1; end  // C
                    // --- Row 3 active (row = 4'b0111) ---
                    8'b0111_1110: begin key <= 4'hE; valid <= 1'b1; end  // * -> 0xE
                    8'b0111_1101: begin key <= 4'h0; valid <= 1'b1; end  // 0
                    8'b0111_1011: begin key <= 4'hF; valid <= 1'b1; end  // # -> 0xF (admin key)
                    8'b0111_0111: begin key <= 4'hD; valid <= 1'b1; end  // D
                    default:      begin key <= 4'h0; valid <= 1'b0; end
                endcase
            end
        end
    end

endmodule
