`timescale 1ns / 1ps
// =============================================================================
// Module  : keypad_scanner
// Purpose : Top-level keypad subsystem: scan driver + debounce + encoder.
//
// Signal chain for column inputs:
//   raw col[i] → debounce (includes 2-FF sync + counter) → hex_keypad_encoder
//
// CHANGE: Replaced the standalone synchronizer module with 4 per-bit debounce
//   instances (one per column line).  The debounce module already contains a
//   2-stage synchronizer internally, so metastability protection is preserved
//   AND mechanical bounce on the keypad column lines is now eliminated.
//   Without debounce, a bouncing column line could produce multiple
//   key_valid pulses for a single physical keypress and fill the
//   input_buffer with repeated digits.
//
// synchronizer.v is no longer instantiated here (kept in project as spare).
// =============================================================================

module keypad_scanner (
    input            clk,
    input            rst,
    input      [3:0] col,       // raw column signals from keypad (active-low)
    output     [3:0] row,       // row scan drive signals (active-low)
    output     [3:0] key,       // decoded hex key (0x0-0xF)
    output           key_valid  // single-cycle pulse when new key is detected
);

    wire [3:0] col_clean;   // debounced column signals

    // -------------------------------------------------------------------------
    // Row scan driver
    // -------------------------------------------------------------------------
    row_signal rs (
        .clk (clk),
        .rst (rst),
        .row (row)
    );

    // -------------------------------------------------------------------------
    // Per-bit column debounce  (replaces synchronizer.v)
    // Each instance: 2-FF sync + 4.17 ms stable window @ 12 MHz
    // -------------------------------------------------------------------------
    debounce #(.STABLE_CYCLES(50000)) db_col0 (
        .clk   (clk),
        .rst   (rst),
        .noisy (col[0]),
        .clean (col_clean[0])
    );

    debounce #(.STABLE_CYCLES(50000)) db_col1 (
        .clk   (clk),
        .rst   (rst),
        .noisy (col[1]),
        .clean (col_clean[1])
    );

    debounce #(.STABLE_CYCLES(50000)) db_col2 (
        .clk   (clk),
        .rst   (rst),
        .noisy (col[2]),
        .clean (col_clean[2])
    );

    debounce #(.STABLE_CYCLES(50000)) db_col3 (
        .clk   (clk),
        .rst   (rst),
        .noisy (col[3]),
        .clean (col_clean[3])
    );

    // -------------------------------------------------------------------------
    // Hex encoder  (receives clean, bounce-free column signals)
    // -------------------------------------------------------------------------
    hex_keypad_encoder enc (
        .clk   (clk),
        .rst   (rst),
        .row   (row),
        .col   (col_clean),
        .key   (key),
        .valid (key_valid)
    );

endmodule
