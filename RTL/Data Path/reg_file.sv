import riscv_pkg::*;

module regf (
  input clk,
  input [REG_ADDER_W-1:0] rs1, rs2, rd,
  input [XLEN-1:0] wd,
  input we,
  output [XLEN-1:0] rdata1, rdata2
);

  logic [XLEN-1:0] regs [0:31];

  assign rdata1 = (rs1 == 0) ? 0 : regs[rs1];
  assign rdata2 = (rs2 == 0) ? 0 : regs[rs2];

  always @(posedge clk)
    if (we && rd != 0)
      regs[rd] <= wd;
endmodule
