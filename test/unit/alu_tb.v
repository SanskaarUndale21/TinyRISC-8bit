/*
 * alu_tb.v - standalone unit test for src/rtl/alu.v
 *
 * Exhaustively exercises every opcode plus the boundary cases that matter
 * for an 8-bit ALU: zero, sign-bit carry/borrow, and signed overflow at
 * both wrap-around edges (0x7F/0x80). Independent of the CPU/ROM/RAM -
 * pure combinational checks against hand-computed expected values.
 *
 * Run with: bash test/unit/run.sh (or see that script for the raw
 * iverilog/vvp invocation).
 */
`timescale 1ns/1ps
module alu_tb;
  reg [3:0] alu_op;
  reg [7:0] a, b;
  wire [7:0] result;
  wire carry_out, zero_out, negative_out, overflow_out;
  integer errors;

  alu dut (
    .alu_op(alu_op), .operand_a(a), .operand_b(b),
    .result(result), .carry_out(carry_out), .zero_out(zero_out),
    .negative_out(negative_out), .overflow_out(overflow_out)
  );

  task check;
    input [3:0] op;
    input [7:0] va, vb;
    input [7:0] exp_result;
    input exp_c, exp_z, exp_n, exp_v;
    begin
      alu_op = op; a = va; b = vb;
      #1;
      if (result !== exp_result || carry_out !== exp_c || zero_out !== exp_z ||
          negative_out !== exp_n || overflow_out !== exp_v) begin
        errors = errors + 1;
        $display("FAIL op=%b a=%d b=%d -> result=%d(exp %d) C=%b(exp %b) Z=%b(exp %b) N=%b(exp %b) V=%b(exp %b)",
                  op, va, vb, result, exp_result, carry_out, exp_c, zero_out, exp_z, negative_out, exp_n, overflow_out, exp_v);
      end else begin
        $display("PASS op=%b a=%d b=%d -> result=%d C=%b Z=%b N=%b V=%b", op, va, vb, result, carry_out, zero_out, negative_out, overflow_out);
      end
    end
  endtask

  initial begin
    errors = 0;

    // ADD
    check(4'b0001, 8'd5, 8'd3, 8'd8, 0,0,0,0);
    check(4'b0001, 8'd200, 8'd100, 8'd44, 1,0,0,0); // 300 mod 256 = 44, carry=1
    check(4'b0001, 8'd127, 8'd1, 8'd128, 0,0,1,1); // signed overflow
    check(4'b0001, 8'd0, 8'd0, 8'd0, 0,1,0,0);

    // SUB
    check(4'b0010, 8'd5, 8'd3, 8'd2, 0,0,0,0);
    check(4'b0010, 8'd3, 8'd5, 8'd254, 1,0,1,0); // borrow, no signed overflow
    check(4'b0010, 8'h80, 8'h01, 8'h7F, 0,0,0,1); // -128-1 signed overflow, no borrow
    check(4'b0010, 8'd10, 8'd10, 8'd0, 0,1,0,0);

    // AND/OR/XOR
    check(4'b0011, 8'hF0, 8'h3C, 8'h30, 0,0,0,0);
    check(4'b0100, 8'hF0, 8'h0F, 8'hFF, 0,0,1,0);
    check(4'b0101, 8'hFF, 8'hFF, 8'h00, 0,1,0,0);
    check(4'b0101, 8'hAA, 8'h55, 8'hFF, 0,0,1,0);

    // MOV (result = operand_b, flags computed but unused by caller)
    check(4'b0110, 8'd99, 8'd42, 8'd42, 0,0,0,0);

    // CMP (same math as SUB)
    check(4'b0111, 8'd13, 8'd3, 8'd10, 0,0,0,0);
    check(4'b0111, 8'd10, 8'd10, 8'd0, 0,1,0,0);

    // SHL
    check(4'b1000, 8'h81, 8'd0, 8'h02, 1,0,0,0); // bit7 shifted into carry
    check(4'b1000, 8'h01, 8'd0, 8'h02, 0,0,0,0);
    check(4'b1000, 8'h00, 8'd0, 8'h00, 0,1,0,0);

    // SHR
    check(4'b1001, 8'h81, 8'd0, 8'h40, 1,0,0,0); // bit0 shifted into carry
    check(4'b1001, 8'h02, 8'd0, 8'h01, 0,0,0,0);

    // INC
    check(4'b1010, 8'hFF, 8'd0, 8'h00, 1,1,0,0); // wrap, no signed overflow
    check(4'b1010, 8'h7F, 8'd0, 8'h80, 0,0,1,1); // signed overflow
    check(4'b1010, 8'd5, 8'd0, 8'd6, 0,0,0,0);

    // DEC
    check(4'b1011, 8'h00, 8'd0, 8'hFF, 1,0,1,0); // borrow, no signed overflow
    check(4'b1011, 8'h80, 8'd0, 8'h7F, 0,0,0,1); // signed overflow, no borrow
    check(4'b1011, 8'd5, 8'd0, 8'd4, 0,0,0,0);

    // NOP / JMP / JZ / LOAD / STORE -> default case, result=0
    check(4'b0000, 8'd5, 8'd3, 8'd0, 0,1,0,0);
    check(4'b1100, 8'd5, 8'd3, 8'd0, 0,1,0,0);
    check(4'b1101, 8'd5, 8'd3, 8'd0, 0,1,0,0);
    check(4'b1110, 8'd5, 8'd3, 8'd0, 0,1,0,0);
    check(4'b1111, 8'd5, 8'd3, 8'd0, 0,1,0,0);

    $display("---------------------------------------------");
    if (errors == 0)
      $display("ALL ALU TESTS PASSED");
    else
      $display("%0d ALU TESTS FAILED", errors);
    $finish;
  end
endmodule
