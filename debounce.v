`timescale 1ns / 1ps
// =============================================================================
// Module  : debounce
// Purpose : Removes mechanical contact bounce from a single digital input.
//           Safe to connect raw off-chip signals directly — includes an
//           internal 2-stage flip-flop synchronizer so both metastability
//           AND bounce are handled in one module.
//
// Operation:
//   The input is first captured by 2 pipeline FFs (sync1, sync2) to resolve
//   metastability.  The debounce logic then watches sync2:
//     - If sync2 differs from the accepted 'state', increment a counter.
//     - If the signal holds stable for STABLE_CYCLES consecutive clocks,
//       accept the new level → update 'state' and drive 'clean'.
//     - If the signal returns to 'state' before the counter expires,
//       reset the counter (bounce detected, ignore the glitch).
//
// FIXES vs. the original image module
// ------------------------------------
// FIX 1: Added internal 2-stage synchronizer (sync1/sync2).
//        Original used 'noisy' directly in combinational comparison,
//        which can propagate metastable voltages into counter logic.
//
// FIX 2: Made STABLE_CYCLES a parameter (default 50000).
//        At 12 MHz → 50000 / 12 000 000 = 4.17 ms debounce window.
//        At 100 MHz pass STABLE_CYCLES=1_000_000 for the same 10 ms window.
//
// FIX 3: Counter now counts up to STABLE_CYCLES-1 and checks on that value,
//        giving exactly STABLE_CYCLES stable cycles before accepting.
//        Original checked == 50000 AFTER incrementing so the effective
//        window was 50001 cycles — minor but corrected for clarity.
//
// FIX 4: Added `timescale for simulation compatibility.
// =============================================================================

module debounce #(
    parameter STABLE_CYCLES = 50000   // cycles the input must hold stable
                                      // 50000 @ 12 MHz  = 4.17 ms
                                      // 50000 @ 100 MHz = 0.5  ms (increase if needed)
)(
    input  clk,
    input  rst,
    input  noisy,   // raw, possibly bouncing / metastable input
    output reg clean  // debounced, synchronised output
);

    // -------------------------------------------------------------------------
    // FIX 1: 2-stage synchronizer — resolve metastability first
    // -------------------------------------------------------------------------
    reg sync1, sync2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            sync1 <= 1'b0;
            sync2 <= 1'b0;
        end else begin
            sync1 <= noisy;
            sync2 <= sync1;
        end
    end

    // -------------------------------------------------------------------------
    // Debounce counter — operates on the synchronised signal (sync2)
    // -------------------------------------------------------------------------
    // Counter wide enough to hold STABLE_CYCLES.
    // 16 bits covers up to 65535; use 20 bits for up to ~1M cycles.
    reg [19:0] count;
    reg        state;   // last accepted (stable) level

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count <= 20'd0;
            state <= 1'b0;
            clean <= 1'b0;
        end else begin
            if (sync2 != state) begin
                // Signal is different from accepted state — count stable time
                if (count == STABLE_CYCLES - 1) begin
                    // FIX 3: held stable for exactly STABLE_CYCLES clocks → accept
                    state <= sync2;
                    clean <= sync2;
                    count <= 20'd0;
                end else begin
                    count <= count + 1'b1;
                end
            end else begin
                // Signal matches accepted state — reset counter (bounce/glitch)
                count <= 20'd0;
            end
        end
    end

endmodule
