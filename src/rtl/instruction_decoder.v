/*
 * instruction_decoder.v - TinyRISC-8 instruction decoder
 *
 * Purely combinational. Splits the instruction register into its opcode
 * and register fields and derives the per-instruction control signals
 * consumed by the control FSM and datapath muxes in cpu_top.v.
 */

`default_nettype none

module instruction_decoder (
    input  wire [7:0] ir,
    output wire [3:0] opcode,
    output wire [1:0] src_sel,
    output wire [1:0] dst_sel,

    output wire is_nop,
    output wire is_add,
    output wire is_sub,
    output wire is_and,
    output wire is_or,
    output wire is_xor,
    output wire is_mov,
    output wire is_cmp,
    output wire is_shl,
    output wire is_shr,
    output wire is_inc,
    output wire is_dec,
    output wire is_jmp,
    output wire is_jz,
    output wire is_load,
    output wire is_store,

    output wire reg_write_en,    // write back result into R[dst_sel]
    output wire flags_write_en   // update the flags register
);

  // Opcode encodings (must match alu.v / program_rom.v).
  localparam OP_NOP   = 4'b0000;
  localparam OP_ADD   = 4'b0001;
  localparam OP_SUB   = 4'b0010;
  localparam OP_AND   = 4'b0011;
  localparam OP_OR    = 4'b0100;
  localparam OP_XOR   = 4'b0101;
  localparam OP_MOV   = 4'b0110;
  localparam OP_CMP   = 4'b0111;
  localparam OP_SHL   = 4'b1000;
  localparam OP_SHR   = 4'b1001;
  localparam OP_INC   = 4'b1010;
  localparam OP_DEC   = 4'b1011;
  localparam OP_JMP   = 4'b1100;
  localparam OP_JZ    = 4'b1101;
  localparam OP_LOAD  = 4'b1110;
  localparam OP_STORE = 4'b1111;

  assign opcode  = ir[7:4];
  assign src_sel = ir[3:2];
  assign dst_sel = ir[1:0];

  assign is_nop   = (opcode == OP_NOP);
  assign is_add   = (opcode == OP_ADD);
  assign is_sub   = (opcode == OP_SUB);
  assign is_and   = (opcode == OP_AND);
  assign is_or    = (opcode == OP_OR);
  assign is_xor   = (opcode == OP_XOR);
  assign is_mov   = (opcode == OP_MOV);
  assign is_cmp   = (opcode == OP_CMP);
  assign is_shl   = (opcode == OP_SHL);
  assign is_shr   = (opcode == OP_SHR);
  assign is_inc   = (opcode == OP_INC);
  assign is_dec   = (opcode == OP_DEC);
  assign is_jmp   = (opcode == OP_JMP);
  assign is_jz    = (opcode == OP_JZ);
  assign is_load  = (opcode == OP_LOAD);
  assign is_store = (opcode == OP_STORE);

  // Every instruction that produces a register-file result except CMP
  // (compare only updates flags) writes back on this instruction's
  // WRITEBACK cycle.
  assign reg_write_en = is_add | is_sub | is_and | is_or | is_xor | is_mov |
                        is_shl | is_shr | is_inc | is_dec | is_load;

  // Only genuine ALU arithmetic/logic/compare operations touch the flags.
  assign flags_write_en = is_add | is_sub | is_and | is_or | is_xor |
                           is_shl | is_shr | is_inc | is_dec | is_cmp;

endmodule
