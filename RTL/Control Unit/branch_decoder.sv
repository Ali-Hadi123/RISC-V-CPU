import riscv_pkg::*;

module branch_comp (
  input funct3_branch_e funct3,
  input logic is_zero,
  input logic is_less,
  input logic is_less_u,
  output logic branch_taken,
  output logic illegal_instr_branch
);

  always_comb begin
    illegal_instr_branch = 1'b0;
    
    unique case(funct3)
        F3_BEQ:  branch_taken = is_zero;
        F3_BNE:  branch_taken = ~is_zero;
        F3_BLT:  branch_taken = is_less;
        F3_BGE:  branch_taken = ~is_less;
        F3_BLTU: branch_taken = is_less_u;
        F3_BGEU: branch_taken = ~is_less_u;
        
        default: begin
          branch_taken = 1'b0;
          illegal_instr_branch = 1'b1;
        end
    endcase
  end
endmodule
