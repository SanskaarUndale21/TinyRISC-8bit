/*
 * opcode_coverage_tb.v - supplementary local-only opcode coverage check
 *
 * The main testbench (test/test.py) exercises the shipped demo program,
 * which only ever runs XOR, LOAD, INC, MOV, ADD, CMP, SUB and JZ. This
 * plain-Verilog testbench links the real RTL against a *different* scratch
 * ROM (opcode_coverage_rom.v) that exercises the remaining opcodes -
 * AND, OR, SHL, SHR, DEC, JMP, STORE, NOP - so all 16 instructions have
 * been run against real hardware behavior at least once, not just the
 * ALU in isolation (see alu_tb.v for that).
 *
 * This is deliberately NOT wired into test/Makefile / the TinyTapeout
 * cocotb flow: the official gl_test CI job re-simulates the *actual*
 * hardened netlist against the *actual* shipped program_rom.v contents,
 * and swapping in a different ROM here would defeat that check. Run this
 * manually with `bash test/unit/run.sh` (RTL-only, iverilog).
 *
 * Register values are read the same way the real chip is meant to be
 * debugged: through ui_in[7]=1 + ui_in[1:0]=register index -> uo_out,
 * never by peeking internal hierarchy, so this stays representative of
 * what's actually observable on the TinyTapeout pins.
 */

`timescale 1ns/1ps

module opcode_coverage_tb;

  reg clk = 0;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

  always #5 clk = ~clk;

  tt_um_sanskaarundale21_tinyrisc8 dut (
      .ui_in  (ui_in),
      .uo_out (uo_out),
      .uio_in (uio_in),
      .uio_out(uio_out),
      .uio_oe (uio_oe),
      .ena    (ena),
      .clk    (clk),
      .rst_n  (rst_n)
  );

  integer errors = 0;

  // Read register R<idx> through the debug-readback mux (ui_in[7]=1,
  // ui_in[1:0]=idx -> uo_out), exactly as described in project.v.
  task check_reg;
    input [1:0] idx;
    input [7:0] expected;
    reg   [7:0] got;
    begin
      ui_in = {1'b1, 5'b0, idx};
      #1;
      got = uo_out;
      if (got !== expected) begin
        errors = errors + 1;
        $display("FAIL R%0d: got=%0d expected=%0d", idx, got, expected);
      end else begin
        $display("PASS R%0d = %0d", idx, got);
      end
      ui_in = 8'd0;
    end
  endtask

  // Advance exactly one instruction (FETCH, DECODE, EXECUTE, WRITEBACK).
  task step;
    begin
      repeat (4) @(posedge clk);
      #0;
    end
  endtask

  initial begin
    ena = 1;
    ui_in = 0;
    uio_in = 0;
    rst_n = 0;
    repeat (5) @(posedge clk);
    #2;
    rst_n = 1;
    #2;
    @(posedge clk);

    step(); $display("-- 0: LOAD R0,[R0] --"); check_reg(0, 10);
    step(); $display("-- 1: XOR R1,R1 --");    check_reg(1, 0);
    step(); $display("-- 2: INC R1 --");       check_reg(1, 1);
    step(); $display("-- 3: LOAD R1,[R1] --");  check_reg(1, 3);
    step(); $display("-- 4: AND R0,R1 --");    check_reg(0, 2);
    step(); $display("-- 5: STORE R1,[R0] --"); // read back via instr 9's LOAD
    step(); $display("-- 6: XOR R2,R2 --");     check_reg(2, 0);
    step(); $display("-- 7: INC R2 --");        check_reg(2, 1);
    step(); $display("-- 8: INC R2 --");        check_reg(2, 2);
    step(); $display("-- 9: LOAD R3,[R2] (reads back the STORE) --"); check_reg(3, 3);
    step(); $display("-- 10: OR R0,R3 --");     check_reg(0, 3);
    step(); $display("-- 11: SHL R0 --");       check_reg(0, 6);
    step(); $display("-- 12: SHR R0 --");       check_reg(0, 3);
    step(); $display("-- 13: DEC R0 --");       check_reg(0, 2);
    step(); $display("-- 14: NOP (no state change expected) --"); check_reg(0, 2);

    // 15: JMP R2 (R2=2) - PC should jump back to address 2, not fall
    // through to 16.
    step();
    $display("-- 15: JMP R2 -> PC should be 2, uio_out[3:0]=%0d --", uio_out[3:0]);
    if (uio_out[3:0] !== 4'd2) begin
      errors = errors + 1;
      $display("FAIL JMP: PC low nibble = %0d, expected 2", uio_out[3:0]);
    end else begin
      $display("PASS JMP: PC correctly jumped to 2");
    end

    $display("---------------------------------------------");
    if (errors == 0)
      $display("ALL OPCODE COVERAGE TESTS PASSED");
    else
      $display("%0d OPCODE COVERAGE TESTS FAILED", errors);
    $finish;
  end

endmodule
