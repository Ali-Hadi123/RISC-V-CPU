import riscv_pkg::*;
`timescale 1ns/1ps

module imem_tb;

  int unsigned total_tests = 0;
  int unsigned passed_tests = 0;

  logic [XLEN-1:0] default_pc_addr;
  logic [XLEN-1:0] default_instr;

  imem #(                         //DUV1: IMEM when nothing is uploaded.
    .init_mem(""),
    .rom_size(1024)
  ) duv_default (
    .pc_addr(default_pc_addr),
    .instr(default_instr)
  );

  logic [XLEN-1:0] init_pc_addr;
  logic [XLEN-1:0] init_instr; 

  imem #(                         //DUV2: IMEM when memory is initialized.
    .init_mem("imem_test.hex"),
    .rom_size(16)
  ) duv_init (
    .pc_addr(default_pc_addr),
    .instr(default_instr)
  );

  task verify_init(                      //Used to test the initialized imem.
    input logic [XLEN-1:0] addr,
    input logic [XLEN-1:0] exp_instr,
    input string test_name
  );
    pc_addr_init = addr;

    #10;

    total_tests++;
 
    assert (instr_init === exp_instr) begin
      passed_tests++;
      $display("Passed: %s", test_name);
    end
    else
      $display("Failed: %s\nExpected instr = %h\nGot instr = %h", test_name, exp_instr, instr_init);
  endtask
