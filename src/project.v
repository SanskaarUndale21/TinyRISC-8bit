/*
 * Copyright (c) 2026 Sanskaar Undale
 * SPDX-License-Identifier: Apache-2.0
 *
 * project.v - TinyTapeout top level for the TinyRISC-8 CPU
 *
 * This is the TinyTapeout boundary module. It instantiates cpu_top (the
 * actual CPU, in rtl/cpu_top.v) and maps its signals onto the fixed
 * ui_in/uo_out/uio_* TinyTapeout pin interface.
 *
 * Pin mapping
 * -----------
 *   ui_in[7]   : debug mode enable. When 1, uo_out shows the selected
 *                general-purpose register instead of the live ALU result.
 *   ui_in[1:0] : debug register select (00=R0, 01=R1, 10=R2, 11=R3),
 *                used only when ui_in[7] = 1.
 *   ui_in[6:2] : unused, reserved for future expansion.
 *
 *   uo_out[7:0]: current ALU result (default), or the selected register's
 *                value in debug mode - see ui_in[7] above.
 *
 *   uio_out[3:0]: current PC, low 4 bits.
 *   uio_out[7:4]: condition flags, packed as {V, N, C, Z} (bit 7 = V,
 *                 bit 6 = N, bit 5 = C, bit 4 = Z).
 *   uio_oe      : 8'hFF - all uio pins driven as outputs.
 *   uio_in      : reserved, not used by this design.
 */

`default_nettype none

module tt_um_sanskaarundale21_tinyrisc8 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);

  wire [7:0] alu_result;
  wire [7:0] debug_reg_value;
  wire [7:0] pc_value;
  wire       zero_flag, carry_flag, negative_flag, overflow_flag;

  cpu_top cpu (
      .clk              (clk),
      .rst_n            (rst_n),
      .ena              (ena),
      .debug_reg_sel    (ui_in[1:0]),
      .alu_result_out   (alu_result),
      .debug_reg_out    (debug_reg_value),
      .pc_out           (pc_value),
      .zero_flag_out    (zero_flag),
      .carry_flag_out   (carry_flag),
      .negative_flag_out(negative_flag),
      .overflow_flag_out(overflow_flag)
  );

  assign uo_out = ui_in[7] ? debug_reg_value : alu_result;

  assign uio_out = {overflow_flag, negative_flag, carry_flag, zero_flag, pc_value[3:0]};
  assign uio_oe  = 8'hFF;

  // uio_in and ui_in[6:2] are reserved/unused in this design.
  wire _unused = &{uio_in, ui_in[6:2], 1'b0};

endmodule
