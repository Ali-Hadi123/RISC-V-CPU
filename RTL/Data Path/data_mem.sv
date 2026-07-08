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

  //Code for writing data (sw, sh, sb):

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

  //Code for reading data (lw, lh, lb):
  
  logic [31:0] rword;
  logic [15:0] rhalf;
  logic [7:0] rbyte;

  always_comb begin
    word = ram[windex];
    
    unique case(byte_off)
      2'b00: rbyte = word[7:0];
      2'b01: rbyte = word[15:8];
      2'b10: rbyte = word[23:16];
      2'b11: rbyte = word[31:24];
    endcase

    unique case (byte_off[1])
      1'b0: rhalf = word[15:0];
      1'b1: rhalf = word[31:16];
    endcase

    read_data = '0;

    if (mem_read) begin
      unique case(mem_size)
        MEM_BYTE: read_data = mem_unsigned ? {24'b0, rbyte} : {{24{rbyte[7]}}, rbyte};
        MEM_HALF: read_data = mem_unsigned ? {16'b0, rhalf} : {{16{rhalf[15]}}, rhalf};
        MEM_WORD: read_data = word;
        default: read_data = '0;
      endcase
    end
  end
endmodule
