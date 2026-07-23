import riscv_pkg::*;
`timescale 1ns/1ps

module regf_tb;
  logic clk;
  logic [REG_ADDR_W-1:0] tb_rs1, tb_rs2, tb_rd;
  logic [XLEN-1:0] tb_wd;
  logic reg_write;
  logic [XLEN-1:0] tb_rdata1, tb_rdata2;

  int unsigned total_tests = 0;
  int unsigned passed_tests = 0;

  regf duv(
    .clk(clk),
    .rs1(tb_rs1),
    .rs2(tb_rs2),
    .rd(tb_rd),
    .wd(tb_wd),
    .reg_write(reg_write),
    .rdata1(tb_rdata1),
    .rdata2(tb_rdata2)
  );

  always #5 clk = ~clk;

  //Concurrent assert statements for testing (these tests are constantly being ran):
  
always @(posedge clk) begin
    if (tb_rs1 == 5'd0) begin
        assert (tb_rdata1 == 32'd0)
        else
            $error("x0 is not zero!");
    end
end

  task write_reg(
    input [REG_ADDR_W-1:0] rn,
    input [XLEN-1:0] data
  );
    @(negedge clk);
    reg_write = 1'b1;
    tb_rd = rn;
    tb_wd = data;
    
    @(negedge clk);
    reg_write = 1'b0;
  endtask

  task read_reg(input [REG_ADDR_W-1:0] rn);
    @(negedge clk);
    tb_rs1 = rn;
  endtask

  initial begin
    $dumpfile("reg_file_tb.vcd");
    $dumpvars(0, regf_tb);
    
    clk = 0;
    reg_write = 0;
    tb_rs1 = 0;
    tb_rs2 = 0;
    tb_rd = 0;
    tb_wd = 0;

    $display("STARTING REGISTER FILE TESTING:");

    write_reg(5'd5, 32'd123);              //Testing writing a value to x5 and then reading it.
    read_reg(5'd5);
    total_tests++;

    #10;
    
    assert (tb_rdata1 == 32'd123) begin
      passed_tests++;
      $display("Passed Test 1");
    end
    else
      $error("Failed Test 1\nExpected: 32'd123\nGot: %0d", tb_rdata1);

    write_reg(5'd8, 32'd456);       //Testing that different registers can be written to w/o overwriting data.
    read_reg(5'd5);
    total_tests++;

    #10;
    
    assert (tb_rdata1 == 32'd123) begin
      passed_tests++;
      $display("Passed Test 1");
    end
    else
      $error("Failed Test 1\nExpected: 32'd123\nGot: %0d", tb_rdata1);

    read_reg(5'd8);                    //Testing reading from a different register.
    total_tests++;

    #10;
    
    assert (tb_rdata1 == 32'd456) begin
      passed_tests++;
      $display("Passed Test 1");
    end
    else
      $error("Failed Test 1\nExpected: 32'd123\nGot: %0d", tb_rdata1);

    write_reg(5'd0, 32'hFFFF_FFFF);      //Testing that x0 can't be overwritten.
    read_reg(5'd0);
    total_tests++;

    #10;
    
    assert (tb_rdata1 == 32'd0) begin
      passed_tests++;
      $display("Passed Test 4");
    end
    else
      $error("Failed Test 4\nExpected: 32'd0\nGot: %0d", tb_rdata1);

    //Summary
    $display("REGFILE TESTING COMPLETE!");
    $display("Results: %0d/%0d tests passed.", passed_tests, total_tests);
    $finish;
  end
endmodule
