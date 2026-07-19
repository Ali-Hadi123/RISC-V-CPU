import riscv_pkg::*;

module regf (
  input clk,
  input [REG_ADDR_W-1:0] rs1, rs2, rd,
  input [XLEN-1:0] wd,
  input reg_write,
  output [XLEN-1:0] rdata1, rdata2
);

  logic [XLEN-1:0] regs [0:REG_COUNT-1];

  assign rdata1 = (rs1 == 0) ? 0 : regs[rs1];
  assign rdata2 = (rs2 == 0) ? 0 : regs[rs2];

  always_ff
    if (reg_write & rd != 0)
      regs[rd] <= wd;
endmodule
