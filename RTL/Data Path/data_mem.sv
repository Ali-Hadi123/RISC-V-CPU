import riscv_pkg::*;

module dmem #(
  parameter int unsigned memory_space = 1024
)
(
  input clk,
  input logic [XLEN-1:0] byte_addr,
  input logic [XLEN-1:0] wdata,
  input logic mem_read,
  input logic mem_write,
  input mem_size_e mem_size,
  input logic mem_unsigned,
  output logic [XLEN-1:0] read_data
);

  logic [XLEN-1:0] ram [0:memory_space-1]; //Creates 4KB of memory when memory_space = 1024.
