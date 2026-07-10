/*
 * alu.v - TinyRISC-8 Arithmetic Logic Unit
 *
 * Combinational 8-bit ALU. operand_a is the accumulator/destination-register
 * value, operand_b is the source-register value (see cpu_top.v for the
 * register/instruction convention). For single-operand ops (INC/DEC/SHL/SHR)
 * operand_b is ignored.
 *
 * Flag conventions:
 *   - carry_out   : for ADD/INC, the arithmetic carry-out of bit 7.
 *                   for SUB/DEC/CMP, the *borrow* flag (1 = borrow occurred,
 *                   i.e. operand_a < operand_b).
 *   - zero_out    : result == 0
 *   - negative_out: result[7]
 *   - overflow_out: signed two's-complement overflow of the operation
 */

`default_nettype none

module alu (
    input  wire [3:0] alu_op,
    input  wire [7:0] operand_a,   // destination / accumulator operand (Rd)
    input  wire [7:0] operand_b,   // source operand (Rs)
    output reg  [7:0] result,
    output reg        carry_out,
    output wire       zero_out,
    output wire        negative_out,
    output reg        overflow_out
);

  // Opcode encodings (must match instruction_decoder.v / program_rom.v).
  localparam OP_ADD = 4'b0001;
  localparam OP_SUB = 4'b0010;
  localparam OP_AND = 4'b0011;
  localparam OP_OR  = 4'b0100;
  localparam OP_XOR = 4'b0101;
  localparam OP_MOV = 4'b0110;
  localparam OP_CMP = 4'b0111;
  localparam OP_SHL = 4'b1000;
  localparam OP_SHR = 4'b1001;
  localparam OP_INC = 4'b1010;
  localparam OP_DEC = 4'b1011;

  // 9-bit intermediates used to extract carry/borrow cleanly.
  reg [8:0] add_ext;
  reg [8:0] sub_ext;

  always @(*) begin
    // Defaults prevent unintended latches.
    result       = 8'd0;
    carry_out    = 1'b0;
    overflow_out = 1'b0;
    add_ext      = 9'd0;
    sub_ext      = 9'd0;

    case (alu_op)
      OP_ADD: begin
        add_ext      = {1'b0, operand_a} + {1'b0, operand_b};
        result       = add_ext[7:0];
        carry_out    = add_ext[8];
        overflow_out = (~(operand_a[7] ^ operand_b[7])) & (operand_a[7] ^ result[7]);
      end

      OP_SUB, OP_CMP: begin
        // CMP performs the same subtraction as SUB but the caller (control
        // FSM / decoder) suppresses the register write-back for CMP.
        sub_ext      = {1'b0, operand_a} - {1'b0, operand_b};
        result       = sub_ext[7:0];
        carry_out    = sub_ext[8];  // borrow flag: 1 if operand_a < operand_b
        overflow_out = (operand_a[7] ^ operand_b[7]) & (operand_a[7] ^ result[7]);
      end

      OP_AND: begin
        result = operand_a & operand_b;
      end

      OP_OR: begin
        result = operand_a | operand_b;
      end

      OP_XOR: begin
        result = operand_a ^ operand_b;
      end

      OP_MOV: begin
        // Rd <= Rs : pass the source operand straight through.
        result = operand_b;
      end

      OP_SHL: begin
        result    = {operand_a[6:0], 1'b0};
        carry_out = operand_a[7];  // bit shifted out
      end

      OP_SHR: begin
        result    = {1'b0, operand_a[7:1]};
        carry_out = operand_a[0];  // bit shifted out
      end

      OP_INC: begin
        add_ext      = {1'b0, operand_a} + 9'd1;
        result       = add_ext[7:0];
        carry_out    = add_ext[8];
        overflow_out = (~operand_a[7]) & result[7];
      end

      OP_DEC: begin
        sub_ext      = {1'b0, operand_a} - 9'd1;
        result       = sub_ext[7:0];
        carry_out    = sub_ext[8];
        overflow_out = operand_a[7] & (~result[7]);
      end

      default: begin
        // NOP, JMP, JZ, LOAD, STORE do not use the ALU result.
        result = 8'd0;
      end
    endcase
  end

  assign zero_out     = (result == 8'd0);
  assign negative_out = result[7];

endmodule
