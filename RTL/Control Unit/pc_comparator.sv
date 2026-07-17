module pc_comp (
  input logic branch,
  input logic branch_taken,
  input logic jump,
  output logic pc_src
);

  assign pc_src = jump | (branch & branch_taken);
  
endmodule
