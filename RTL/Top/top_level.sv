import riscv_pkg::*;

module top #(
  parameter int unsigned ram_size = 1024,
  parameter int unsigned rom_size = 1024,
  parameter init_mem = ""
)(
  input logic clk,
  input logic rst
);

  //Initializations: 
  
  //pc:
  logic [XLEN-1:0] pc;
  logic [XLEN-1:0] next_pc;
  logic [XLEN-1:0] PCPlus4;
  logic [XLEN-1:0] PCTarget;
  logic [XLEN-1:0] PCResult;

  //instr:
  logic [ILEN-1:0] instr;

  //Control Signals:
  result_src_e result_src;
  logic mem_read;
  logic mem_write;
  alu_src_e alu_src;
  instr_fmt_e imm_src;
  logic reg_write;
  
