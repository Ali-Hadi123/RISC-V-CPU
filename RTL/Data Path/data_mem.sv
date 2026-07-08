import riscv_pkg::*;

module dmem #(
  parameter int unsigned memory_space = 1024
)
(
  input clk,
  input logic [XLEN-1:0] byte_addr,
  input logic [XLEN-1:0] wdata,
  input logic mem_read,
  input logic mem_write,
  input mem_size_e mem_size,
  input logic mem_unsigned,
  output logic [XLEN-1:0] read_data
);

  logic [XLEN-1:0] ram [0:memory_space-1]; //Creates 4KB of memory when memory_space = 1024.
  
  logic [$clog2(memory_space)-1:0] windex;
  assign windex = addr[$clog2(memory_space)+1:2];
  logic [1:0] byte_off;
  assign byte_off = addr[1:0];

  //Code for writing data:

  always_ff @(posedge clk) begin
    if (mem_write) begin
      unique case(mem_size)
        MEM_BYTE: begin
          unique case(byte_off)
            2'b00: ram[windex][7:0]   <= wdata[7:0];
            2'b01: ram[windex][15:8]  <= wdata[7:0];
            2'b10: ram[windex][23:16] <= wdata[7:0];
            2'b11: ram[windex][31:24] <= wdata[7:0];
          endcase
        end

        MEM_HALF: begin
          unique case (byte_off[1])
            1'b0: ram[windex][15:0]  <= wdata[15:0];
            1'b1: ram[windex][31:16] <= wdata[15:0];
          endcase
        end

        MEM_WORD: ram[windex] <= wdata;
      endcase
    end
  end


