module imem #(
  parameter init_mem = ""
)
(
  input [31:0] pc_addr,
  output [31:0] instr
);

  logic [31:0] rom [0:1023]; //4KB memory space.
  initial $readmemh(init_mem, rom);
