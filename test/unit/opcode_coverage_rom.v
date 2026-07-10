// opcode_coverage_rom.v - a drop-in replacement for src/rtl/program_rom.v
// used only by test/unit/opcode_coverage_tb.v. Exercises AND, OR, SHL, SHR,
// DEC, JMP, STORE, NOP - the opcodes the shipped demo program never runs.
// Written against the real data_ram preload (RAM[0]=10, RAM[1]=3).
`default_nettype none
module program_rom (
    input  wire [5:0] addr,
    output reg  [7:0] data
);
  always @(*) begin
    case (addr)
      6'd0:  data = 8'b1110_0000; // LOAD R0,[R0]  -> R0 = RAM[0] = 10
      6'd1:  data = 8'b0101_0101; // XOR  R1,R1    -> R1 = 0
      6'd2:  data = 8'b1010_0001; // INC  R1       -> R1 = 1
      6'd3:  data = 8'b1110_0101; // LOAD R1,[R1]  -> R1 = RAM[1] = 3
      6'd4:  data = 8'b0011_0100; // AND  R0,R1    -> R0 = 10 & 3 = 2
      6'd5:  data = 8'b1111_0100; // STORE R1,[R0] -> RAM[R0=2] = R1(3)
      6'd6:  data = 8'b0101_1010; // XOR  R2,R2    -> R2 = 0
      6'd7:  data = 8'b1010_0010; // INC  R2       -> R2 = 1
      6'd8:  data = 8'b1010_0010; // INC  R2       -> R2 = 2
      6'd9:  data = 8'b1110_1011; // LOAD R3,[R2]  -> R3 = RAM[R2=2] = 3
      6'd10: data = 8'b0100_1100; // OR   R0,R3    -> R0 = 2 | 3 = 3
      6'd11: data = 8'b1000_0000; // SHL  R0       -> R0 = 3<<1 = 6
      6'd12: data = 8'b1001_0000; // SHR  R0       -> R0 = 6>>1 = 3
      6'd13: data = 8'b1011_0000; // DEC  R0       -> R0 = 2
      6'd14: data = 8'b0000_0000; // NOP
      6'd15: data = 8'b1100_1000; // JMP  R2       -> PC <= R2 = 2
      default: data = 8'b0000_0000;
    endcase
  end
endmodule
