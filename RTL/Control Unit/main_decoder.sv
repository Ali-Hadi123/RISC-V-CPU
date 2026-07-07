import riscv_pkg::*;

module main_decoder (
  input opcode_e opcode,
  output pc_src,
  output [1:0] result_src,
  output mem_write,
  output alu_src,
  output [1:0] imm_src,
  output reg_write,
  output [1:0] alu_op
);

  logic branch;
  logic jump;
  
  always_comb begin
    pc_src = 1'b0;
    result_src = 1'b0;
    mem_write = 1'b0;
    alu_src = 1'b0;
    imm_src = FMT_I;
    reg_write = 1'b0;
