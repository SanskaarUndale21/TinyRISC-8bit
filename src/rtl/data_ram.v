/*
 * data_ram.v - TinyRISC-8 data RAM (16 x 8)
 *
 * Synchronous write, combinational read, as required for the LOAD/STORE
 * instructions. Addressing scheme (see cpu_top.v):
 *   - LOAD  Rd,[Rs] : address = R[Rs][3:0] (low 4 bits of the source
 *                     register), data written into Rd.
 *   - STORE Rs,[Rd] : address = R[Rd][3:0] (low 4 bits of the destination
 *                     register), data taken from Rs.
 * Only 4 address bits are needed since the RAM has 16 entries; the upper
 * 4 bits of the pointer register are ignored.
 *
 * Preload: RAM[0] = 10, RAM[1] = 3 (all other locations reset to 0). These
 * two values seed the demonstration program in program_rom.v, since the
 * instruction set has no immediate/constant-load instruction - LOAD from a
 * known RAM location is the only way to get a non-zero value into a
 * register after reset.
 */

`default_nettype none

module data_ram (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       write_en,
    input  wire [3:0] addr,
    input  wire [7:0] write_data,
    output wire [7:0] read_data
);

  reg [7:0] mem [0:15];

  assign read_data = mem[addr];

  integer i;
  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      mem[0] <= 8'd10;
      mem[1] <= 8'd3;
      for (i = 2; i < 16; i = i + 1)
        mem[i] <= 8'd0;
    end else if (write_en) begin
      mem[addr] <= write_data;
    end
  end

endmodule
