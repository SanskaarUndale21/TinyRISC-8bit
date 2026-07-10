/*
 * flags_register.v - TinyRISC-8 condition flags (Z, C, N, V)
 *
 * Updated on the WRITEBACK cycle of ALU-class instructions (ADD, SUB, AND,
 * OR, XOR, SHL, SHR, INC, DEC, CMP), gated by flags_write from the control
 * FSM / instruction decoder. MOV, JMP, JZ, LOAD, STORE and NOP leave the
 * flags unchanged.
 */

`default_nettype none

module flags_register (
    input  wire clk,
    input  wire rst_n,
    input  wire flags_write,
    input  wire zero_in,
    input  wire carry_in,
    input  wire negative_in,
    input  wire overflow_in,
    output reg  zero_flag,
    output reg  carry_flag,
    output reg  negative_flag,
    output reg  overflow_flag
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      zero_flag     <= 1'b0;
      carry_flag    <= 1'b0;
      negative_flag <= 1'b0;
      overflow_flag <= 1'b0;
    end else if (flags_write) begin
      zero_flag     <= zero_in;
      carry_flag    <= carry_in;
      negative_flag <= negative_in;
      overflow_flag <= overflow_in;
    end
  end

endmodule
