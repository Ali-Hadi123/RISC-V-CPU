import riscv_pkg::*;

module alu (
  input alu_op_e alu_cntrl,
  input [XLEN-1:0] a,
  input [XLEN-1:0] b,
  output logic [XLEN-1:0] result,
  output logic zero
);

  logic [XLEN-1:0] sum;
  logic cout;

  always_comb begin
    if (alu_cntrl == ALU_ADD)
      {cout, sum} = {1'b0, a} + {1'b0,  b};
    else
      {cout, sum} = {1'b0, a} + {1'b0, ~b} + 33'd1;
  end

  always_comb begin
    unique case(alu_cntrl)
