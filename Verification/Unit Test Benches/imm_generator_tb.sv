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
    $dumpfile("imm_generator_tb.vcd");
    $dumpvars(0, imm_generator_tb);

    tb_instr = 32'd0;    //Clearing signals and values.
    tb_imm_src = FMT_I;

    #10;

    $display("STARTING IMM GEN TESTING:")

    verify_imm_gen();
