import riscv_pkg::*;

module mem_decoder (
  input opcode_e op_code,
  input logic [2:0] funct3,
  output mem_size_e mem_size,
  output logic mem_unsigned,
  output logic illegal_instr_mem
);

  always_comb begin
    mem_size = MEM_WORD;  //Safe defaults.
    mem_unsigned = 1'b0;
    illegal_instr_mem = 1'b0;

    unique case(op_code)
      OP_LOAD: begin
        unique case(funct3_load_e'(funct3))
          F3_LB: begin
            mem_size = MEM_BYTE;
            mem_unsigned = 1'b0;
          end
          F3_LBU: begin
            mem_size = MEM_BYTE;
            mem_unsigned = 1'b1;
          end
          F3_LH: begin
            mem_size = MEM_HALF;
            mem_unsigned = 1'b0;
          end
          F3_LHU: begin
            mem_size = MEM_HALF;
            mem_unsigned = 1'b1;
          end
          F3_LW: begin
            mem_size = MEM_WORD;
            mem_unsigned = 1'b0;
          end
          default: begin
            mem_size = MEM_WORD;
            mem_unsigned = 1'b0;
            illegal_instr_mem = 1'b1;
          end
        endcase
      end

      OP_STORE: begin
        unique case(funct3_store_e'(funct3))
          F3_SB: mem_size = MEM_BYTE;
          F3_SH: mem_size = MEM_HALF;
          F3_SW: mem_size = MEM_WORD;
          
          default: begin
            mem_size = MEM_WORD;
            illegal_instr_mem = 1'b1;
          end
        endcase
      end

      default: begin
        mem_size = MEM_WORD;
        mem_unsigned = 1'b0;
      end
    endcase
  end
endmodule
