import riscv_pkg::*;

module regf (
  input clk,
  input [4:0] rs1, rs2, rd,
  input [31:0] wd,
  input we,
  output [31:0] rdata1, rdata2
);

  logic [31:0] regs [0:31];

  assign rdata1 = (rs1 == 0) ? 0 : regs[rs1];
  assign rdata2 = (rs2 == 0) ? 0 : regs[rs2];

  always @(posedge clk)
    if (we && rd != 0)
      regs[rd] <= wd;
endmodule
