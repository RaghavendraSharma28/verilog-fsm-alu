////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Filename: Keypress.v
// Author:   Raghavendra Sharma
// Date:     5/2/26
// Revision: 1
//
// Description: Generates a single-cycle pulse on button release for clean input handling.
// Converts a noisy button press into a one-clock enable signal.
//
////////////////////////////////////////////////////////////////////////////////////////////////////
module keypress(CLOCK_50, reset, key_in, key_out);
    input  CLOCK_50, reset, key_in;
    output key_out;
 
    // ---- Debounce counter ----
    parameter DEBOUNCE_COUNT = 1_000_000;  // 20 ms at 50 MHz
    localparam CTR_BITS = 20;              // ceil(log2(1_000_000)) = 20
 
    reg [CTR_BITS-1:0] db_counter;
    reg                db_stable;         // debounced (stable) key value
 
    always @(posedge CLOCK_50 or negedge reset) begin
        if (!reset) begin
            db_counter <= 0;
            db_stable  <= 1'b1;  // released state
        end
        else begin
            if (key_in == db_stable) begin
                // No change — reset counter
                db_counter <= 0;
            end
            else begin
                // Key signal differs from last stable value
                if (db_counter == DEBOUNCE_COUNT - 1) begin
                    // Stable for long enough — accept the new value
                    db_stable  <= key_in;
                    db_counter <= 0;
                end
                else begin
                    db_counter <= db_counter + 1;
                end
            end
        end
    end
 
    // ---- Pulse-on-release FSM (operates on debounced signal) ----
    // Detects: stable low (pressed) -> stable high (released) -> 1-cycle pulse
    reg [1:0] state, next_state;
    localparam IDLE     = 2'd0,
               PRESSED  = 2'd1,
               RELEASED = 2'd2,
               PULSE    = 2'd3;
 
    always @(posedge CLOCK_50 or negedge reset) begin
        if (!reset) state <= IDLE;
        else        state <= next_state;
    end
 
    always @(*) begin
        case (state)
            IDLE:     next_state = (!db_stable) ? PRESSED  : IDLE;
            PRESSED:  next_state = ( db_stable) ? RELEASED : PRESSED;
            RELEASED: next_state = PULSE;
            PULSE:    next_state = IDLE;
            default:  next_state = IDLE;
        endcase
    end
 
    assign key_out = (state == PULSE);
 
endmodule