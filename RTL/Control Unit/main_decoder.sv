import riscv_pkg::*;

module main_decoder (
  input opcode_e op_code,
  input logic [2:0] funct3,
  input is_zero,
  input is_less,
  input is_less_u,
  
  output pc_src,
  output result_src_e result_src,
  output mem_read,
  output mem_write,
  output alu_src,
  output instr_fmt_e [1:0] imm_src,
  output reg_write,
  
  output [1:0] alu_op
);

  logic branch;
  logic branch_taken;
  logic jump;
  
  always_comb begin
    
    branch     = 1'b0;
    jump       = 1'b0;

    // Creating safe signals as a default case.
    
    result_src = RESULT_ALU;          // ALU result
    mem_write  = 1'b0;           // Never write memory by default
    alu_src    = 1'b0;           // Use register operand (RD2)
    imm_src    = FMT_I;          // Doesn't matter unless ALUSrc=1
    reg_write  = 1'b0;           // Don't write registers
    alu_op     = ALUOP_ADD;          // Default ALU operation (typically ADD)
    
    case(op_code)
      OP_ARTH_REG: begin
        result_src = RESULT_ALU;
        mem_write = 1'b0;
        alu_src = 1'b0;
        imm_src = FMT_I;
        reg_write = 1'b1;
        alu_op = ALUOP_FUNCT;
      end

      OP_ARTH_IMM: begin
        result_src = RESULT_ALU;
        mem_write = 1'b0;
        alu_src = 1'b1;
        imm_src = FMT_I;
        reg_write = 1'b1;
        alu_op = ALUOP_ADD;
      end

      OP_LOAD: begin
        result_src = RESULT_MEM;
        mem_write = 1'b0;
        alu_src = 1'b1;
        imm_src = FMT_I;
        reg_write = 1'b1;
        alu_op = ALUOP_ADD;
      end

      OP_STORE: begin
        result_src = RESULT_ALU;
        mem_write = 1'b1;
        alu_src = 1'b1;
        imm_src = FMT_S;
        reg_write = 1'b0;
        alu_op = ALUOP_ADD;
      end

      OP_BRANCH: begin
        branch = 1'b1;
        
        result_src = RESULT_ALU;
        mem_write = 1'b0;
        alu_src = 1'b0;
        imm_src = FMT_B;
        reg_write = 1'b0;
        alu_op = ALUOP_BRANCH;
      end

      OP_JAL: begin
        jump = 1'b1;
        
        result_src = RESULT_PCPLUS4;
        mem_write = 1'b0;
        alu_src = 1'b0;
        imm_src = FMT_J;
        reg_write = 1'b1;
        alu_op = ALUOP_ADD;
      end

      OP_JALR: begin
        jump = 1'b1;
        
        result_src = RESULT_PCPLUS4;
        mem_write = 1'b0;
        alu_src = 1'b1;
        imm_src = FMT_I;
        reg_write = 1'b1;
        alu_op = ALUOP_ADD;
      end

      OP_LUI: begin
        result_src = RESULT_ALU;        
        mem_write  = 1'b0;         
        alu_src    = 1'b1;        
        imm_src    = FMT_U;       
        reg_write  = 1'b1;           
        alu_op     = ALUOP_PASS_B;
      end

      OP_AUIPC: begin
        result_src = RESULT_ALU;        
        mem_write  = 1'b0;         
        alu_src    = 1'b1;        
        imm_src    = FMT_U;       
        reg_write  = 1'b1;           
        alu_op     = ALUOP_ADD_PC;
      end
    endcase
  end
endmodule
