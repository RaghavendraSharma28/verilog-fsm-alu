////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Filename: controller.v
// Description: Main FSM controller for ECE 3544 Project 5 FSMD.
// Author:   Raghavendra Sharma
// Date:     5/2/26
//
//   State machine sequences:
//     WAIT_OP -> WAIT_A -> (if needs B) WAIT_B -> EXECUTE -> WAIT_OP
//     Multiply: WAIT_OP -> WAIT_A -> WAIT_B -> MUL_LOAD -> MUL_SHOW ->
//               MUL_STEP (x8, one per Enter press) -> MUL_DONE -> WAIT_OP
//
//   "Enter" = single-cycle pulse from keypress module on KEY[0] release.
//   "Reset" = active-low KEY[1].
//
////////////////////////////////////////////////////////////////////////////////////////////////////
module controller(
    input        CLOCK_50,
    input        reset,         // active-low
    input        enter,         // single-cycle pulse from keypress module
    input  [3:0] opcode,        // datapath opcode register (valid 1 cycle after S_LOAD_OP)
    // Datapath control outputs
    output reg   load_op,
    output reg   load_A,
    output reg   load_B,
    output reg   result_load,
    output reg   load_mul_result,
    // Multiplier control outputs
    output reg   mul_load,
    output reg   mul_step,
    // Display control
    output reg   show_product
);
 
    localparam [4:0]
        S_WAIT_OP   = 5'd0,
        S_LOAD_OP   = 5'd1,   // assert load_op; datapath latches SW->opcode this cycle
        S_DECODE    = 5'd2,   // FIX 1: opcode register is now valid; branch here, not in LOAD_OP
        S_WAIT_A    = 5'd3,
        S_LOAD_A    = 5'd4,
        S_EXEC_A    = 5'd5,   // A-only ops: complement, negate
        S_WAIT_B    = 5'd6,
        S_LOAD_B    = 5'd7,
        S_EXECUTE   = 5'd8,
        S_MUL_LOAD  = 5'd9,
        S_MUL_SHOW  = 5'd10,
        S_MUL_WAIT  = 5'd11,
        S_MUL_DO    = 5'd12,  // asserts mul_step for exactly 1 cycle
        S_MUL_DONE  = 5'd13;
 
    reg [4:0] state, next_state;
    reg [3:0] step_count;
 
    // A-only ops (no B needed): complement=0x4, negate=0x7
    function op_needs_only_A;
        input [3:0] op;
        op_needs_only_A = (op == 4'h4) || (op == 4'h7);
    endfunction
 
    // Sequential: state register and step counter
    always @(posedge CLOCK_50 or negedge reset) begin
        if (!reset) begin
            state      <= S_WAIT_OP;
            step_count <= 4'd0;
        end
        else begin
            state <= next_state;
            if (state == S_MUL_LOAD)      step_count <= 4'd0;
            else if (state == S_MUL_DO)   step_count <= step_count + 4'd1;
        end
    end
 
    // Next-state logic — opcode read here is from datapath register (already settled)
    always @(*) begin
        next_state = state;
        case (state)
            S_WAIT_OP:  if (enter)              next_state = S_LOAD_OP;
            S_LOAD_OP:                          next_state = S_DECODE;   // wait 1 cycle
            // FIX 1: branch on opcode HERE — datapath register updated on prev edge
            S_DECODE:
                if      (op_needs_only_A(opcode)) next_state = S_WAIT_A;
                else                              next_state = S_WAIT_A; // always go to WAIT_A
            // (branching on A-only vs B-needed happens after LOAD_A, using settled opcode)
            S_WAIT_A:   if (enter)              next_state = S_LOAD_A;
            S_LOAD_A:
                if (op_needs_only_A(opcode))    next_state = S_EXEC_A;
                else                            next_state = S_WAIT_B;
            S_EXEC_A:                           next_state = S_WAIT_OP;
            S_WAIT_B:   if (enter)              next_state = S_LOAD_B;
            S_LOAD_B:
                if (opcode == 4'hC)             next_state = S_MUL_LOAD;
                else                            next_state = S_EXECUTE;
            S_EXECUTE:                          next_state = S_WAIT_OP;
            S_MUL_LOAD:                         next_state = S_MUL_SHOW;
            S_MUL_SHOW: if (enter)              next_state = S_MUL_DO;
            S_MUL_DO:
                if (step_count == 4'd7)         next_state = S_MUL_DONE;
                else                            next_state = S_MUL_WAIT;
            S_MUL_WAIT: if (enter)              next_state = S_MUL_DO;
            S_MUL_DONE:                         next_state = S_WAIT_OP;
            default:                            next_state = S_WAIT_OP;
        endcase
    end
 
    // Output logic (Moore: outputs depend only on current state)
    always @(*) begin
        load_op         = 1'b0;
        load_A          = 1'b0;
        load_B          = 1'b0;
        result_load     = 1'b0;
        load_mul_result = 1'b0;
        mul_load        = 1'b0;
        mul_step        = 1'b0;
        show_product    = 1'b0;
 
        case (state)
            S_LOAD_OP:  load_op         = 1'b1;
            S_LOAD_A:   load_A          = 1'b1;
            S_EXEC_A:   result_load     = 1'b1;
            S_LOAD_B:   load_B          = 1'b1;
            S_EXECUTE:  result_load     = 1'b1;
            S_MUL_LOAD: mul_load        = 1'b1;
            S_MUL_SHOW: show_product    = 1'b1;
            S_MUL_DO: begin
                        mul_step        = 1'b1;
                        show_product    = 1'b1;
                        end
            S_MUL_WAIT: show_product    = 1'b1;
            S_MUL_DONE: load_mul_result = 1'b1;
            default: ;
        endcase
    end
 
endmodule