//imm_gen is hardcoded for RV32I since different instruction sets (e.g. RV64I) would require different splicing.
import riscv_pkg::*;

module imm_gen (
  input logic [31:0] instr,
  input instr_fmt_e imm_src,
  output logic [31:0] imm_out
);

  //Obtaining the immediate from the instruction differently based on what type of instruction imm_scr reports.
  
  always_comb            
    unique case(imm_src)  
      FMT_I: imm_out = {{20{instr[31]}}, instr[31:20]};
      FMT_S: imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      FMT_B: imm_out = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
      FMT_U: imm_out = {instr[31:12], 12'b0};
      FMT_J: imm_out = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
      default: imm_out = {32{1'b0}};
    endcase
endmodule
