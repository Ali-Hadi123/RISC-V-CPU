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

  always #10 clk = ~clk;
