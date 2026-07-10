package riscv_pkg;

  parameter int XLEN       = 32;                  
  parameter int REG_COUNT  = 32;
  parameter int REG_ADDR_W = $clog2(REG_COUNT);
  parameter int ILEN       = 32;

  typedef enum logic [6:0] {    //Possible OP codes (instr[6:0]).
    OP_LOAD     = 7'b0000011,
    OP_STORE    = 7'b0100011,
    OP_BRANCH   = 7'b1100011,
    OP_JALR     = 7'b1100111,
    OP_JAL      = 7'b1101111,
    OP_ARTH_IMM = 7'b0010011,
    OP_ARTH_REG = 7'b0110011,
    OP_AUIPC    = 7'b0010111,
    OP_LUI      = 7'b0110111,
    OP_SYSTEM   = 7'b1110011,
    OP_FENCE    = 7'b0001111
  } opcode_e;

  typedef enum logic [2:0] {  //Possible funct3 values for branch instructions.
    F3_BEQ  = 3'b000,
    F3_BNE  = 3'b001,
    F3_BLT  = 3'b100,
    F3_BGE  = 3'b101,
    F3_BLTU = 3'b110,
    F3_BGEU = 3'b111
  } funct3_branch_e;

  typedef enum logic [2:0] {  //Possible funct3 values for load instructions.
    F3_LB  = 3'b000,
    F3_LH  = 3'b001,
    F3_LW  = 3'b010,
    F3_LBU = 3'b100,
    F3_LHU = 3'b101
  } funct3_load_e;

  typedef enum logic [2:0] {  //Possible funct3 values for store instructions.
    F3_SB = 3'b000,
    F3_SH = 3'b001,
    F3_SW = 3'b010
  } funct3_store_e;

  typedef enum logic [2:0] {  //Possible funct3 values for arithmatic.
    F3_ADD_SUB = 3'b000,
    F3_SLL     = 3'b001,
    F3_SLT     = 3'b010,
    F3_SLTU    = 3'b011,
    F3_XOR     = 3'b100,
    F3_SRL_SRA = 3'b101,
    F3_OR      = 3'b110,
    F3_AND     = 3'b111
  } funct3_arth_e;

  typedef enum logic [6:0] { //Distinguishes SUB from ADD and SRA from SRL based on funct7 value.
    F7_NORMAL = 7'b0000000,
    F7_ALT    = 7'b0100000   
  } funct7_e;

  //SystemVerilog automatically assigns interger values starting from 0 and counting upwards for enums that don't have explicit
  //values. Since the values of the enums below don't correspond to specefic bits of machine instructions, their values don't matter
  //and it's ok to let SystemVerilog assign the default values.
  
  typedef enum logic [2:0] {
    FMT_R,                    
    FMT_I,
    FMT_S,
    FMT_B,
    FMT_U,
    FMT_J
  } instr_fmt_e;

  typedef enum logic [1:0] {
    ALUOP_ADD,
    ALUOP_BRANCH,
    ALUOP_FUNCT,
    ALUOP_ADD_PC
} alu_op_e;
  
  typedef enum logic [3:0] { 
    ALU_ADD,
    ALU_SUB,
    ALU_SLL,
    ALU_SLT,
    ALU_SLTU,
    ALU_XOR,
    ALU_SRL,
    ALU_SRA,
    ALU_OR,
    ALU_AND,
    ALU_PASS_B
  } alu_ctrl_e;

  typedef enum logic [1:0] {
    RESULT_ALU     = 2'b00,
    RESULT_MEM     = 2'b01,
    RESULT_PCPLUS4 = 2'b10
} result_src_e;

  typedef enum logic [1:0] {
    ALU_SRC_A_RS1,
    ALU_SRC_A_PC,
    ALU_SRC_A_ZERO
  } alu_src_a_e;

  typedef enum logic {
    ALU_SRC_B_RS2,
    ALU_SRC_B_IMM
  } alu_src_b_e;

  typedef enum logic [1:0] {
    WB_SRC_ALU,
    WB_SRC_MEM,
    WB_SRC_PC_PLUS4,
    WB_SRC_IMM
  } wb_src_e;

  typedef enum logic [1:0] {
    MEM_BYTE,
    MEM_HALF,
    MEM_WORD
  } mem_size_e;

  typedef struct packed {
    logic       reg_write;      // write result back to rd
    logic       mem_read;       // load from data memory
    logic       mem_write;      // store to data memory
    logic       mem_unsigned;   // zero- vs sign-extend loaded data
    mem_size_e  mem_size;       // byte / half / word
    logic       branch;         // is a conditional branch
    logic       jump;           // is an unconditional jump (JAL/JALR)
    alu_op_e    alu_op;
    alu_src_a_e alu_src_a;
    alu_src_b_e alu_src_b;
    wb_src_e    wb_src;
    logic       illegal_instr;  // decoder could not recognize the opcode
  } ctrl_t;

  // Instruction field extraction helpers.
  
  function automatic logic [6:0] get_opcode(input logic [ILEN-1:0] instr);
    return instr[6:0];
  endfunction

  function automatic logic [4:0] get_rd(input logic [ILEN-1:0] instr);
    return instr[11:7];
  endfunction

  function automatic logic [4:0] get_rs1(input logic [ILEN-1:0] instr);
    return instr[19:15];
  endfunction

  function automatic logic [4:0] get_rs2(input logic [ILEN-1:0] instr);
    return instr[24:20];
  endfunction

  function automatic logic [2:0] get_funct3(input logic [ILEN-1:0] instr);
    return instr[14:12];
  endfunction

  function automatic logic [6:0] get_funct7(input logic [ILEN-1:0] instr);
    return instr[31:25];
  endfunction


  // Immediate generator - sign/zero extends the correct bit field for the given instruction format.

  function automatic logic [XLEN-1:0] get_imm (
    input logic [ILEN-1:0]  instr,
    input instr_fmt_e       fmt
  );
    
    logic [XLEN-1:0] imm;
    unique case (fmt)
      FMT_I:   imm = {{21{instr[31]}}, instr[30:20]};
      FMT_S:   imm = {{21{instr[31]}}, instr[30:25], instr[11:7]};
      FMT_B:   imm = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0};
      FMT_U:   imm = {instr[31:12], 12'b0};
      FMT_J:   imm = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21], 1'b0};
      default: imm = '0;   // FMT_R has no immediate
    endcase
    return imm;
  endfunction

  function automatic instr_fmt_e get_fmt(input logic [6:0] opcode);
    unique case (opcode)
      OP_ARTH_REG:        get_fmt = FMT_R;
      OP_ARTH_IMM,
      OP_LOAD,
      OP_JALR,
      OP_SYSTEM,
      OP_FENCE:            get_fmt = FMT_I;
      OP_STORE:            get_fmt = FMT_S;
      OP_BRANCH:           get_fmt = FMT_B;
      OP_LUI,
      OP_AUIPC:            get_fmt = FMT_U;
      OP_JAL:              get_fmt = FMT_J;
      default:             get_fmt = FMT_I;
    endcase
  endfunction

endpackage : riscv_pkg
