////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Filename: project5Top_tb.v
// Description: Testbench for ECE 3544 Project 5 top-level module.
//
//   Uses hierarchical access (dut.u_dp.result_reg, dut.u_dp.display_val) to read
//   internal signals and perform actual pass/fail checks after every operation.
//
//   Operations tested (all 14 + edge cases):
//     0x0  OR_ID:  A=F0, B=96  -> F1D7
//     0x1  NAND:   A=FF, B=0F  -> 00F0
//     0x2  NOR:    A=AA, B=55  -> 0000
//     0x3  XOR:    A=FF, B=0F  -> 00F0
//     0x4  COMP:   A=A5        -> 005A
//     0x5  ADD:    A=0A, B=05  -> 000F
//     0x5  ADD:    A=FF, B=01  -> 0000  (signed edge: -1+1=0)
//     0x6  SUB:    A=0A, B=05  -> 0005
//     0x6  SUB:    A=80, B=01  -> FF7F  (signed edge: -128-1=-129)
//     0x7  NEG:    A=01        -> FFFF
//     0x8  ASL:    A=01, B=03  -> 0008
//     0x9  ASR:    A=F0, B=04  -> FFFF  (signed: -16>>4=-1)
//     0x9  ASR:    A=40, B=02  -> 0010  (positive)
//     0xA  CSL:    A=80, B=01  -> 0100
//     0xA  CSL:    A=80, B=00  -> 0080  (edge: shamt=0)
//     0xB  CSR:    A=01, B=01  -> 8000
//     0xB  CSR:    A=01, B=00  -> 0001  (edge: shamt=0)
//     0xC  MUL:    A=0F, B=07  -> initial=0007, final=0069
//     0xD  DEBUG:  A=AB, B=CD  -> ABCD (result_reg), LED=CD
//
////////////////////////////////////////////////////////////////////////////////////////////////////
`timescale 1ns/1ps
module project5Top_tb;

    reg        CLOCK_50;
    reg  [3:0] KEY;
    reg  [9:0] SW;
    wire [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0;
    wire [9:0] LED;

    // DUT
    project5Top dut(
        .CLOCK_50(CLOCK_50),
        .KEY(KEY),
        .SW(SW),
        .HEX5(HEX5), .HEX4(HEX4),
        .HEX3(HEX3), .HEX2(HEX2),
        .HEX1(HEX1), .HEX0(HEX0),
        .LED(LED)
    );

    // Override debounce counter to 5 cycles so simulation runs in reasonable time
    defparam dut.u_enter.DEBOUNCE_COUNT = 5;

    // 50 MHz clock
    initial CLOCK_50 = 0;
    always #10 CLOCK_50 = ~CLOCK_50;

    // Pass/fail counters
    integer pass_count, fail_count;

    //------------------------------------------------------------------
    // Task: simulate debounced press-and-release of KEY[0]
    // With DEBOUNCE_COUNT=5, need >=5 stable cycles in each state.
    //------------------------------------------------------------------
    task press_enter;
        begin
            @(posedge CLOCK_50); #1;
            KEY[0] = 0;                     // press (active-low)
            repeat(8) @(posedge CLOCK_50);  // hold through debounce
            KEY[0] = 1;                     // release
            repeat(8) @(posedge CLOCK_50);  // hold through debounce
            repeat(5) @(posedge CLOCK_50);  // let controller FSM settle
        end
    endtask

    //------------------------------------------------------------------
    // Task: set switches then press Enter
    //------------------------------------------------------------------
    task set_and_enter;
        input [9:0] sw_val;
        begin
            SW = sw_val;
            #5;
            press_enter;
        end
    endtask

    //------------------------------------------------------------------
    // Task: check result_reg via hierarchical access and print pass/fail
    //------------------------------------------------------------------
    task check_result;
        input [15:0]  expected;
        input [127:0] test_name;  // 16 chars — wide enough for all names used here
        reg   [15:0]  actual;
        begin
            @(posedge CLOCK_50); #1;
            actual = dut.u_dp.result_reg;
            if (actual === expected) begin
                $display("  PASS  %-12s  got %04X", test_name, actual);
                pass_count = pass_count + 1;
            end
            else begin
                $display("  FAIL  %-12s  expected %04X, got %04X", test_name, expected, actual);
                fail_count = fail_count + 1;
            end
        end
    endtask

    //------------------------------------------------------------------
    // Task: run a 2-operand operation and check result
    //------------------------------------------------------------------
    task run_op2;
        input [3:0]   opcode;
        input [7:0]   A, B;
        input [15:0]  expected;
        input [127:0] test_name;
        begin
            set_and_enter({6'b0, opcode});
            set_and_enter({2'b0, A});
            set_and_enter({2'b0, B});
            check_result(expected, test_name);
        end
    endtask

    //------------------------------------------------------------------
    // Task: run a 1-operand operation and check result
    //------------------------------------------------------------------
    task run_op1;
        input [3:0]   opcode;
        input [7:0]   A;
        input [15:0]  expected;
        input [127:0] test_name;
        begin
            set_and_enter({6'b0, opcode});
            set_and_enter({2'b0, A});
            check_result(expected, test_name);
        end
    endtask

    //------------------------------------------------------------------
    // Main test sequence
    //------------------------------------------------------------------
    integer i;
    reg [15:0] actual;

    initial begin
        $dumpfile("project5Top_tb.vcd");
        $dumpvars(0, project5Top_tb);

        pass_count = 0;
        fail_count = 0;

        KEY = 4'b1111;
        SW  = 10'd0;

        // Reset (active-low KEY[1])
        KEY[1] = 0;
        repeat(5) @(posedge CLOCK_50);
        KEY[1] = 1;
        repeat(3) @(posedge CLOCK_50);
        $display("=== Reset complete. Beginning tests. ===\n");

        // ---- 0x0 OR with Student ID ----
        // {A,B} = {F0,96} = F096; F096 | 1143 = F1D7
        $display("--- Op 0x0: OR with ID ---");
        run_op2(4'h0, 8'hF0, 8'h96, 16'hF1D7, "OR_ID");

        // ---- 0x1 NAND ----
        // ~(FF & 0F) = ~0F = F0 -> zero-extended = 00F0
        $display("\n--- Op 0x1: NAND ---");
        run_op2(4'h1, 8'hFF, 8'h0F, 16'h00F0, "NAND");

        // ---- 0x2 NOR ----
        // ~(AA | 55) = ~FF = 00 -> 0000
        $display("\n--- Op 0x2: NOR ---");
        run_op2(4'h2, 8'hAA, 8'h55, 16'h0000, "NOR");

        // ---- 0x3 XOR ----
        // FF ^ 0F = F0 -> 00F0
        $display("\n--- Op 0x3: XOR ---");
        run_op2(4'h3, 8'hFF, 8'h0F, 16'h00F0, "XOR");

        // ---- 0x4 COMP (A only) ----
        // ~A5 = 5A -> 005A
        $display("\n--- Op 0x4: COMP ---");
        run_op1(4'h4, 8'hA5, 16'h005A, "COMP");

        // ---- 0x5 ADD (basic) ----
        // sext(0A) + sext(05) = 10 + 5 = 15 = 000F
        $display("\n--- Op 0x5: ADD ---");
        run_op2(4'h5, 8'h0A, 8'h05, 16'h000F, "ADD");

        // ---- 0x5 ADD (signed edge: -1 + 1 = 0) ----
        // sext(FF)=-1, sext(01)=+1 -> 0x0000
        $display("\n--- Op 0x5: ADD signed edge (-1+1=0) ---");
        run_op2(4'h5, 8'hFF, 8'h01, 16'h0000, "ADD_edge");

        // ---- 0x6 SUB (basic) ----
        // sext(0A) - sext(05) = 10 - 5 = 5 = 0005
        $display("\n--- Op 0x6: SUB ---");
        run_op2(4'h6, 8'h0A, 8'h05, 16'h0005, "SUB");

        // ---- 0x6 SUB (signed edge: -128 - 1 = -129 = FF7F) ----
        // sext(80)=-128, sext(01)=1 -> -129 -> FF7F as 16-bit 2's complement
        $display("\n--- Op 0x6: SUB signed edge (-128-1=FF7F) ---");
        run_op2(4'h6, 8'h80, 8'h01, 16'hFF7F, "SUB_edge");

        // ---- 0x7 NEG (A only) ----
        // -sext(01) = -1 = FFFF
        $display("\n--- Op 0x7: NEG ---");
        run_op1(4'h7, 8'h01, 16'hFFFF, "NEG");

        // ---- 0x8 ASL ----
        // sext(01)=0001, <<3 = 0008
        $display("\n--- Op 0x8: ASL ---");
        run_op2(4'h8, 8'h01, 8'h03, 16'h0008, "ASL");

        // ---- 0x9 ASR (negative value: sign should fill) ----
        // sext(F0)=FFF0 (=-16), >>4 = FFFF (=-1)
        $display("\n--- Op 0x9: ASR negative (FFF0>>4=FFFF) ---");
        run_op2(4'h9, 8'hF0, 8'h04, 16'hFFFF, "ASR_neg");

        // ---- 0x9 ASR (positive value: zeros fill) ----
        // sext(40)=0040 (=+64), >>2 = 0010 (=+16)
        $display("\n--- Op 0x9: ASR positive (0040>>2=0010) ---");
        run_op2(4'h9, 8'h40, 8'h02, 16'h0010, "ASR_pos");

        // ---- 0xA CSL ----
        // A=80 -> 0080 (16-bit), rotate left 1 -> 0100
        $display("\n--- Op 0xA: CSL ---");
        run_op2(4'hA, 8'h80, 8'h01, 16'h0100, "CSL");

        // ---- 0xA CSL shamt=0 edge case ----
        // rotate by 0 -> unchanged = 0080
        $display("\n--- Op 0xA: CSL shamt=0 edge ---");
        run_op2(4'hA, 8'h80, 8'h00, 16'h0080, "CSL_zero");

        // ---- 0xB CSR ----
        // A=01 -> 0001, rotate right 1 -> 8000
        $display("\n--- Op 0xB: CSR ---");
        run_op2(4'hB, 8'h01, 8'h01, 16'h8000, "CSR");

        // ---- 0xB CSR shamt=0 edge case ----
        // rotate by 0 -> unchanged = 0001
        $display("\n--- Op 0xB: CSR shamt=0 edge ---");
        run_op2(4'hB, 8'h01, 8'h00, 16'h0001, "CSR_zero");

        // ---- 0xC MULTIPLY: 15 * 7 = 105 = 0x0069 ----
        $display("\n--- Op 0xC: MULTIPLY (15 x 7 = 105 = 0069) ---");
        set_and_enter(10'hC);
        set_and_enter(10'h0F);  // A = 15
        set_and_enter(10'h07);  // B = 7

        // After B entered, FSM is in S_MUL_SHOW: display shows initial {9'b0, B} = 0007
        @(posedge CLOCK_50); #1;
        actual = dut.u_dp.display_val;
        if (actual === 16'h0007) begin
            $display("  PASS  MUL_init   initial product_reg display = %04X", actual);
            pass_count = pass_count + 1;
        end
        else begin
            $display("  FAIL  MUL_init   expected 0007, got %04X", actual);
            fail_count = fail_count + 1;
        end

        // 8 Enter presses to complete all steps
        for (i = 0; i < 8; i = i + 1) begin
            press_enter;
            $display("         MUL step %0d: product_reg = %04X",
                     i+1, dut.u_mul.product_reg[15:0]);
        end

        // After 8 steps FSM enters S_MUL_DONE and latches result into result_reg
        @(posedge CLOCK_50); #1;
        actual = dut.u_dp.result_reg;
        if (actual === 16'h0069) begin
            $display("  PASS  MUL_final  result_reg = %04X", actual);
            pass_count = pass_count + 1;
        end
        else begin
            $display("  FAIL  MUL_final  expected 0069, got %04X", actual);
            fail_count = fail_count + 1;
        end

        // ---- 0xD DEBUG ----
        // result_reg = {A, B} = {AB, CD} = ABCD
        // HEX5/HEX4 show reg_A = AB; LED[7:0] show reg_B = CD
        $display("\n--- Op 0xD: DEBUG ---");
        set_and_enter(10'hD);
        set_and_enter(10'hAB);  // A = 0xAB
        set_and_enter(10'hCD);  // B = 0xCD
        @(posedge CLOCK_50); #1;
        actual = dut.u_dp.result_reg;
        if (actual === 16'hABCD) begin
            $display("  PASS  DEBUG_res  result_reg = %04X", actual);
            pass_count = pass_count + 1;
        end
        else begin
            $display("  FAIL  DEBUG_res  expected ABCD, got %04X", actual);
            fail_count = fail_count + 1;
        end
        // Check LEDs show reg_B = CD during debug mode
        if (LED[7:0] === 8'hCD) begin
            $display("  PASS  DEBUG_LED  LED[7:0] = %02X", LED[7:0]);
            pass_count = pass_count + 1;
        end
        else begin
            $display("  FAIL  DEBUG_LED  expected CD on LED[7:0], got %02X", LED[7:0]);
            fail_count = fail_count + 1;
        end

        // ---- Summary ----
        $display("\n==========================================");
        $display("  Results: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0)
            $display("  ALL TESTS PASSED");
        else
            $display("  *** %0d TEST(S) FAILED — check waveform ***", fail_count);
        $display("==========================================\n");
        $finish;
    end

endmodule