////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Filename: multiplier.v
// Description: Sequential (shift-and-add) multiplier, 8x8 -> 16-bit unsigned result.
// Author:   Raghavendra Sharma
// Date:     5/2/26
//
//   Product register is 17 bits (2n+1 for n=8):
//     [16]    = carry/overflow bit
//     [15:8]  = upper half (accumulates partial products)
//     [7:0]   = lower half (holds multiplier bits, shifted out one per step)
//
//   Algorithm per step:
//     1. If product_reg[0] == 1, add multiplicand to product_reg[15:8],
//        storing the 9-bit result into {product_reg[16], product_reg[15:8]}.
//     2. Logical right-shift the full 17-bit register by 1 (MSB filled with 0).
//
//   After 8 steps, product_reg[15:0] holds the 16-bit unsigned result.
//   Verified by simulation against 15x7=105, 12x11=132, 255x255=65025.
//
////////////////////////////////////////////////////////////////////////////////////////////////////
module multiplier(
    input             CLOCK_50,
    input             reset,       // active-low async reset
    input             load,        // load A/B into registers (1-cycle pulse)
    input             shift_step,  // perform one add-and-shift step (1-cycle pulse)
    input      [7:0]  A,           // multiplicand
    input      [7:0]  B,           // multiplier
    output reg [16:0] product_reg  // full 17-bit product register (display shows [15:0])
);
 
    reg [7:0] multiplicand;
 
    // 9-bit addition wire for add step
    wire [8:0] add_result = {1'b0, product_reg[15:8]} + {1'b0, multiplicand};
 
    always @(posedge CLOCK_50 or negedge reset) begin
        if (!reset) begin
            multiplicand <= 8'd0;
            product_reg  <= 17'd0;
        end
        else if (load) begin
            // Upper 9 bits = 0, lower 8 bits = B (the multiplier)
            multiplicand <= A;
            product_reg  <= {9'b0, B};
        end
        else if (shift_step) begin
            if (product_reg[0]) begin
                // Add multiplicand to upper half, then shift right 1
                // {carry, sum[7:0]} stored in [16:8], then >> 1
                product_reg <= {1'b0, add_result[8], add_result[7:0], product_reg[7:1]};
            end
            else begin
                // Just shift right, no add
                product_reg <= {1'b0, product_reg[16:1]};
            end
        end
    end
 
endmodule