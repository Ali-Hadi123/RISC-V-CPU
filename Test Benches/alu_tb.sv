// ============================================================================
// alu_tb.sv - Self-checking testbench for the RV32I ALU (RTL/Data Path/alu.sv)
//
// Compile order (example, Questa/ModelSim):
//   vlog RTL/riscv_pkg.sv
//   vlog "RTL/Data Path/alu.sv"
//   vlog alu_tb.sv
//   vsim -c alu_tb -do "run -all; quit"
//
// Strategy:
//   - A reference model (model_result) reimplements the expected ALU
//     behavior independently of the DUT's internal implementation.
//   - run_test() drives the DUT, computes expected result/flags from the
//     model, and self-checks every output (result, is_zero, is_less,
//     is_less_u) on every call.
//   - Directed tests hit each opcode plus known corner cases (overflow,
//     sign-extension, shift-amount truncation, zero flag, etc).
//   - A randomized loop follows for broader coverage.
// ============================================================================

import riscv_pkg::*;

module alu_tb;

  // ---------------- DUT signals ----------------
  alu_ctrl_e        alu_ctrl;
  logic [XLEN-1:0]  a, b;
  logic [XLEN-1:0]  result;
  logic             is_zero, is_less, is_less_u;

  // ---------------- Bookkeeping ----------------
  int unsigned test_count = 0;
  int unsigned pass_count = 0;
  int unsigned fail_count = 0;

  // ---------------- DUT instantiation ----------------
  alu dut (
    .alu_ctrl  (alu_ctrl),
    .a         (a),
    .b         (b),
    .result    (result),
    .is_zero   (is_zero),
    .is_less   (is_less),
    .is_less_u (is_less_u)
  );

  // ---------------- Reference model ----------------
  // Mirrors the *intended* RV32I ALU behavior, independent of the DUT's
  // internal implementation (e.g. its shared adder/subtractor).
  function automatic logic [XLEN-1:0] model_result(input alu_ctrl_e ctrl,
                                                     input logic [XLEN-1:0] a_in, b_in);
    case (ctrl)
      ALU_ADD:    model_result = a_in + b_in;
      ALU_SUB:    model_result = a_in - b_in;
      ALU_AND:    model_result = a_in & b_in;
      ALU_OR:     model_result = a_in | b_in;
      ALU_XOR:    model_result = a_in ^ b_in;
      ALU_SLT:    model_result = {{(XLEN-1){1'b0}}, ($signed(a_in) < $signed(b_in))};
      ALU_SLTU:   model_result = {{(XLEN-1){1'b0}}, (a_in < b_in)};
      ALU_SLL:    model_result = a_in << b_in[4:0];
      ALU_SRL:    model_result = a_in >> b_in[4:0];
      ALU_SRA:    model_result = $signed(a_in) >>> b_in[4:0];
      ALU_PASS_B: model_result = b_in;
      default:    model_result = '0;
    endcase
  endfunction

  // ---------------- Stimulus + self-check task ----------------
  task automatic run_test(input string name, input alu_ctrl_e ctrl,
                           input logic [XLEN-1:0] a_in, b_in);
    logic [XLEN-1:0] exp_result;
    logic            exp_zero, exp_less, exp_lessu;

    alu_ctrl = ctrl;
    a        = a_in;
    b        = b_in;
    #1; // let combinational logic settle

    exp_result = model_result(ctrl, a_in, b_in);
    exp_zero   = (exp_result == '0);
    // is_less / is_less_u are computed unconditionally from a,b in the DUT,
    // independent of alu_ctrl - the model reflects that here too.
    exp_less   = ($signed(a_in) < $signed(b_in));
    exp_lessu  = (a_in < b_in);

    test_count++;

    if (result !== exp_result || is_zero !== exp_zero ||
        is_less !== exp_less || is_less_u !== exp_lessu) begin
      fail_count++;
      $display("[FAIL] %-28s ctrl=%-10s a=0x%08h b=0x%08h | result=0x%08h (exp 0x%08h) zero=%0b(exp %0b) less=%0b(exp %0b) lessu=%0b(exp %0b)",
                name, ctrl.name(), a_in, b_in,
                result, exp_result, is_zero, exp_zero,
                is_less, exp_less, is_less_u, exp_lessu);
    end else begin
      pass_count++;
      $display("[PASS] %-28s ctrl=%-10s a=0x%08h b=0x%08h -> result=0x%08h",
                name, ctrl.name(), a_in, b_in, result);
    end
  endtask

  // ---------------- Test sequence ----------------
  initial begin
    $display("========================================");
    $display(" ALU Testbench Starting");
    $display("========================================");

    // ---------------- ALU_ADD ----------------
    run_test("ADD basic",             ALU_ADD, 32'd10,       32'd15);
    run_test("ADD zero + zero",       ALU_ADD, 32'd0,        32'd0);
    run_test("ADD negative operand",  ALU_ADD, -32'sd5,      32'd3);
    run_test("ADD overflow wrap",     ALU_ADD, 32'hFFFF_FFFF,32'd1);
    run_test("ADD max_pos + max_pos", ALU_ADD, 32'h7FFF_FFFF,32'h7FFF_FFFF);

    // ---------------- ALU_SUB ----------------
    run_test("SUB basic",             ALU_SUB, 32'd20,       32'd5);
    run_test("SUB result zero",       ALU_SUB, 32'd42,       32'd42);
    run_test("SUB negative result",   ALU_SUB, 32'd5,        32'd20);
    run_test("SUB underflow",         ALU_SUB, 32'h0000_0000,32'd1);

    // ---------------- ALU_AND / OR / XOR ----------------
    run_test("AND basic",             ALU_AND, 32'hFF00_FF00,32'h0F0F_0F0F);
    run_test("AND to zero",           ALU_AND, 32'hFFFF_FFFF,32'h0000_0000);
    run_test("OR basic",              ALU_OR,  32'hFF00_FF00,32'h00FF_00FF);
    run_test("OR with zero",          ALU_OR,  32'hFFFF_FFFF,32'h0000_0000);
    run_test("XOR basic",             ALU_XOR, 32'hAAAA_AAAA,32'h5555_5555);
    run_test("XOR identical->zero",   ALU_XOR, 32'hDEAD_BEEF,32'hDEAD_BEEF);

    // ---------------- ALU_SLT (signed) ----------------
    run_test("SLT true, positives",   ALU_SLT, 32'd3,        32'd5);
    run_test("SLT false, positives",  ALU_SLT, 32'd5,        32'd3);
    run_test("SLT true, neg < pos",   ALU_SLT, -32'sd5,      32'd3);
    run_test("SLT false, pos > neg",  ALU_SLT, 32'd3,        -32'sd5);
    run_test("SLT equal operands",    ALU_SLT, 32'd7,        32'd7);
    run_test("SLT neg vs neg",        ALU_SLT, -32'sd10,     -32'sd3);

    // ---------------- ALU_SLTU (unsigned) ----------------
    run_test("SLTU true",             ALU_SLTU, 32'd3,        32'd5);
    run_test("SLTU false",            ALU_SLTU, 32'd5,        32'd3);
    run_test("SLTU 0xFFFFFFFF vs 0",  ALU_SLTU, 32'hFFFF_FFFF,32'd0);
    run_test("SLTU 0 vs 0xFFFFFFFF",  ALU_SLTU, 32'd0,        32'hFFFF_FFFF);
    run_test("SLTU equal operands",   ALU_SLTU, 32'd7,        32'd7);

    // ---------------- ALU_SLL ----------------
    run_test("SLL by 0",              ALU_SLL, 32'h0000_0001,32'd0);
    run_test("SLL by 1",              ALU_SLL, 32'h0000_0001,32'd1);
    run_test("SLL by 31",             ALU_SLL, 32'h0000_0001,32'd31);
    run_test("SLL shifts out bits",   ALU_SLL, 32'hFFFF_FFFF,32'd4);
    run_test("SLL shamt>31 truncates",ALU_SLL, 32'h0000_0001,32'd32); // b[4:0]=0

    // ---------------- ALU_SRL ----------------
    run_test("SRL by 0",              ALU_SRL, 32'hFFFF_FFFF,32'd0);
    run_test("SRL by 1",              ALU_SRL, 32'h8000_0000,32'd1);
    run_test("SRL by 31",             ALU_SRL, 32'h8000_0000,32'd31);
    run_test("SRL no sign extension", ALU_SRL, 32'h8000_0000,32'd4);

    // ---------------- ALU_SRA ----------------
    run_test("SRA by 0",              ALU_SRA, 32'h8000_0000,32'd0);
    run_test("SRA negative by 1",     ALU_SRA, 32'h8000_0000,32'd1);
    run_test("SRA negative by 31",    ALU_SRA, 32'h8000_0000,32'd31);
    run_test("SRA positive by 4",     ALU_SRA, 32'h7000_0000,32'd4);
    run_test("SRA sign-extends",      ALU_SRA, 32'hF000_0000,32'd4);

    // ---------------- ALU_PASS_B (used for LUI) ----------------
    run_test("PASS_B basic",          ALU_PASS_B, 32'hDEAD_BEEF, 32'h1234_5678);
    run_test("PASS_B zero",           ALU_PASS_B, 32'hFFFF_FFFF, 32'h0000_0000);

    // ---------------- Flag decoupling ----------------
    // is_less / is_less_u are combinational functions of a,b only - they
    // must be correct even when alu_ctrl selects an unrelated operation
    // (this matters for BLT/BGE/BLTU/BGEU, which read these flags directly
    // instead of routing through the ALU result).
    run_test("is_less valid during AND",  ALU_AND, -32'sd1, 32'd5);
    run_test("is_less_u valid during OR", ALU_OR,  32'd1,   32'hFFFF_FFFF);
    run_test("zero flag via SUB equal",   ALU_SUB, 32'd100, 32'd100);
    run_test("zero flag via ADD to 0",    ALU_ADD, -32'sd50, 32'd50);

    // ---------------- Randomized testing ----------------
    $display("----------------------------------------");
    $display(" Beginning randomized testing (200 vectors)");
    $display("----------------------------------------");

    for (int i = 0; i < 200; i++) begin
      alu_ctrl_e       rand_ctrl;
      logic [XLEN-1:0] rand_a, rand_b;
      rand_ctrl = alu_ctrl_e'($urandom_range(0, 10)); // 11 legal opcodes: ALU_ADD..ALU_PASS_B
      rand_a    = $urandom();
      rand_b    = $urandom();
      run_test($sformatf("random_%0d", i), rand_ctrl, rand_a, rand_b);
    end

    // ---------------- Summary ----------------
    $display("========================================");
    $display(" Test Summary: %0d run, %0d passed, %0d failed",
              test_count, pass_count, fail_count);
    if (fail_count == 0)
      $display(" RESULT: ALL TESTS PASSED");
    else
      $display(" RESULT: %0d TEST(S) FAILED", fail_count);
    $display("========================================");

    $finish;
  end

endmodule
