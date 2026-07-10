/*
 * control_fsm.v - TinyRISC-8 control unit
 *
 * Classic four-state fetch/decode/execute/writeback FSM. Every instruction
 * takes exactly 4 clock cycles (uniform CPI), one per state:
 *
 *   FETCH     - address the ROM with the current PC; ir_write pulses so
 *               the instruction register captures rom_data on this cycle's
 *               clock edge.
 *   DECODE    - instruction_decoder combinationally splits the now-stable
 *               IR into opcode/register fields and control signals. No
 *               register writes happen this cycle.
 *   EXECUTE   - the ALU (and/or data RAM address) combinationally computes
 *               the result for this instruction. No register writes happen
 *               this cycle either; EXECUTE exists as its own state to keep
 *               the FETCH/DECODE/EXECUTE/WRITEBACK structure explicit and
 *               to leave a clean timing slot for the ALU's combinational
 *               path to settle before WRITEBACK samples it.
 *   WRITEBACK - reg_write/flags_write/ram_write/pc_write pulse as
 *               appropriate for the decoded instruction, committing the
 *               ALU result / loaded data / flags / RAM write / PC update.
 *
 * ena freezes the whole FSM (and therefore the whole CPU, since every
 * other module's writes are gated by FSM-driven pulses) so the design is
 * inert while TinyTapeout has not selected/powered this project.
 */

`default_nettype none

module control_fsm (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,

    input  wire       is_store,
    input  wire       decoder_reg_write_en,
    input  wire       decoder_flags_write_en,

    output reg  [1:0] state,
    output wire       ir_write,
    output wire       reg_write,
    output wire       flags_write,
    output wire       ram_write,
    output wire       pc_write
);

  localparam STATE_FETCH     = 2'b00;
  localparam STATE_DECODE    = 2'b01;
  localparam STATE_EXECUTE   = 2'b10;
  localparam STATE_WRITEBACK = 2'b11;

  reg [1:0] next_state;

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
      state <= STATE_FETCH;
    else if (ena)
      state <= next_state;
    // else: hold current state while not enabled
  end

  always @(*) begin
    case (state)
      STATE_FETCH:     next_state = STATE_DECODE;
      STATE_DECODE:    next_state = STATE_EXECUTE;
      STATE_EXECUTE:   next_state = STATE_WRITEBACK;
      STATE_WRITEBACK: next_state = STATE_FETCH;
      default:         next_state = STATE_FETCH;
    endcase
  end

  assign ir_write    = (state == STATE_FETCH);
  assign reg_write   = (state == STATE_WRITEBACK) && decoder_reg_write_en;
  assign flags_write = (state == STATE_WRITEBACK) && decoder_flags_write_en;
  assign ram_write   = (state == STATE_WRITEBACK) && is_store;
  // The PC advances or jumps exactly once per instruction, at WRITEBACK.
  assign pc_write    = (state == STATE_WRITEBACK);

endmodule
