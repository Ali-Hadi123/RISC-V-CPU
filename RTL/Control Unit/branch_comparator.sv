import riscv_pkg::*;

module branch_comp (
  input funct3_branch_e funct3,
  input logic is_zero,
  input logic is_less,
  input logic is_less_u,
  output logic branch_taken
);

  always_comb begin
    unique case(funct3)
        F3_BEQ:  branch_taken = is_zero;
        F3_BNE:  branch_taken = ~is_zero;
        F3_BLT:  branch_taken = is_less;
        F3_BGE:  branch_taken = ~is_less;
        F3_BLTU: branch_taken = is_less_u;
        F3_BGEU: branch_taken = ~is_less_u;
        default: branch_taken = 1'b0;
    endcase
  end
endmodule
