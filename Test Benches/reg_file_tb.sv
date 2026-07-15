// Strategy:
//   - A shadow model (shadow_regs[]) mirrors the DUT's register array.
//     do_write() drives we/rd/wd, lets the synchronous write land on the
//     following posedge, and updates the shadow model using the exact same
//     "ignore writes to x0" rule as the RTL.
//   - Reads (rdata1/rdata2) are purely combinational in the DUT, so
//     do_read_check() drives rs1/rs2 and self-checks both output ports
//     against the shadow model after a small settle delay, independent
//     of whatever write is happening in the same cycle.
//   - Directed tests cover: x0 always reading 0 (even after an attempted
//     write to it), we=0 blocking a write, reading rs1==rs2 from the same
//     register, back-to-back writes to every register (0..31), the
//     synchronous-write/asynchronous-read interaction (old data is visible
//     combinationally until the write's posedge lands, new data right
//     after), and write-then-immediate-read-of-same-register.
//   - A randomized mixed read/write loop follows for broader coverage.

import riscv_pkg::*;

module regf_tb;

  logic                    clk;
  logic [REG_ADDR_W-1:0]   rs1, rs2, rd;
  logic [XLEN-1:0]         wd;
  logic                    we;
  logic [XLEN-1:0]         rdata1, rdata2;

  int unsigned test_count = 0;
  int unsigned pass_count = 0;
  int unsigned fail_count = 0;

  // Shadow model: mirrors the DUT's register array (x0 is always 0).
  logic [XLEN-1:0] shadow_regs [0:REG_COUNT-1];

  regf dut (
    .clk    (clk),
    .rs1    (rs1),
    .rs2    (rs2),
    .rd     (rd),
    .wd     (wd),
    .we     (we),
    .rdata1 (rdata1),
    .rdata2 (rdata2)
  );

  // ---------------- Clock ----------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // ---------------- Waveform dump ----------------
  initial begin
    $dumpfile("regf_tb.vcd");
    $dumpvars(0, regf_tb);
  end

  initial begin
    for (int i = 0; i < REG_COUNT; i++)
      shadow_regs[i] = '0;
  end

  // ---------------- Write task (drives DUT + updates shadow model) ----------------
  task automatic do_write(input logic [REG_ADDR_W-1:0] addr, input logic [XLEN-1:0] data);
    @(negedge clk);
    rd = addr;
    wd = data;
    we = 1'b1;

    @(posedge clk); // Synchronous write is sampled here, same as the DUT.
    #1;             // Let the nonblocking assignment inside the DUT settle.

    if (addr != '0)
      shadow_regs[addr] = data;
    // Writes to x0 are ignored, matching "if (we && rd != 0)" in the RTL.

    @(negedge clk);
    we = 1'b0;
  endtask

  // ---------------- Read + self-check task ----------------
  task automatic do_read_check(input string name, input logic [REG_ADDR_W-1:0] a1,
                                input logic [REG_ADDR_W-1:0] a2);
    logic [XLEN-1:0] exp1, exp2;

    exp1 = (a1 == '0) ? '0 : shadow_regs[a1];
    exp2 = (a2 == '0) ? '0 : shadow_regs[a2];

    rs1 = a1;
    rs2 = a2;
    #1; // Let combinational read logic settle.

    test_count++;
    if (rdata1 !== exp1 || rdata2 !== exp2) begin
      fail_count++;
      $display("[FAIL] %-32s rs1=%0d rs2=%0d | rdata1=0x%08h(exp 0x%08h) rdata2=0x%08h(exp 0x%08h)",
                name, a1, a2, rdata1, exp1, rdata2, exp2);
    end else begin
      pass_count++;
      $display("[PASS] %-32s rs1=%0d rs2=%0d -> rdata1=0x%08h rdata2=0x%08h",
                name, a1, a2, rdata1, rdata2);
    end
  endtask

  // ---------------- Test sequence ----------------
  initial begin
    rs1 = '0; rs2 = '0; rd = '0; wd = '0; we = 1'b0;

    $display("========================================");
    $display(" Register File (regf) Testbench Starting");
    $display("========================================");

    // ---------------- x0 hardwired-zero checks ----------------
    do_read_check("x0 reads 0 before any writes", 5'd0, 5'd0);

    // Attempt to write x0 -- should have no effect.
    do_write(5'd0, 32'hFFFF_FFFF);
    do_read_check("x0 still 0 after attempted write", 5'd0, 5'd0);

    // ---------------- Basic write/read on a normal register ----------------
    do_write(5'd5, 32'hDEAD_BEEF);
    do_read_check("x5 readback", 5'd5, 5'd0);

    // ---------------- we=0 should block a write ----------------
    @(negedge clk);
    rd = 5'd5;
    wd = 32'h0000_0000;
    we = 1'b0; // write disabled
    @(posedge clk);
    #1;
    @(negedge clk);
    do_read_check("x5 unchanged when we=0", 5'd5, 5'd0);

    // ---------------- rs1 == rs2 reading the same register ----------------
    do_write(5'd10, 32'h1234_5678);
    do_read_check("rs1==rs2 same register", 5'd10, 5'd10);

    // ---------------- Write to every register (1..31), then verify all ----------------
    for (int i = 1; i < REG_COUNT; i++)
      do_write(i[REG_ADDR_W-1:0], 32'hA000_0000 + i);

    for (int i = 0; i < REG_COUNT; i++)
      do_read_check($sformatf("full sweep x%0d", i), i[REG_ADDR_W-1:0], 5'd0);

    // ---------------- Synchronous-write / asynchronous-read interaction ----------------
    // Old data must still be visible right up until the write's posedge lands;
    // new data must be visible immediately after (combinational read).
    do_write(5'd7, 32'h1111_1111);
    do_read_check("x7 before overwrite", 5'd7, 5'd0);

    @(negedge clk);
    rd = 5'd7;
    wd = 32'h2222_2222;
    we = 1'b1;
    rs1 = 5'd7;
    #1;
    test_count++;
    if (rdata1 !== 32'h1111_1111) begin
      fail_count++;
      $display("[FAIL] %-32s rdata1=0x%08h (exp 0x11111111, old value pre-edge)",
                "x7 old value just before posedge", rdata1);
    end else begin
      pass_count++;
      $display("[PASS] %-32s -> rdata1=0x%08h (old value, as expected)",
                "x7 old value just before posedge", rdata1);
    end

    @(posedge clk); // write lands here
    #1;
    shadow_regs[7] = 32'h2222_2222;
    test_count++;
    if (rdata1 !== 32'h2222_2222) begin
      fail_count++;
      $display("[FAIL] %-32s rdata1=0x%08h (exp 0x22222222, new value post-edge)",
                "x7 new value just after posedge", rdata1);
    end else begin
      pass_count++;
      $display("[PASS] %-32s -> rdata1=0x%08h (new value, as expected)",
                "x7 new value just after posedge", rdata1);
    end

    @(negedge clk);
    we = 1'b0;

    // ---------------- Randomized mixed read/write testing ----------------
    $display("----------------------------------------");
    $display(" Beginning randomized testing (300 ops)");
    $display("----------------------------------------");

    for (int i = 0; i < 300; i++) begin
      logic [REG_ADDR_W-1:0] rand_rd, rand_rs1, rand_rs2;
      logic [XLEN-1:0]       rand_wd;
      int                    op_pick;

      rand_rd  = $urandom_range(0, REG_COUNT-1);
      rand_rs1 = $urandom_range(0, REG_COUNT-1);
      rand_rs2 = $urandom_range(0, REG_COUNT-1);
      rand_wd  = $urandom();
      op_pick  = $urandom_range(0, 1);

      if (op_pick == 0)
        do_write(rand_rd, rand_wd);
      else
        do_read_check($sformatf("random_%0d", i), rand_rs1, rand_rs2);
    end

    // Final sanity sweep after the randomized mix.
    for (int i = 0; i < REG_COUNT; i++)
      do_read_check($sformatf("post-random sweep x%0d", i), i[REG_ADDR_W-1:0], 5'd0);

    // ---------------- Summary ----------------
    $display("========================================");
    $display(" Test Summary: %0d run, %0d passed, %0d failed",
              test_count, pass_count, fail_count);
    if (fail_count == 0)
      $display(" RESULT: ALL TESTS PASSED");
    else
      $display(" RESULT: %0d TEST(S) FAILED", fail_count);
    $display("========================================");

    $finish;
  end
endmodule
