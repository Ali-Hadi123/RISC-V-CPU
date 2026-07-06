import riscv_pkg::*;

module pc (
    input clk,
    input rst,
    input logic [XLEN-1:0] next_pc,
    output logic [XLEN-1:0] pc
);

always_ff @(posedge clk or posedge rst)
    if (rst)
        pc <= 0;    //Forces the program counter to 0 in the event of a reset signal.
    else
        pc <= next_pc; //Sets the program counter to next_pc in response to the clock's rising edge.
        
endmodule
