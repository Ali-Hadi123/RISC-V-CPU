// Self-checking testbench for the data memory
//
// Strategy:
//   - A shadow memory array (word-addressable, same size as the DUT's ram)
//     is maintained entirely in the testbench. do_write() updates the
//     shadow model using the exact same byte/half/word-enable logic as the
//     RTL, and do_read_check() computes the expected read_data from the
//     shadow model (including sign/zero extension) and self-checks it
//     against the DUT on every call.
//   - Writes are synchronous (posedge clk), so do_write() drives inputs on
//     a negedge and lets the write land on the following posedge, mirroring
//     how the DUT actually samples wdata/byte_addr/mem_size.
//   - Reads are combinational in the DUT, so do_read_check() only needs a
//     small settle delay after driving the read-side inputs.
//   - Directed tests hit each mem_size, every byte_off / half offset,
//     sign-extension and zero-extension corner cases, adjacent-byte
//     non-corruption, mem_read de-asserted (read_data forced to 0), and
//     first/last memory locations. A randomized mixed read/write loop
//     follows for broader coverage.
//   - $dumpfile/$dumpvars are set up so the waveform can be opened

import riscv_pkg::*;

module dmem_tb;

  localparam int unsigned MEM_SPACE = 1024;
  localparam int WIDX_W = $clog2(MEM_SPACE);

  logic             clk;
  logic [XLEN-1:0]  byte_addr;
  logic [XLEN-1:0]  wdata;
  logic             mem_read;
  logic             mem_write;
  mem_size_e        mem_size;
  logic             mem_unsigned;
  logic [XLEN-1:0]  read_data;

  int unsigned test_count = 0;
  int unsigned pass_count = 0;
  int unsigned fail_count = 0;

  // Shadow model: mirrors the DUT's word-addressable ram exactly.
  logic [XLEN-1:0] shadow [0:MEM_SPACE-1];

  dmem #(.memory_space(MEM_SPACE)) dut (
    .clk          (clk),
    .byte_addr    (byte_addr),
    .wdata        (wdata),
    .mem_read     (mem_read),
    .mem_write    (mem_write),
    .mem_size     (mem_size),
    .mem_unsigned (mem_unsigned),
    .read_data    (read_data)
  );

  // ---------------- Clock ----------------
  initial clk = 1'b0;
  always #5 clk = ~clk;

  // ---------------- Waveform dump ----------------
  initial begin
    $dumpfile("dmem_tb.vcd");
    $dumpvars(0, dmem_tb);
  end

  // ---------------- Helpers to compute windex / byte_off ----------------
  function automatic logic [WIDX_W-1:0] get_windex(input logic [XLEN-1:0] addr);
    return addr[WIDX_W+1:2];
  endfunction

  function automatic logic [1:0] get_byte_off(input logic [XLEN-1:0] addr);
    return addr[1:0];
  endfunction

  // ---------------- Write task (drives DUT + updates shadow model) ----------------
  task automatic do_write(input logic [XLEN-1:0] addr, input logic [XLEN-1:0] data,
                           input mem_size_e size);
    logic [WIDX_W-1:0] windex;
    logic [1:0]        byte_off;

    windex   = get_windex(addr);
    byte_off = get_byte_off(addr);

    @(negedge clk);
    byte_addr = addr;
    wdata     = data;
    mem_size  = size;
    mem_write = 1'b1;
    mem_read  = 1'b0;

    @(posedge clk); // Synchronous write is sampled here, same as the DUT.
    #1;             // Let the nonblocking assignment inside the DUT settle.

    // Update the shadow model using the same enable logic as the RTL.
    unique case (size)
      MEM_BYTE: begin
        unique case (byte_off)
          2'b00: shadow[windex][7:0]   = data[7:0];
          2'b01: shadow[windex][15:8]  = data[7:0];
          2'b10: shadow[windex][23:16] = data[7:0];
          2'b11: shadow[windex][31:24] = data[7:0];
        endcase
      end
      MEM_HALF: begin
        unique case (byte_off[1])
          1'b0: shadow[windex][15:0]  = data[15:0];
          1'b1: shadow[windex][31:16] = data[15:0];
        endcase
      end
      MEM_WORD: shadow[windex] = data;
    endcase

    @(negedge clk);
    mem_write = 1'b0;
  endtask

  // ---------------- Read + self-check task ----------------
  task automatic do_read_check(input string name, input logic [XLEN-1:0] addr,
                                input mem_size_e size, input logic uns);
    logic [WIDX_W-1:0] windex;
    logic [1:0]        byte_off;
    logic [31:0]       rword;
    logic [15:0]        rhalf;
    logic [7:0]         rbyte;
    logic [XLEN-1:0]    exp_data;

    windex   = get_windex(addr);
    byte_off = get_byte_off(addr);
    rword    = shadow[windex];

    unique case (byte_off)
      2'b00: rbyte = rword[7:0];
      2'b01: rbyte = rword[15:8];
      2'b10: rbyte = rword[23:16];
      2'b11: rbyte = rword[31:24];
    endcase

    unique case (byte_off[1])
      1'b0: rhalf = rword[15:0];
      1'b1: rhalf = rword[31:16];
    endcase

    unique case (size)
      MEM_BYTE: exp_data = uns ? {24'b0, rbyte} : {{24{rbyte[7]}}, rbyte};
      MEM_HALF: exp_data = uns ? {16'b0, rhalf} : {{16{rhalf[15]}}, rhalf};
      MEM_WORD: exp_data = rword;
      default:  exp_data = '0;
    endcase

    @(negedge clk);
    byte_addr    = addr;
    mem_size     = size;
    mem_unsigned = uns;
    mem_read     = 1'b1;
    mem_write    = 1'b0;
    #1; // Let combinational read logic settle.

    test_count++;
    if (read_data !== exp_data) begin
      fail_count++;
      $display("[FAIL] %-32s addr=0x%08h size=%-9s uns=%0b | read_data=0x%08h (exp 0x%08h)",
                name, addr, size.name(), uns, read_data, exp_data);
    end else begin
      pass_count++;
      $display("[PASS] %-32s addr=0x%08h size=%-9s uns=%0b -> read_data=0x%08h",
                name, addr, size.name(), uns, read_data);
    end

    mem_read = 1'b0;
  endtask

  // ---------------- Check that read_data is forced to 0 when mem_read is low ----------------
  task automatic check_read_disabled(input string name, input logic [XLEN-1:0] addr);
    @(negedge clk);
    byte_addr = addr;
    mem_size  = MEM_WORD;
    mem_read  = 1'b0;
    mem_write = 1'b0;
    #1;

    test_count++;
    if (read_data !== '0) begin
      fail_count++;
      $display("[FAIL] %-32s addr=0x%08h | read_data=0x%08h (exp 0x00000000, mem_read=0)",
                name, addr, read_data);
    end else begin
      pass_count++;
      $display("[PASS] %-32s addr=0x%08h -> read_data forced to 0 as expected", name, addr);
    end
  endtask

  // ---------------- Test sequence ----------------
  initial begin
    byte_addr    = '0;
    wdata        = '0;
    mem_read     = 1'b0;
    mem_write    = 1'b0;
    mem_size     = MEM_WORD;
    mem_unsigned = 1'b0;

    $display("========================================");
    $display(" Data Memory (dmem) Testbench Starting");
    $display("========================================");

    // ---------------- Word writes/reads ----------------
    do_write(32'h0000_0000, 32'hDEAD_BEEF, MEM_WORD);
    do_read_check("WORD basic readback",        32'h0000_0000, MEM_WORD, 1'b0);

    do_write(32'h0000_0004, 32'h0000_0000, MEM_WORD);
    do_read_check("WORD zero readback",         32'h0000_0004, MEM_WORD, 1'b0);

    // Last word in the memory array (memory_space-1 = 1023 -> byte addr 4092)
    do_write(32'h0000_0FFC, 32'hCAFE_F00D, MEM_WORD);
    do_read_check("WORD last address",          32'h0000_0FFC, MEM_WORD, 1'b0);

    // ---------------- Byte writes: all 4 offsets within one word ----------------
    do_write(32'h0000_0010, 32'h0000_0011, MEM_BYTE); // byte_off 00
    do_write(32'h0000_0011, 32'h0000_0022, MEM_BYTE); // byte_off 01
    do_write(32'h0000_0012, 32'h0000_0033, MEM_BYTE); // byte_off 10
    do_write(32'h0000_0013, 32'h0000_0044, MEM_BYTE); // byte_off 11
    do_read_check("BYTE offset00 unsigned",      32'h0000_0010, MEM_BYTE, 1'b1);
    do_read_check("BYTE offset01 unsigned",      32'h0000_0011, MEM_BYTE, 1'b1);
    do_read_check("BYTE offset10 unsigned",      32'h0000_0012, MEM_BYTE, 1'b1);
    do_read_check("BYTE offset11 unsigned",      32'h0000_0013, MEM_BYTE, 1'b1);
    do_read_check("WORD after 4 byte writes",    32'h0000_0010, MEM_WORD, 1'b0); // should be 0x44332211

    // ---------------- Byte sign/zero extension corner cases ----------------
    do_write(32'h0000_0020, 32'h0000_0080, MEM_BYTE); // negative byte (0x80)
    do_read_check("BYTE 0x80 signed (negative)", 32'h0000_0020, MEM_BYTE, 1'b0);
    do_read_check("BYTE 0x80 unsigned",          32'h0000_0020, MEM_BYTE, 1'b1);

    do_write(32'h0000_0021, 32'h0000_00FF, MEM_BYTE); // 0xFF -> -1 signed, 255 unsigned
    do_read_check("BYTE 0xFF signed (negative)", 32'h0000_0021, MEM_BYTE, 1'b0);
    do_read_check("BYTE 0xFF unsigned",          32'h0000_0021, MEM_BYTE, 1'b1);

    do_write(32'h0000_0022, 32'h0000_007F, MEM_BYTE); // largest positive byte
    do_read_check("BYTE 0x7F signed (positive)", 32'h0000_0022, MEM_BYTE, 1'b0);

    // ---------------- Half writes: both offsets in a word ----------------
    do_write(32'h0000_0030, 32'h0000_1234, MEM_HALF); // byte_off[1]=0 (lower half)
    do_write(32'h0000_0032, 32'h0000_5678, MEM_HALF); // byte_off[1]=1 (upper half)
    do_read_check("HALF lower unsigned",         32'h0000_0030, MEM_HALF, 1'b1);
    do_read_check("HALF upper unsigned",         32'h0000_0032, MEM_HALF, 1'b1);
    do_read_check("WORD after 2 half writes",    32'h0000_0030, MEM_WORD, 1'b0); // 0x56781234

    // ---------------- Half sign/zero extension corner cases ----------------
    do_write(32'h0000_0040, 32'h0000_8000, MEM_HALF); // negative half
    do_read_check("HALF 0x8000 signed (negative)", 32'h0000_0040, MEM_HALF, 1'b0);
    do_read_check("HALF 0x8000 unsigned",          32'h0000_0040, MEM_HALF, 1'b1);

    do_write(32'h0000_0044, 32'h0000_7FFF, MEM_HALF); // largest positive half
    do_read_check("HALF 0x7FFF signed (positive)", 32'h0000_0044, MEM_HALF, 1'b0);

    // ---------------- Adjacent-byte non-corruption ----------------
    do_write(32'h0000_0050, 32'hFFFF_FFFF, MEM_WORD);
    do_write(32'h0000_0051, 32'h0000_0000, MEM_BYTE); // clear only byte_off 01
    do_read_check("WORD partial byte clear",     32'h0000_0050, MEM_WORD, 1'b0); // exp 0xFFFF00FF

    do_write(32'h0000_0060, 32'hFFFF_FFFF, MEM_WORD);
    do_write(32'h0000_0062, 32'h0000_0000, MEM_HALF); // clear only upper half
    do_read_check("WORD partial half clear",     32'h0000_0060, MEM_WORD, 1'b0); // exp 0x0000FFFF

    // ---------------- mem_read de-asserted forces read_data to 0 ----------------
    check_read_disabled("mem_read low -> 0",     32'h0000_0000);

    // ---------------- Randomized mixed read/write testing ----------------
    $display("----------------------------------------");
    $display(" Beginning randomized testing (300 ops)");
    $display("----------------------------------------");

    for (int i = 0; i < 300; i++) begin
      logic [WIDX_W-1:0] rand_windex;
      logic [1:0]        rand_boff;
      logic [XLEN-1:0]   rand_addr;
      logic [XLEN-1:0]   rand_data;
      mem_size_e         rand_size;
      logic              rand_uns;
      int                op_pick;

      rand_windex = $urandom_range(0, MEM_SPACE-1);
      rand_boff   = $urandom_range(0, 3);
      rand_addr   = {rand_windex, rand_boff};
      rand_data   = $urandom();
      rand_size   = mem_size_e'($urandom_range(0, 2));
      rand_uns    = $urandom_range(0, 1);
      op_pick     = $urandom_range(0, 1);

      if (op_pick == 0)
        do_write(rand_addr, rand_data, rand_size);
      else
        do_read_check($sformatf("random_%0d", i), rand_addr, rand_size, rand_uns);
    end

    // Final pass: read back every location touched in the random loop is not
    // tracked individually, but do one more full sweep of a few fixed
    // addresses through the shadow model to confirm consistency after the
    // randomized mix.
    do_read_check("post-random sanity word",     32'h0000_0000, MEM_WORD, 1'b0);
    do_read_check("post-random sanity byte",     32'h0000_0011, MEM_BYTE, 1'b1);
    do_read_check("post-random sanity half",     32'h0000_0032, MEM_HALF, 1'b1);

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
