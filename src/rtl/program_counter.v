/*
 * program_counter.v - TinyRISC-8 program counter
 *
 * 8-bit PC register. Updated once per instruction, at the WRITEBACK stage
 * (pc_write pulse from the control FSM). pc_next is computed externally in
 * cpu_top.v (sequential +1, or the jump target for JMP / taken JZ).
 */

`default_nettype none

module program_counter (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       pc_write,
    input  wire [7:0] pc_next,
    output reg  [7:0] pc_out
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      pc_out <= 8'd0;
    else if (pc_write)
      pc_out <= pc_next;
  end

endmodule
