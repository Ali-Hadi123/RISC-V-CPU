module imem #(
  parameter init_mem = ""
)
(
  input [31:0] pc_addr,
  output [31:0] instr
);

  logic [31:0] rom [0:1023]; //4KB memory space.
  integer i;
  
  initial begin
    if (init_mem != "")
      $readmemh(init_mem, rom);
    else
      for (i=0; i<1024; i++)
        rom[i] = 32'h0000_0013; //Fills memory with NOP instructions (addi x0, x0, 0 in assembly) if no hex file is uploaded.
  end
