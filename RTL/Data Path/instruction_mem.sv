module imem #(
  parameter init_mem = ""
)
(
  input [31:0] pc_addr,
  output [31:0] instr
);

  logic [31:0] rom [0:1023]; //Creates a 4KB memory space.
  integer i;
  
  initial begin
    for (i=0; i<1024; i++)
      rom[i] = 32'h0000_0013; //Preemptively fills rom with NOP instructions in case of a hex file less than 1024 words.
    if (init_mem != "")
      $readmemh(init_mem, rom); //Overwrites NOP instructions with words from the hex file.
  end
  
  assign instr = rom[pc_addr[11:2]]; //Dividing values by 4 as rom is word alligned and not byte alligned.
  
endmodule
