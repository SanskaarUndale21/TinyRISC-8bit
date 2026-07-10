/*
 * cpu_top.v - TinyRISC-8 CPU datapath and integration
 *
 * Wires together the program counter, instruction register, program ROM,
 * data RAM, register file, ALU, flags register, instruction decoder and
 * control FSM described in the other rtl/ modules.
 *
 * Datapath summary
 * -----------------
 * FETCH:
 *   program_rom[pc[5:0]] -> instruction_register (captured on ir_write)
 *
 * DECODE (combinational, from the now-stable IR):
 *   instruction_decoder splits IR into {opcode, src_sel, dst_sel} and the
 *   is_* / reg_write_en / flags_write_en control signals.
 *   register_file provides two combinational read ports:
 *     src_data = R[src_sel]   (the "Rs" operand)
 *     dst_data = R[dst_sel]   (the "Rd" operand / accumulator)
 *
 * EXECUTE (combinational):
 *   alu.operand_a = dst_data (accumulator), alu.operand_b = src_data
 *   -> result / carry / zero / negative / overflow
 *   data_ram read address is selected as:
 *     LOAD  : src_data[3:0]   (Rs holds the pointer)
 *     STORE : dst_data[3:0]   (Rd holds the pointer)
 *   -> ram_read_data (combinational)
 *   jump target (for JMP / JZ) = src_data (Rs holds the branch address)
 *
 * WRITEBACK (synchronous, gated by control_fsm's pulses):
 *   register_file.write_data = ram_read_data if LOAD, else alu_result
 *   register_file write happens when reg_write (excludes CMP/JMP/JZ/STORE/NOP)
 *   flags_register updates when flags_write (ALU ops + CMP only)
 *   data_ram write happens when ram_write (STORE only), data = src_data
 *   program_counter updates every cycle (pc_write): PC+1, or the branch
 *   target for JMP, or the branch target for JZ only if the (pre-existing)
 *   Z flag is set.
 *
 * Register-indirect addressing scheme
 * ------------------------------------
 * The 8-bit instruction format has no room for an immediate address, so
 * LOAD/STORE and JMP/JZ all take their address/target from a register's
 * current value (see program_rom.v and data_ram.v headers for the exact
 * field usage). This is a common, practical choice for tiny 8-bit
 * register-register ISAs like this one.
 */

