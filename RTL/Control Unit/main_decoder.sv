import riscv_pkg::*;

module main_decoder (
  input opcode_e op_code,
  input is_zero,
  input is_less,
  input is_less_u,
  
  output pc_src,
  output [1:0] result_src,
  output mem_read,
  output mem_write,
  output alu_src,
  output instr_fmt_e [1:0] imm_src,
  output reg_write,
  
  output [1:0] alu_op
);

  logic branch;
  logic jump;

  assign pc_src = (branch & is_zero) | jump;
  
  always_comb begin
    
    branch     = 1'b0;
    jump       = 1'b0;

    // Creating safe signals as a default case.
    
    result_src = 2'b00;          // ALU result
    mem_write  = 1'b0;           // Never write memory by default
    alu_src    = 1'b0;           // Use register operand (RD2)
    imm_src    = FMT_I;          // Doesn't matter unless ALUSrc=1
    reg_write  = 1'b0;           // Don't write registers
    alu_op     = 2'b00;          // Default ALU operation (typically ADD)
    
    case(op_code)
      OP_ARTH_REG: begin
        reg_write = 1'b1;
        alu_src = 1'b0;
        result_src = 2'b00;
        
        
