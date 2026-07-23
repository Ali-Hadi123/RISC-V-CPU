import riscv_pkg::*;
`timescale 1ns/1ps

module regf_tb;
  logic clk;
  logic [REG_ADDR_W-1:0] tb_rs1, tb_rs2, tb_rd;
  logic [XLEN-1:0] tb_wd;
  logic reg_write;
  logic [XLEN-1:0] tb_rdata1, tb_rdata2;

  int unsigned total_tests = 0;
  int unsigned passed_tests = 0;

  regf duv(
    .clk(clk),
    .rs1(tb_rs1),
    .rs2(tb_rs2),
    .rd(tb_rd),
    .wd(tb_wd),
    .reg_write(reg_write),
    .rdata1(tb_rdata1),
    .rdata2(tb_rdata2)
  );

  logic clk = 0;
  always #5 clk = ~clk;

  //Concurrent assert statements for testing (these tests are constantly being ran):
  
  property x0_value:
    @(posedge clk) (tb_rs1 == 5'b0) |-> (tb_rdata1 == 32'b0);
  endproperty

  total_tests++;
  
  assert x0_value begin
    passed_tests++;
    $display("x0 holds 0 is true, test PASSED.");
  end
  else
    $error("x0 does NOT hold 0, test FAILED.");

  property write_then_read:
    @(posedge clk) (reg_write && tb_rs1 != 0 && tb_rs1 == tb_rd) |=> (tb_rdata1 == $past(wd));
  endproperty

  total_tests++;

  assert write_then_read begin
    passed_tests++;
    $display("Writing and then reading a register works, test PASSED.");
  end
  else
    $error("Writing and then reading a register doesn't work, test FAILED.");

  task write_reg(
    input [REG_ADDR_W-1:0] rn,
    input [XLEN-1:0] data
  );
    @(negedge clk);
    reg_write = 1'b1;
    tb_rd = rn;
    tb_wd = data;
    
    @(negedge clk);
    reg_write = 1'b0;
  endtask

  task read_reg(input [REG_ADDR_W-1:0] rn);
    @(negedge clk);
    rb_rs1 = rn;
  endtask  
