`timescale 1ns / 1ps
// =============================================================================
// Module  : password_lock_top
// Purpose : Top-level integration of all sub-modules.
//
// CHANGES IN THIS REVISION
// ------------------------
// CHANGE 1 – Button debounce (replaces manual 2-stage sync block):
//   start_btn, enter_btn, and clear_btn are now debounced using the
//   debounce module (which includes its own 2-stage sync internally).
//   This eliminates both metastability AND mechanical bounce on the
//   push-buttons.  Without debounce a single button press could send
//   multiple 'enter' pulses, causing the FSM to skip states.
//
// Previously applied fixes (unchanged):
//   FIX A – input_enable gating:   key_valid gated by FSM input_enable.
//   FIX B – button synchronizers:  now superseded by debounce instances.
//   FIX C – timer CLK_FREQ:        12 MHz matches XDC period 83.333 ns.
// =============================================================================

module password_lock_top (
    input            clk,
    input            rst,

    input      [3:0] col,          // keypad column inputs (active-low)

    input            start_btn,    // raw push-button inputs (off-chip)
    input            enter_btn,
    input            clear_btn,

    output     [3:0] row,          // keypad row drive (active-low)

    output           green_led,
    output           red_led,
    output           blue_led,

    output           buzzer,
    output           relay
);

    // =========================================================================
    // CHANGE 1: Debounce instances for the three push-buttons
    //   Each instance handles: metastability (2-FF sync) + bounce (counter)
    //   STABLE_CYCLES=50000 @ 12 MHz → 4.17 ms window per button
    // =========================================================================
    wire start_sync;
    wire enter_sync;
    wire clear_sync;

    debounce #(.STABLE_CYCLES(50000)) db_start (
        .clk   (clk),
        .rst   (rst),
        .noisy (start_btn),
        .clean (start_sync)
    );

    debounce #(.STABLE_CYCLES(50000)) db_enter (
        .clk   (clk),
        .rst   (rst),
        .noisy (enter_btn),
        .clean (enter_sync)
    );

    debounce #(.STABLE_CYCLES(50000)) db_clear (
        .clk   (clk),
        .rst   (rst),
        .noisy (clear_btn),
        .clean (clear_sync)
    );

    // =========================================================================
    // Internal wires
    // =========================================================================
    wire [3:0]  key;
    wire        key_valid;

    wire [15:0] input_data;
    wire        input_full;

    wire        timer_done;
    wire        timer_start;
    wire [3:0]  timer_value;

    wire        clear_buffer;
    wire        input_enable;

    // Gate key_valid — only feed the buffer when the FSM is in a digit-entry state
    wire        gated_key_valid = key_valid & input_enable;

    // =========================================================================
    // Sub-module instances
    // =========================================================================

    // Keypad: scan driver + per-bit col debounce + hex encoder
    keypad_scanner ks (
        .clk       (clk),
        .rst       (rst),
        .col       (col),
        .row       (row),
        .key       (key),
        .key_valid (key_valid)
    );

    // Input shift-register buffer (4 nibbles → 16-bit word)
    input_buffer ib (
        .clk       (clk),
        .rst       (rst),
        .clear     (clear_sync | clear_buffer),
        .key       (key),
        .key_valid (gated_key_valid),
        .data_out  (input_data),
        .full      (input_full)
    );

    // Countdown timer — 12 MHz onboard oscillator (XDC period = 83.333 ns)
    timer #(.CLK_FREQ(12_000_000)) t (
        .clk     (clk),
        .rst     (rst),
        .start   (timer_start),
        .seconds (timer_value),
        .done    (timer_done)
    );

    // Main FSM: password check, admin flow, lockout logic
    fsm_controller fsm (
        .clk          (clk),
        .rst          (rst),
        .start_btn    (start_sync),
        .enter        (enter_sync),
        .key          (key),
        .key_valid    (key_valid),
        .input_data   (input_data),
        .input_full   (input_full),
        .timer_done   (timer_done),
        .green_led    (green_led),
        .red_led      (red_led),
        .blue_led     (blue_led),
        .buzzer       (buzzer),
        .relay        (relay),
        .clear_buffer (clear_buffer),
        .input_enable (input_enable),
        .timer_start  (timer_start),
        .timer_value  (timer_value)
    );

endmodule
