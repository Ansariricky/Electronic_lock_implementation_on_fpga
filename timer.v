`timescale 1ns / 1ps
// =============================================================================
// Module  : timer
// Purpose : Counts down a programmable number of seconds then pulses 'done'.
//
// FIX 1 (RESTART BUG): The original checked 'start && !running' every cycle.
//   Because the FSM holds 'start=1' for the entire timed state, when the
//   timer finished (running->0) the SAME clock edge that advanced the FSM
//   state away still saw start=1 in the timer, causing an immediate silent
//   restart.  Fix: use a RISING EDGE detector on 'start'.  The FSM asserts
//   timer_start=0 in all non-timed states, so whenever a timed state is
//   entered 'start' has a genuine 0->1 transition that triggers exactly one
//   load.
//
// FIX 2 (PARAMETER): CLK_FREQ made a Verilog parameter so the same RTL
//   works with any clock frequency without editing the source.
//   Default = 100_000_000 (100 MHz Nexys/Basys boards).
//   Change at instantiation: timer #(.CLK_FREQ(12_000_000)) t(...);
//
// FIX 3: 'seconds' value is captured into 'sec_target' at the start pulse
//   so the timer is immune to the FSM output changing mid-count.
//
// 'done' is a single-cycle HIGH pulse when the countdown completes.
// =============================================================================

module timer #(
    parameter CLK_FREQ = 100_000_000   // default: 100 MHz
)(
    input            clk,
    input            rst,
    input            start,    // level from FSM; timer starts on rising edge
    input      [3:0] seconds,  // duration in seconds (captured at rising edge)
    output reg       done
);

    reg [31:0] count;
    reg  [3:0] sec;
    reg  [3:0] sec_target;   // seconds captured at load time
    reg        running;
    reg        start_prev;   // for rising-edge detection

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            count      <= 32'd0;
            sec        <= 4'd0;
            sec_target <= 4'd0;
            running    <= 1'b0;
            done       <= 1'b0;
            start_prev <= 1'b0;
        end else begin
            start_prev <= start;
            done       <= 1'b0;   // default: done is LOW

            // -------------------------------------------------------------------
            // FIX: Load on RISING EDGE of start, not on level.
            // This fires exactly once per state entry.
            // -------------------------------------------------------------------
            if (start && !start_prev && !running) begin
                sec_target <= seconds;
                running    <= 1'b1;
                count      <= 32'd0;
                sec        <= 4'd0;
            end

            // -------------------------------------------------------------------
            // Count logic (only when running)
            // -------------------------------------------------------------------
            if (running) begin
                if (count == CLK_FREQ - 1) begin
                    count <= 32'd0;
                    sec   <= sec + 1'b1;
                    // Fires when OLD sec == target-1, i.e. after 'sec_target' seconds
                    if (sec == sec_target - 1) begin
                        done    <= 1'b1;
                        running <= 1'b0;
                    end
                end else begin
                    count <= count + 1'b1;
                end
            end
        end
    end

endmodule
