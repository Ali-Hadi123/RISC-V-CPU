import riscv_pkg::*;

module top #(
  parameter int unsigned ram_size = 1024,
  parameter int unsigned rom_size = 1024,
  parameter init_mem = ""
)(
  input logic clk,
  input logic rst
);

  
