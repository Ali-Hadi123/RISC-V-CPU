import riscv_pkg::*;

module imm_gen (
  input logic [31:0] instr,
  input instr_fmt_e imm_scr,
  output logic [31:0] imm_out
);
//ISBUJ
  always_comb
    unique case(imm_scr)
      
