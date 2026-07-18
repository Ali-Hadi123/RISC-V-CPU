import riscv_pkg::*;

module top #(
  parameter int unsigned ram_size = 1024,
  parameter int unsigned rom_size = 1024,
  parameter init_mem = ""
)(
  input logic clk,
  input logic rst
);

  //Initializng pc variables:

  logic [XLEN-1:0] pc;
  logic [XLEN-1:0] next_pc;
  logic [XLEN-1:0] PCPlus4;
  logic [XLEN-1:0] PCTarget;
