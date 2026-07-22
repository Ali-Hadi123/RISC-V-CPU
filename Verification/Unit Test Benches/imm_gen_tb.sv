import riscv_pkg::*;
`timescale 1ns/1ps

module imm_gen_tb;
  logic [31:0] tb_instr;
  instr_fmt_e tb_imm_src;
  logic [31:0] tb_imm_out;

  //Counters:
  int unsigned total_tests = 0;
  int unsigned passed_tests = 0;

  imm_gen duv(
    .instr(tb_instr),
    .imm_src(tb_imm_src),
    .imm_out(tb_imm_out)
  );

  task verify_imm_gen(
    input logic [31:0] instr,
    input instr_fmt_e instr_type,
    input logic [31:0] exp_imm_out,
    input string test_name
  );

    tb_instr = instr;
    tb_imm_src = instr_type;

    #10;

    total_tests++;

    assert (tb_imm_out === exp_imm_out) begin
      passed_tests++;
      $display("Passed: %s", test_name);
    end
    else
      $display("Failed: %s\nExpected imm_out = %h\nGot imm_out = %h", test_name, exp_imm_out, tb_imm_out);
  endtask

  initial begin
    $dumpfile("imm_gen_tb.vcd");
    $dumpvars(0, imm_gen_tb);

    tb_instr = 32'd0;    //Clearing signals and values.
    tb_imm_src = FMT_I;

    #10;

    $display("STARTING IMM GEN TESTING:");

    verify_imm_gen(32'h0000_0093, FMT_I, 32'h0000_0000, "Test 1: I type (addi rd, rs1, 0)."); 
    verify_imm_gen(32'hABC0_0093, FMT_I, 32'hFFFF_FABC, "Test 2: I type (addi rd, rs1, -1348)."); 
    verify_imm_gen(32'h1200_21A3, FMT_S, 32'h0000_0123, "Test 3: S type.");
    verify_imm_gen(32'h4000_0063, FMT_B, 32'h0000_0400, "Test 4: B type.");
    verify_imm_gen(32'h8000_0037, FMT_U, 32'h8000_0000, "Test 5: U type.");
    verify_imm_gen(32'h8000_006F, FMT_J, 32'hFFF0_0000, "Test 6: J type.");
    verify_imm_gen(32'h8000_006F, 5'b11111, 32'b0, "Test 7: Invalid imm_src value.");

    $display("IMM GENERATOR TESTING COMPLETE!");
    $display("Results: %0d/%0d tests passed.", passed_tests, total_tests);
  end
endmodule
