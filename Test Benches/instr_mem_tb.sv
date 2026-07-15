// Strategy:
//   - imem is purely combinational (no clk), so this testbench drives
//     pc_addr and checks instr after a small settle delay.
//   - Two DUT instances are used:
//       dut_default : init_mem = "" -> every word should read back as the
//                     NOP fill value (32'h0000_0013), verified across the
//                     whole (small) memory space.
//       dut_hex     : init_mem = "imem_test.hex" -> the first 16 words are
//                     preloaded with known, hard-coded values (independent
//                     of the hex file generation, so this is a genuine
//                     self-check and not just "reread the same file back").
//                     Words beyond the 16 preloaded lines must fall back to
//                     the NOP fill value, exactly like the RTL's default
//                     case if the hex file were shorter than memory_space.
//   - A byte-offset-invariance check confirms that pc_addr's lower 2 bits
//     (which are not part of the word index) don't affect which word is
//     returned, since RTL indexes with pc_addr[$clog2(memory_space)+1:2].
//   - Boundary checks cover word 0 and the last valid word
//     (memory_space-1) for both DUT instances.
//
// NOTE: imem_test.hex must be present in the simulation run directory
// (same directory this testbench is invoked from) since init_mem is a
// relative path consumed by $readmemh inside the DUT.

import riscv_pkg::*;

module imem_tb;

  localparam logic [XLEN-1:0] NOP = 32'h0000_0013;

  // ---------------- DUT 1: default fill (no hex file loaded) ----------------
  localparam int unsigned DEFAULT_SPACE = 64;

  logic [XLEN-1:0] pc_addr_default;
  logic [XLEN-1:0] instr_default;

  imem #(
    .init_mem      (""),
    .memory_space  (DEFAULT_SPACE)
  ) dut_default (
    .pc_addr (pc_addr_default),
    .instr   (instr_default)
  );

  // ---------------- DUT 2: preloaded from imem_test.hex ----------------
  localparam int unsigned HEX_SPACE   = 256;
  localparam int unsigned HEX_LINES   = 16; // number of words actually in imem_test.hex

  logic [XLEN-1:0] pc_addr_hex;
  logic [XLEN-1:0] instr_hex;

  imem #(
    .init_mem      ("imem_test.hex"),
    .memory_space  (HEX_SPACE)
  ) dut_hex (
    .pc_addr (pc_addr_hex),
    .instr   (instr_hex)
  );

  // Hard-coded expected contents of imem_test.hex, written independently of
  // the generation script so this is a genuine self-check.
  logic [XLEN-1:0] expected_hex [0:HEX_LINES-1];

  initial begin
    for (int i = 0; i < HEX_LINES; i++)
      expected_hex[i] = 32'hA5A5_0000 + i;
  end

  int unsigned test_count = 0;
  int unsigned pass_count = 0;
  int unsigned fail_count = 0;

  // ---------------- Waveform dump ----------------
  initial begin
    $dumpfile("imem_tb.vcd");
    $dumpvars(0, imem_tb);
  end

  // ---------------- Self-check task ----------------
  task automatic check(input string name, input logic [XLEN-1:0] got,
                        input logic [XLEN-1:0] exp);
    test_count++;
    if (got !== exp) begin
      fail_count++;
      $display("[FAIL] %-32s got=0x%08h (exp 0x%08h)", name, got, exp);
    end else begin
      pass_count++;
      $display("[PASS] %-32s -> 0x%08h", name, got);
    end
  endtask

  // ---------------- Test sequence ----------------
  initial begin
    pc_addr_default = '0;
    pc_addr_hex     = '0;
    #1; // allow initial expected_hex[] population + combinational settle

    $display("========================================");
    $display(" Instruction Memory (imem) Testbench Starting");
    $display("========================================");

    // ---------------- Default-fill DUT: every word should be NOP ----------------
    $display("---- Default fill (init_mem=\"\") ----");
    for (int w = 0; w < DEFAULT_SPACE; w++) begin
      pc_addr_default = w * 4;
      #1;
      check($sformatf("default NOP word_%0d", w), instr_default, NOP);
    end

    // Byte-offset invariance on the default DUT: lower 2 bits of pc_addr
    // shouldn't change which word is fetched (RTL ignores them via the
    // pc_addr[$clog2(memory_space)+1:2] slice).
    pc_addr_default = 32'h0000_0000; #1;
    check("default byte_off=0 word0", instr_default, NOP);
    pc_addr_default = 32'h0000_0001; #1;
    check("default byte_off=1 word0", instr_default, NOP);
    pc_addr_default = 32'h0000_0002; #1;
    check("default byte_off=2 word0", instr_default, NOP);
    pc_addr_default = 32'h0000_0003; #1;
    check("default byte_off=3 word0", instr_default, NOP);

    // ---------------- Hex-preloaded DUT ----------------
    $display("---- Hex preload (init_mem=\"imem_test.hex\") ----");
    for (int w = 0; w < HEX_LINES; w++) begin
      pc_addr_hex = w * 4;
      #1;
      check($sformatf("hex preload word_%0d", w), instr_hex, expected_hex[w]);
    end

    // Words beyond the 16 preloaded lines must still be NOP (pre-fill
    // default, since $readmemh only overwrote the first HEX_LINES words).
    pc_addr_hex = HEX_LINES * 4; #1;
    check("hex fallback NOP (first unwritten word)", instr_hex, NOP);

    pc_addr_hex = (HEX_LINES + 5) * 4; #1;
    check("hex fallback NOP (further unwritten word)", instr_hex, NOP);

    // Last valid word in the hex DUT's memory space (memory_space-1).
    pc_addr_hex = (HEX_SPACE - 1) * 4; #1;
    check("hex last address NOP fallback", instr_hex, NOP);

    // Byte-offset invariance on the hex DUT, using a preloaded word.
    pc_addr_hex = 32'h0000_0000; #1;
    check("hex byte_off=0 word0", instr_hex, expected_hex[0]);
    pc_addr_hex = 32'h0000_0001; #1;
    check("hex byte_off=1 word0", instr_hex, expected_hex[0]);
    pc_addr_hex = 32'h0000_0002; #1;
    check("hex byte_off=2 word0", instr_hex, expected_hex[0]);
    pc_addr_hex = 32'h0000_0003; #1;
    check("hex byte_off=3 word0", instr_hex, expected_hex[0]);

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
