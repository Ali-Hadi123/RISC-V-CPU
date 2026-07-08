import riscv_pkg::*;

module dmem #(
  parameter int unsigned memory_space = 1024
)
(
  input clk,
  input logic [XLEN-1:0] byte_addr,
  input logic [XLEN-1:0] wdata,
);
