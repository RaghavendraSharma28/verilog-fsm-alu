////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Filename: datapath.v
// Description: Datapath for ECE 3544 Project 5.
// Author:   Raghavendra Sharma
// Date:     5/2/26
//
//   Implements all 14 operations. Operand registers A and B are loaded by the FSM.
//   The result register latches the computed value when result_load is asserted.
//   The multiply result is fed in from the multiplier module.
//
//   Student ID last 4 digits: 1143 -> BCD = 16'h1143
//
////////////////////////////////////////////////////////////////////////////////////////////////////
module datapath(
    input             CLOCK_50,
    input             reset,         // active-low
    // Register load controls from FSM
    input             load_A,        // load SW[7:0] into reg_A
    input             load_B,        // load SW[7:0] into reg_B (or SW[3:0] for 4-bit ops)
    input             load_op,       // load SW[3:0] into opcode register
    input             result_load,   // latch computed result into result register
    input             load_mul_result, // latch multiply product into result register
    // Switch input
    input      [7:0]  SW,
    // Multiply interface
    input      [16:0] product_reg,   // from multiplier module (shown during multiply steps)
    input             show_product,  // show product_reg[15:0] on display instead of result_reg
    // Outputs
    output reg [3:0]  opcode,
    output reg [7:0]  reg_A,
    output reg [7:0]  reg_B,
    output reg [15:0] result_reg,    // registered result (displayed between operations)
    output     [15:0] display_val    // what to show on HEX displays right now
);
 
    // Student ID last 4 digits in BCD
    localparam [15:0] STUDENT_ID = 16'h1143;
 
    // Operation codes
    localparam OP_OR_ID  = 4'h0,
               OP_NAND   = 4'h1,
               OP_NOR    = 4'h2,
               OP_XOR    = 4'h3,
               OP_COMP   = 4'h4,
               OP_ADD    = 4'h5,
               OP_SUB    = 4'h6,
               OP_NEG    = 4'h7,
               OP_ASL    = 4'h8,
               OP_ASR    = 4'h9,
               OP_CSL    = 4'hA,
               OP_CSR    = 4'hB,
               OP_MUL    = 4'hC,
               OP_DEBUG  = 4'hD;   // any unused code; using D
 
    // Sign-extended A and B for arithmetic operations (no 'signed' attribute per spec)
    wire [15:0] A_sext = {{8{reg_A[7]}}, reg_A};
    wire [15:0] B_sext = {{8{reg_B[7]}}, reg_B};
 
    // Shift amount from B[3:0] (4-bit unsigned, max 15)
    wire [3:0] shamt = reg_B[3:0];
 
    // --- ASR: manual sign-fill, no $signed or >>> operator ---
    // Logical right-shift, then OR in sign-bit replicated into vacated MSBs.
    // sign_fill[15:0]: if A_sext[15]==1, upper 'shamt' bits become 1, else 0.
    // Built as a 16-bit mask: ((1<<shamt)-1) << (16-shamt), but done combinationally.
    wire        asr_sign = A_sext[15];
    wire [15:0] asr_shifted = A_sext >> shamt;            // logical shift (zeros fill)
    // Generate sign-fill mask: shamt ones starting at bit (15) down to (16-shamt)
    // Use a priority mux over all possible shamt values (0-15) — fully combinational.
    reg  [15:0] asr_sign_mask;
    always @(*) begin
        case (shamt)
            4'd0:  asr_sign_mask = 16'b0000_0000_0000_0000;
            4'd1:  asr_sign_mask = 16'b1000_0000_0000_0000;
            4'd2:  asr_sign_mask = 16'b1100_0000_0000_0000;
            4'd3:  asr_sign_mask = 16'b1110_0000_0000_0000;
            4'd4:  asr_sign_mask = 16'b1111_0000_0000_0000;
            4'd5:  asr_sign_mask = 16'b1111_1000_0000_0000;
            4'd6:  asr_sign_mask = 16'b1111_1100_0000_0000;
            4'd7:  asr_sign_mask = 16'b1111_1110_0000_0000;
            4'd8:  asr_sign_mask = 16'b1111_1111_0000_0000;
            4'd9:  asr_sign_mask = 16'b1111_1111_1000_0000;
            4'd10: asr_sign_mask = 16'b1111_1111_1100_0000;
            4'd11: asr_sign_mask = 16'b1111_1111_1110_0000;
            4'd12: asr_sign_mask = 16'b1111_1111_1111_0000;
            4'd13: asr_sign_mask = 16'b1111_1111_1111_1000;
            4'd14: asr_sign_mask = 16'b1111_1111_1111_1100;
            4'd15: asr_sign_mask = 16'b1111_1111_1111_1110;
        endcase
    end
    wire [15:0] asr_result = asr_shifted | (asr_sign ? asr_sign_mask : 16'h0000);
 
    // --- Circular shifts on 16-bit zero-filled A ---
    // FIX 2: When shamt==0, (16-shamt)==16 which shifts a 16-bit value by its full width.
    // Verilog gives 0 for that, so the OR would incorrectly add A_zext back in.
    // Guard: when shamt==0, result is just A_zext unchanged (no rotation needed).
    wire [15:0] A_zext = {8'h00, reg_A};
    wire [15:0] csl_result = (shamt == 4'd0) ? A_zext :
                             (A_zext << shamt) | (A_zext >> (16 - shamt));
    wire [15:0] csr_result = (shamt == 4'd0) ? A_zext :
                             (A_zext >> shamt) | (A_zext << (16 - shamt));
 
    // Combinational result mux (computed every cycle; latched by FSM on result_load)
    reg [15:0] computed;
 
    always @(*) begin
        case (opcode)
            // FIX #2: {A,B} = {reg_A, reg_B} (16-bit concat), OR'd with student ID
            OP_OR_ID: computed = {reg_A, reg_B} | STUDENT_ID;
 
            // Bitwise ops: 8-bit result, zero-extended to 16 bits [note B]
            OP_NAND:  computed = {8'h00, ~(reg_A & reg_B)};
            OP_NOR:   computed = {8'h00, ~(reg_A | reg_B)};
            OP_XOR:   computed = {8'h00,  (reg_A ^ reg_B)};
            OP_COMP:  computed = {8'h00, ~reg_A};
 
            // Arithmetic ops: sign-extended 8-bit operands, 16-bit result [note A]
            OP_ADD:   computed = A_sext + B_sext;
            OP_SUB:   computed = A_sext - B_sext;
            OP_NEG:   computed = (~A_sext) + 16'd1;  // 2's complement without unary minus
 
            // Shift ops [note AS]: A sign-extended, shift by B[3:0] positions
            OP_ASL:   computed = A_sext << shamt;    // vacated LSBs are 0 (correct for ASL)
            OP_ASR:   computed = asr_result;          // FIX #3: manual sign-fill, no $signed
 
            // Circular shifts [note CS]: A zero-filled to 16 bits, rotated
            OP_CSL:   computed = csl_result;
            OP_CSR:   computed = csr_result;
 
            // Multiply: result comes directly from multiplier product_reg, latched separately
            OP_MUL:   computed = product_reg[15:0];
 
            // Debug: display {A, B} side by side on HEX3-HEX2 and HEX1-HEX0
            OP_DEBUG: computed = {reg_A, reg_B};
 
            default:  computed = 16'h0000;
        endcase
    end
 
    // Register loads
    always @(posedge CLOCK_50 or negedge reset) begin
        if (!reset) begin
            opcode     <= 4'h0;
            reg_A      <= 8'h00;
            reg_B      <= 8'h00;
            result_reg <= 16'h0000;
        end
        else begin
            if (load_op) opcode <= SW[3:0];
            if (load_A)  reg_A  <= SW[7:0];
            if (load_B)  reg_B  <= SW[7:0];
            if (result_load)     result_reg <= computed;
            if (load_mul_result) result_reg <= product_reg[15:0];
        end
    end
 
    // Display mux: during multiply steps show current product_reg; otherwise show result_reg
    assign display_val = show_product ? product_reg[15:0] : result_reg;
 
endmodule