`default_nettype none

module cpu_top (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire [1:0] debug_reg_sel,   // external debug register select

    output wire [7:0] alu_result_out,  // current ALU result (for uo_out)
    output wire [7:0] debug_reg_out,   // selected register value (for uo_out)
    output wire [7:0] pc_out,          // current PC (for uio_out)
    output wire       zero_flag_out,
    output wire       carry_flag_out,
    output wire       negative_flag_out,
    output wire       overflow_flag_out
);

  // ---------------------------------------------------------------------
  // Control FSM
  // ---------------------------------------------------------------------
  wire [1:0] state;
  wire       ir_write, reg_write, flags_write, ram_write, pc_write;

  // ---------------------------------------------------------------------
  // Program counter / instruction register / program ROM
  // ---------------------------------------------------------------------
  wire [7:0] pc_next;

  program_counter u_pc (
      .clk     (clk),
      .rst_n   (rst_n),
      .pc_write(pc_write),
      .pc_next (pc_next),
      .pc_out  (pc_out)
  );

  wire [7:0] rom_data;

  program_rom u_rom (
      .addr(pc_out[5:0]),
      .data(rom_data)
  );

  wire [7:0] ir_out;

  instruction_register u_ir (
      .clk     (clk),
      .rst_n   (rst_n),
      .ir_write(ir_write),
      .rom_data(rom_data),
      .ir_out  (ir_out)
  );

  // ---------------------------------------------------------------------
  // Instruction decoder
  // ---------------------------------------------------------------------
  wire [3:0] opcode;
  wire [1:0] src_sel, dst_sel;
  wire       is_nop, is_add, is_sub, is_and, is_or, is_xor, is_mov, is_cmp;
  wire       is_shl, is_shr, is_inc, is_dec, is_jmp, is_jz, is_load, is_store;
  wire       decoder_reg_write_en, decoder_flags_write_en;

  instruction_decoder u_decoder (
      .ir            (ir_out),
      .opcode        (opcode),
      .src_sel       (src_sel),
      .dst_sel       (dst_sel),
      .is_nop        (is_nop),
      .is_add        (is_add),
      .is_sub        (is_sub),
      .is_and        (is_and),
      .is_or         (is_or),
      .is_xor        (is_xor),
      .is_mov        (is_mov),
      .is_cmp        (is_cmp),
      .is_shl        (is_shl),
      .is_shr        (is_shr),
      .is_inc        (is_inc),
      .is_dec        (is_dec),
      .is_jmp        (is_jmp),
      .is_jz         (is_jz),
      .is_load       (is_load),
      .is_store      (is_store),
      .reg_write_en  (decoder_reg_write_en),
      .flags_write_en(decoder_flags_write_en)
  );

  control_fsm u_fsm (
      .clk                   (clk),
      .rst_n                 (rst_n),
      .ena                   (ena),
      .is_store              (is_store),
      .decoder_reg_write_en  (decoder_reg_write_en),
      .decoder_flags_write_en(decoder_flags_write_en),
      .state                 (state),
      .ir_write              (ir_write),
      .reg_write             (reg_write),
      .flags_write           (flags_write),
      .ram_write             (ram_write),
      .pc_write              (pc_write)
  );

  // ---------------------------------------------------------------------
  // Register file
  // ---------------------------------------------------------------------
  wire [7:0] src_data, dst_data, debug_reg_data;
  wire [7:0] reg_write_data;

  register_file u_regfile (
      .clk       (clk),
      .rst_n     (rst_n),
      .write_en  (reg_write),
      .src_sel   (src_sel),
      .dst_sel   (dst_sel),
      .debug_sel (debug_reg_sel),
      .write_data(reg_write_data),
      .src_data  (src_data),
      .dst_data  (dst_data),
      .debug_data(debug_reg_data)
  );

  // ---------------------------------------------------------------------
  // ALU: operand_a = accumulator/destination (Rd), operand_b = source (Rs)
  // ---------------------------------------------------------------------
  wire [7:0] alu_result;
  wire       alu_carry, alu_zero, alu_negative, alu_overflow;

  alu u_alu (
      .alu_op      (opcode),
      .operand_a   (dst_data),
      .operand_b   (src_data),
      .result      (alu_result),
      .carry_out   (alu_carry),
      .zero_out    (alu_zero),
      .negative_out(alu_negative),
      .overflow_out(alu_overflow)
  );

  // ---------------------------------------------------------------------
  // Data RAM: address comes from Rs (LOAD) or Rd (STORE); data comes from
  // Rs (STORE). See data_ram.v / program_rom.v headers for the scheme.
  // ---------------------------------------------------------------------
  wire [3:0] ram_addr   = is_store ? dst_data[3:0] : src_data[3:0];
  wire [7:0] ram_dout;

  data_ram u_ram (
      .clk       (clk),
      .rst_n     (rst_n),
      .write_en  (ram_write),
      .addr      (ram_addr),
      .write_data(src_data),
      .read_data (ram_dout)
  );

  // Register file write-back data: loaded RAM data for LOAD, ALU result
  // (including the MOV pass-through) for every other write-back instruction.
  assign reg_write_data = is_load ? ram_dout : alu_result;

  // ---------------------------------------------------------------------
  // Flags register
  // ---------------------------------------------------------------------
  wire zero_flag, carry_flag, negative_flag, overflow_flag;

  flags_register u_flags (
      .clk          (clk),
      .rst_n        (rst_n),
      .flags_write  (flags_write),
      .zero_in      (alu_zero),
      .carry_in     (alu_carry),
      .negative_in  (alu_negative),
      .overflow_in  (alu_overflow),
      .zero_flag    (zero_flag),
      .carry_flag   (carry_flag),
      .negative_flag(negative_flag),
      .overflow_flag(overflow_flag)
  );

  // ---------------------------------------------------------------------
  // Next-PC selection: JMP always branches to Rs; JZ branches to Rs only
  // if the flag register's *current* (pre-instruction) Z flag is set;
  // every other instruction just increments the PC.
  // ---------------------------------------------------------------------
  wire [7:0] pc_plus_1 = pc_out + 8'd1;

  assign pc_next = is_jmp            ? src_data :
                   (is_jz & zero_flag) ? src_data :
                   pc_plus_1;

  assign alu_result_out    = alu_result;
  assign debug_reg_out     = debug_reg_data;
  assign zero_flag_out     = zero_flag;
  assign carry_flag_out    = carry_flag;
  assign negative_flag_out = negative_flag;
  assign overflow_flag_out = overflow_flag;

  // is_nop/is_add/is_sub/is_and/is_or/is_xor/is_mov/is_cmp/is_shl/is_shr/
  // is_inc/is_dec are decoded for completeness and used by nothing here
  // (the ALU takes the raw opcode directly, and only is_store/is_load/
  // is_jmp/is_jz drive datapath muxes) - bundle them so lint doesn't flag
  // them as unused.
  wire _unused = &{is_nop, is_add, is_sub, is_and, is_or, is_xor, is_mov,
                    is_cmp, is_shl, is_shr, is_inc, is_dec, 1'b0};

endmodule
