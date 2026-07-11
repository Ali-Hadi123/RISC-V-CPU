import riscv_pkg::*;

module alu_decoder (
  input alu_op_e alu_op,
  input logic [2:0] funct3,
  input logic [6:0] funct7,
  output alu_ctrl_e alu_ctrl
);

  
