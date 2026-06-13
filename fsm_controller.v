`timescale 1ns / 1ps
// =============================================================================
// Module  : fsm_controller
// Purpose : Main state machine for the 4-digit hex password lock system.
//
// FIXES APPLIED
// -------------
// FIX 1 – COMBINED input_full&&enter (ADMIN_ENTRY, NEW_PASS, CONFIRM_PASS):
//   The original waited for 'input_full && enter' in the same clock cycle,
//   which is functionally impossible (full becomes true after the 4th key;
//   enter is a separate button press).  Each of these states has been split
//   into two phases:
//     ADMIN_ENTRY  -> ADMIN_WAIT  (wait full, then wait enter)
//     NEW_PASS     -> NEW_WAIT    (wait full, then wait enter + capture)
//     CONFIRM_PASS -> CONFIRM_WAIT (wait full, then wait enter + compare)
//
// FIX 2 – input_enable (uncontrolled buffering):
//   Without a gate, the '#' key pressed in LOCKED_IDLE to enter admin mode
//   was also being loaded into the input_buffer.  A new 'input_enable' output
//   is asserted ONLY in the four states that deliberately collect digits
//   (INPUT, ADMIN_ENTRY, NEW_PASS, CONFIRM_PASS).  The top module gates
//   key_valid through this signal before passing it to input_buffer.
//
// FIX 3 – clear_buffer coverage:
//   Added clear_buffer = 1 in LOCKED_IDLE (ensures clean slate on every
//   idle cycle), GRANTED, DENIED, ADMIN_VERIFY (clears admin password
//   whether verified or not), and CONFIRM_FAIL (new state for mismatch path).
//
// FIX 4 – CONFIRM_FAIL state:
//   When the confirm password doesn't match, the FSM now passes through a
//   dedicated CONFIRM_FAIL state (clear_buffer=1, red LED) before returning
//   to NEW_PASS.  This prevents clear_buffer from being asserted while
//   input_data is still needed for comparison in CONFIRM_WAIT.
//
// Password default : 16'h1234  (change at synthesis time via parameter or
//                               use the admin-change flow at run time)
// Admin password   : 16'hAAAA  (press 'A' four times; change ADMIN_PASS below)
// =============================================================================

module fsm_controller (
    input            clk,
    input            rst,

    // User controls (already synchronized in top module)
    input            start_btn,
    input            enter,

    // From keypad scanner
    input      [3:0] key,
    input            key_valid,

    // From input buffer
    input      [15:0] input_data,
    input             input_full,

    // From timer
    input             timer_done,

    // LED / actuator outputs
    output reg        green_led,
    output reg        red_led,
    output reg        blue_led,
    output reg        buzzer,
    output reg        relay,

    // Control outputs
    output reg        clear_buffer,   // synchronous clear for input_buffer
    output reg        input_enable,   // gate: allow key_valid to reach buffer
    output reg        timer_start,
    output reg [3:0]  timer_value
);

    // =========================================================================
    // State encoding  (5-bit, supports up to 32 states)
    // =========================================================================
    reg [4:0] state;

    localparam
        LOCKED_IDLE    = 5'd0,
        IDLE           = 5'd1,
        INPUT          = 5'd2,
        WAIT_ENTER     = 5'd3,
        CHECK          = 5'd4,
        GRANTED        = 5'd5,
        DENIED         = 5'd6,
        LOCKOUT        = 5'd7,
        ADMIN_ENTRY    = 5'd8,
        ADMIN_WAIT     = 5'd9,   // FIX 1: new – wait for enter after buffer full
        ADMIN_VERIFY   = 5'd10,
        ADMIN_SUCCESS  = 5'd11,
        NEW_PASS       = 5'd12,
        NEW_WAIT       = 5'd13,  // FIX 1: new – wait for enter after buffer full
        NEW_PASS_OK    = 5'd14,
        CONFIRM_PASS   = 5'd15,
        CONFIRM_WAIT   = 5'd16,  // FIX 1: new – wait for enter after buffer full
        CONFIRM_OK     = 5'd17,
        UPDATE_PASS    = 5'd18,
        CONFIRM_FAIL   = 5'd19;  // FIX 4: new – clear buffer before retry

    // =========================================================================
    // Internal registers
    // =========================================================================
    reg [1:0]  attempts;
    reg [15:0] stored_password;
    reg [15:0] temp_password;

    // Admin password (hardcoded, not user-changeable via this flow)
    localparam [15:0] ADMIN_PASS = 16'hAAAA;

    // =========================================================================
    // Sequential: state transitions + data registers
    // =========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state            <= LOCKED_IDLE;
            attempts         <= 2'd0;
            stored_password  <= 16'h1234;
            temp_password    <= 16'h0000;
        end else begin
            case (state)

                // -----------------------------------------------------------------
                LOCKED_IDLE: begin
                    if (start_btn)
                        state <= IDLE;
                    else if (key_valid && key == 4'hF)
                        state <= ADMIN_ENTRY;
                    // else: stay (clear_buffer keeps buffer clean)
                end

                // -----------------------------------------------------------------
                IDLE: begin
                    state <= INPUT;           // one-cycle pass-through
                end

                // -----------------------------------------------------------------
                INPUT: begin
                    if (input_full)
                        state <= WAIT_ENTER;
                end

                // -----------------------------------------------------------------
                WAIT_ENTER: begin
                    if (enter)
                        state <= CHECK;
                end

                // -----------------------------------------------------------------
                CHECK: begin
                    if (input_data == stored_password)
                        state <= GRANTED;
                    else
                        state <= DENIED;
                end

                // -----------------------------------------------------------------
                GRANTED: begin
                    attempts <= 2'd0;
                    state    <= LOCKED_IDLE;
                end

                // -----------------------------------------------------------------
                DENIED: begin
                    attempts <= attempts + 1'b1;
                    // Check OLD value: fire LOCKOUT on 3rd failure (attempts==2)
                    if (attempts == 2'd2)
                        state <= LOCKOUT;
                    else
                        state <= LOCKED_IDLE;
                end

                // -----------------------------------------------------------------
                LOCKOUT: begin
                    attempts <= 2'd0;
                    if (timer_done)
                        state <= LOCKED_IDLE;
                end

                // -----------------------------------------------------------------
                // Admin flow
                // -----------------------------------------------------------------
                ADMIN_ENTRY: begin
                    if (input_full)
                        state <= ADMIN_WAIT;  // FIX 1
                end

                ADMIN_WAIT: begin             // FIX 1
                    if (enter)
                        state <= ADMIN_VERIFY;
                end

                ADMIN_VERIFY: begin
                    if (input_data == ADMIN_PASS)
                        state <= ADMIN_SUCCESS;
                    else
                        state <= LOCKED_IDLE;
                end

                ADMIN_SUCCESS: begin
                    if (timer_done)
                        state <= NEW_PASS;
                end

                // -----------------------------------------------------------------
                // Password change flow
                // -----------------------------------------------------------------
                NEW_PASS: begin
                    if (input_full)
                        state <= NEW_WAIT;    // FIX 1
                end

                NEW_WAIT: begin               // FIX 1
                    if (enter) begin
                        temp_password <= input_data;   // capture new password
                        state         <= NEW_PASS_OK;
                    end
                end

                NEW_PASS_OK: begin
                    if (timer_done)
                        state <= CONFIRM_PASS;
                end

                CONFIRM_PASS: begin
                    if (input_full)
                        state <= CONFIRM_WAIT;  // FIX 1
                end

                CONFIRM_WAIT: begin             // FIX 1
                    if (enter) begin
                        if (input_data == temp_password)
                            state <= CONFIRM_OK;
                        else
                            state <= CONFIRM_FAIL;  // FIX 4: buffer cleared here
                    end
                end

                CONFIRM_OK: begin
                    if (timer_done)
                        state <= UPDATE_PASS;
                end

                UPDATE_PASS: begin
                    stored_password <= temp_password;
                    state           <= LOCKED_IDLE;
                end

                CONFIRM_FAIL: begin             // FIX 4
                    state <= NEW_PASS;          // retry; clear_buffer fires here
                end

                // -----------------------------------------------------------------
                default: state <= LOCKED_IDLE;

            endcase
        end
    end

    // =========================================================================
    // Combinatorial: output logic
    // =========================================================================
    always @(*) begin
        // Defaults
        green_led    = 1'b0;
        red_led      = 1'b0;
        blue_led     = 1'b0;
        buzzer       = 1'b0;
        relay        = 1'b0;
        clear_buffer = 1'b0;
        input_enable = 1'b0;
        timer_start  = 1'b0;
        timer_value  = 4'd0;

        case (state)

            LOCKED_IDLE: begin
                red_led      = 1'b1;
                clear_buffer = 1'b1;   // FIX 3: keep buffer clean while idle
            end

            IDLE: begin
                blue_led = 1'b1;
            end

            INPUT: begin
                blue_led     = 1'b1;
                input_enable = 1'b1;   // FIX 2: enable buffering
            end

            WAIT_ENTER: begin
                blue_led = 1'b1;
            end

            CHECK: begin
                // Transient, no LED change needed
            end

            GRANTED: begin
                green_led    = 1'b1;
                relay        = 1'b1;
                clear_buffer = 1'b1;   // FIX 3
            end

            DENIED: begin
                red_led      = 1'b1;
                buzzer       = 1'b1;
                clear_buffer = 1'b1;   // FIX 3
            end

            LOCKOUT: begin
                red_led     = 1'b1;
                buzzer      = 1'b1;
                timer_start = 1'b1;
                timer_value = 4'd10;
            end

            ADMIN_ENTRY: begin
                blue_led     = 1'b1;
                input_enable = 1'b1;   // FIX 2: enable buffering for admin pass
            end

            ADMIN_WAIT: begin
                blue_led = 1'b1;
            end

            ADMIN_VERIFY: begin
                // Transient check; clear buffer regardless of outcome
                clear_buffer = 1'b1;   // FIX 3
            end

            ADMIN_SUCCESS: begin
                green_led    = 1'b1;
                timer_start  = 1'b1;
                timer_value  = 4'd3;
                clear_buffer = 1'b1;   // clear admin pass before new pass entry
            end

            NEW_PASS: begin
                blue_led     = 1'b1;
                input_enable = 1'b1;   // FIX 2: enable buffering for new pass
            end

            NEW_WAIT: begin
                blue_led = 1'b1;
            end

            NEW_PASS_OK: begin
                green_led    = 1'b1;
                timer_start  = 1'b1;
                timer_value  = 4'd2;
                clear_buffer = 1'b1;
            end

            CONFIRM_PASS: begin
                blue_led     = 1'b1;
                input_enable = 1'b1;   // FIX 2: enable buffering for confirm pass
            end

            CONFIRM_WAIT: begin
                blue_led = 1'b1;
                // NOTE: clear_buffer NOT asserted here so input_data
                // is still valid for comparison in this state. FIX 4
            end

            CONFIRM_OK: begin
                green_led    = 1'b1;
                timer_start  = 1'b1;
                timer_value  = 4'd2;
                clear_buffer = 1'b1;
            end

            UPDATE_PASS: begin
                green_led = 1'b1;
            end

            CONFIRM_FAIL: begin           // FIX 4
                red_led      = 1'b1;
                buzzer       = 1'b1;
                clear_buffer = 1'b1;      // safe to clear now (comparison is done)
            end

        endcase
    end

endmodule
