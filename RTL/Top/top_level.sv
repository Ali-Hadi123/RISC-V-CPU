import riscv_pkg::*;

module top #(
  parameter int unsigned ram_size = 1024,
  parameter int unsigned rom_size = 1024,
  parameter init_mem = ""
)(
  input logic clk,
  input logic rst
);

  //Fetching Instructions:

  logic [XLEN-1] pc_out;
  logic [XLEN-1] next_pc;
  logic [XLEN-1] instr;

  pc u_pc(
    .clk(clk),
    .rst(rst),
    .next_pc(next_pc),
    .pc_out(pc_out)
  );

  imem #(
    .init_mem(init_mem),
    .rom_size(rom_size)
  ) u_imem(
    .pc_addr(pc_out),
    .instr(instr)
  );

  //Instruction Field Extraction:

  opcode_e op_code;
  logic [4:0] rs1_addr, rs2_addr, rd_addr;
  logic [2:0] funct3;
  logic [6:0] funct7;

  assign op_code = opcode_e'(get_opcode(instr));
  assign rs1_addr = get_rs1(instr);
  assign rs2_addr = get_rs2(instr);
  assign rd_addr = get_rd(instr);
  assign funct3 = get_funct3(instr);
  assign funct7 = get_funct7(instr);

  //Generating Control Signals:

  result_src_e result_src;
  logic mem_read, mem_write;
  alu_src_e alu_src;
  instr_fmt_e imm_src;
  logic reg_write;
  logic is_branch, is_jal, is_jalr;
  alu_op_e alu_op;
  logic illegal_instr_main;
