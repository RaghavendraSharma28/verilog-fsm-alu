
module project5Top(CLOCK_50, KEY, SW, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, LED);
    input        CLOCK_50;
    input  [3:0] KEY;
    input  [9:0] SW;
    output [6:0] HEX5;
    output [6:0] HEX4;
    output [6:0] HEX3;
    output [6:0] HEX2;
    output [6:0] HEX1;
    output [6:0] HEX0;
    output [9:0] LED;

    //------------------------------------------------------
    // Internal wires
    //------------------------------------------------------
    wire        enter_pulse;     // single-cycle Enter pulse from keypress module
    wire        reset;           // active-low reset = KEY[1]
    assign      reset = KEY[1];

    // Controller outputs
    wire        load_op, load_A, load_B;
    wire        result_load, load_mul_result;
    wire        mul_load, mul_step;
    wire        show_product;

    // Datapath outputs
    wire [3:0]  opcode;
    wire [7:0]  reg_A, reg_B;
    wire [15:0] result_reg;
    wire [15:0] display_val;

    // Multiplier outputs
    wire [16:0] product_reg;

    //------------------------------------------------------
    // Module Instantiations
    //------------------------------------------------------

    // KEY[0] is Enter (active-low), detect release -> single pulse
    keypress u_enter(
        .CLOCK_50 (CLOCK_50),
        .reset    (reset),
        .key_in   (KEY[0]),
        .key_out  (enter_pulse)
    );

    // FSM Controller
    controller u_ctrl(
        .CLOCK_50       (CLOCK_50),
        .reset          (reset),
        .enter          (enter_pulse),
        .opcode         (opcode),
        .load_op        (load_op),
        .load_A         (load_A),
        .load_B         (load_B),
        .result_load    (result_load),
        .load_mul_result(load_mul_result),
        .mul_load       (mul_load),
        .mul_step       (mul_step),
        .show_product   (show_product)
    );

    // Datapath
    datapath u_dp(
        .CLOCK_50       (CLOCK_50),
        .reset          (reset),
        .load_A         (load_A),
        .load_B         (load_B),
        .load_op        (load_op),
        .result_load    (result_load),
        .load_mul_result(load_mul_result),
        .SW             (SW[7:0]),
        .product_reg    (product_reg),
        .show_product   (show_product),
        .opcode         (opcode),
        .reg_A          (reg_A),
        .reg_B          (reg_B),
        .result_reg     (result_reg),
        .display_val    (display_val)
    );

    // Sequential Multiplier
    multiplier u_mul(
        .CLOCK_50   (CLOCK_50),
        .reset      (reset),
        .load       (mul_load),
        .shift_step (mul_step),
        .A          (reg_A),
        .B          (reg_B),
        .product_reg(product_reg)
    );

    //------------------------------------------------------
    // 7-Segment Display Drivers
    //------------------------------------------------------
    // HEX[3:0]: show the 16-bit display value (result or intermediate multiply product)
    seg7 u_hex0(.in(display_val[3:0]),  .out(HEX0));
    seg7 u_hex1(.in(display_val[7:4]),  .out(HEX1));
    seg7 u_hex2(.in(display_val[11:8]), .out(HEX2));
    seg7 u_hex3(.in(display_val[15:12]),.out(HEX3));

    // HEX5/HEX4: debug displays (opcode 0xD = DEBUG operation).
    //   HEX5 shows the upper nibble of reg_A (bits [7:4]).
    //   HEX4 shows the lower nibble of reg_A (bits [3:0]).
    //   Together they display reg_A as a 2-digit hex value while DEBUG is active.
    //   During all other operations both displays are turned off (7'b1111111, active-low).
    // FIX 3: actually wire to seg7 outputs rather than always driving 7'b1111111.
    wire        debug_active = (opcode == 4'hD);
    wire [6:0]  hex5_debug, hex4_debug;
    seg7 u_hex5_d(.in(reg_A[7:4]), .out(hex5_debug));
    seg7 u_hex4_d(.in(reg_A[3:0]), .out(hex4_debug));
    assign HEX5 = debug_active ? hex5_debug : 7'b1111111;
    assign HEX4 = debug_active ? hex4_debug : 7'b1111111;

    // LEDs: per spec, unused outputs must be off.
    //   During DEBUG op: LED[7:0] shows reg_B so you can verify both operands.
    //   LED[9:8] are always off.
    assign LED[9:8] = 2'b00;
    assign LED[7:0] = debug_active ? reg_B : 8'h00;

endmodule