import riscv_pkg::*;
`timescale 1ns/1ps

module alu_tb;

  logic [XLEN-1:0] data_a, data_b;
  alu_ctrl_e tb_alu_ctrl;
  logic [XLEN-1:0] tb_result;
  logic tb_zero, tb_less, tb_less_u;

  //Counters:
  int unsigned total_tests = 0;
  int unsigned passed_tests = 0;
  
  alu duv(
    .alu_ctrl(tb_alu_ctrl),
    .a(data_a),
    .b(data_b),
    .result(tb_result),
    .is_zero(tb_zero),
    .is_less(tb_less),
    .is_less_u(tb_less_u)
  );

  task verify_alu(
    input logic [XLEN-1:0] a,
    input logic [XLEN-1:0] b,
    input alu_ctrl_e ctrl,
    input logic [XLEN-1:0] exp_result,
    input logic exp_zero,
    input logic exp_less,
    input logic exp_less_u,
    input string test_name
  );

    data_a = a;
    data_b = b;
    tb_alu_ctrl = ctrl;

    #10;

    total_tests++;

    if (tb_result === exp_result && tb_zero === exp_zero && tb_less === exp_less && tb_less_u === exp_less_u) begin
      passed_tests++;
      $display("Passed: %s", test_name);
    end
    else
      $display(
        "FAILED: %s\nExpected result=%h zero=%b less=%b less_u=%b\nGot result=%h zero=%b less=%b less_u=%b",
        test_name, exp_result, exp_zero, exp_less, exp_less_u, tb_result, tb_zero, tb_less, tb_less_u
      );
  endtask
  
  initial begin
    $dumpfile("alu_tb.vcd");
    $dumpvars(0, alu_tb);

    data_a = 32'd0;    //Ensuring all signals are cleared before testing.
    data_b = 32'd0;
    tb_alu_ctrl = ALU_ADD;

    #10;

    $display("STARTING ALU TESTING");

    verify_alu(32'd56, 32'd44, ALU_ADD, 32'd100, 1'b0, 1'b0, 1'b0, "Test 1: Addition"); //Testing 56 + 44 = 100
    verify_alu(32'd1, 32'd53, ALU_SUB, -32'd52, 1'b0, 1'b1, 1'b1, "Test 2: Subtraction"); //Testing 1 - 53 = -52
    verify_alu(32'b10111, 32'b10101, ALU_AND, 32'b10101, 1'b0, 1'b0, 1'b0, "Test 3: AND"); //Testing 10111 & 10101 = 10101
    verify_alu(32'b0011, 32'b1011, ALU_OR, 32'b1011, 1'b0, 1'b1, 1'b1, "Test 4: OR"); //Testing 0011 | 1011 = 1011
    verify_alu(32'b111, 32'b101, ALU_XOR, 32'b010, 1'b0, 1'b0, 1'b0, "Test 5: XOR"); //Testing 111 ^ 101 = 010
    verify_alu(32'd5, -32'd10, ALU_SLT, 32'd0, 1'b1, 1'b0, 1'b1, "Test 6: SLT"); //Testing 5 < -10 = False
    verify_alu(32'd5, -32'd10, ALU_SLTU, 32'd1, 1'b0, 1'b0, 1'b1, "Test 7: SLTU"); //Testing 5 < -10 = True (unsigned)
    verify_alu(32'd7, 32'd2, ALU_SLL, 32'd28, 1'b0, 1'b0, 1'b0, "Test 8: SLL"); //Testing 7 << 2 = 28
    verify_alu(32'd64, 32'd3, ALU_SRL, 32'd8, 1'b0, 1'b0, 1'b0, "Test 9: SRL"); //Testing 64 >> 3 = 8
    verify_alu(-32'b10000, 32'b10, ALU_SRA, -32'b100, 1'b0, 1'b1, 1'b0, "Test 10: SRA"); //Testing -16 >> 2 = -4
    verify_alu(32'd5, 32'd2, ALU_PASS_B, 32'd2, 1'b0, 1'b0, 1'b0, "Test 11: PASS B"); //Testing pass b

    $display("ALU TESTING COMPLETED!");
    $display("Results: %0d/%0d tests passed.", passed_tests, total_tests);
  end
endmodule
