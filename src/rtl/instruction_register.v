/*
 * instruction_register.v - TinyRISC-8 instruction register (IR)
 *
 * Captures the ROM output word at the end of the FETCH state (ir_write
 * pulsed while state == FETCH) and holds it stable through DECODE, EXECUTE
 * and WRITEBACK.
 */

`default_nettype none

module instruction_register (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ir_write,
    input  wire [7:0] rom_data,
    output reg  [7:0] ir_out
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      ir_out <= 8'd0;  // NOP
    else if (ir_write)
      ir_out <= rom_data;
  end

endmodule
