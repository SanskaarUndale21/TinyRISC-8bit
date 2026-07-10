/*
 * register_file.v - TinyRISC-8 general-purpose register file
 *
 * 4 x 8-bit registers (R0-R3). Two combinational read ports (src/dst as
 * decoded from the instruction) plus one extra combinational debug read
 * port used only for external observability via ui_in (see
 * tt_um_tinyrisc8.v). One synchronous write port, active on the WRITEBACK
 * cycle when write_en is asserted by the control FSM.
 */

`default_nettype none

module register_file (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       write_en,
    input  wire [1:0] src_sel,     // Rs field of the instruction
    input  wire [1:0] dst_sel,     // Rd field of the instruction
    input  wire [1:0] debug_sel,   // external debug read select
    input  wire [7:0] write_data,
    output wire [7:0] src_data,    // R[src_sel]
    output wire [7:0] dst_data,    // R[dst_sel]
    output wire [7:0] debug_data   // R[debug_sel]
);

  reg [7:0] regs [0:3];

  assign src_data   = regs[src_sel];
  assign dst_data   = regs[dst_sel];
  assign debug_data = regs[debug_sel];

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      regs[0] <= 8'd0;
      regs[1] <= 8'd0;
      regs[2] <= 8'd0;
      regs[3] <= 8'd0;
    end else if (write_en) begin
      regs[dst_sel] <= write_data;
    end
  end

endmodule
