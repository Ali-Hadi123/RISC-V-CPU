import riscv_pkg::*;

module pc_comp (
  input logic is_branch,
  input logic branch_taken,
  input logic is_jal,
  input logic is_jalr,
  output pc_src_e pc_src
);

  always_comb begin
    if (is_jalr)
      pc_src = PC_RESULT;
    else if (is_jal | (is_branch & branch_taken))
      pc_src = PC_TARGET;
    else
      pc_src = PC_PLUS4;
  end
  
endmodule
