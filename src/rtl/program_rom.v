/*
 * program_rom.v - TinyRISC-8 program ROM (64 x 8)
 *
 * Combinational read, addressed by the low 6 bits of the 8-bit PC.
 * Contents are fixed at synthesis time via a case statement (no $readmemh,
 * so the demo program is baked directly into the gate-level netlist).
 *
 * Demonstration program (one instruction = one byte, addresses 0-11):
 *
 *   Addr  Mnemonic         Encoding   Meaning
 *   0     XOR   R0,R0      0101_0000  R0 <= R0 ^ R0        -> R0 = 0
 *   1     LOAD  R0,[R0]    1110_0000  R0 <= RAM[R0=0]      -> R0 = 10
 *   2     XOR   R1,R1      0101_0101  R1 <= R1 ^ R1        -> R1 = 0
 *   3     INC   R1         1010_0001  R1 <= R1 + 1         -> R1 = 1
 *   4     LOAD  R1,[R1]    1110_0101  R1 <= RAM[R1=1]      -> R1 = 3
 *   5     MOV   R2,R0      0110_0010  R2 <= R0             -> R2 = 10
 *   6     ADD   R2,R1      0001_0110  R2 <= R2 + R1        -> R2 = 13
 *   7     CMP   R2,R1      0111_0110  flags <= R2 - R1     -> Z=0 (13!=3)
 *   8     JZ    R3         1101_1100  not taken (Z=0), PC <= PC+1
 *   9     SUB   R2,R1      0010_0110  R2 <= R2 - R1        -> R2 = 10
 *   10    CMP   R2,R0      0111_0010  flags <= R2 - R0     -> Z=1 (10==10)
 *   11    JZ    R3         1101_1100  taken (Z=1), PC <= R3 = 0 -> loop
 *
 * The XOR Rx,Rx steps at addresses 0 and 2 unconditionally zero R0/R1
 * before they are used as RAM pointers, regardless of what value they
 * held at the end of the previous pass through the loop. Without them,
 * "LOAD R0,[R0]" would address RAM with R0's *previous* value instead of
 * 0 on the second and later passes, since registers are not reset between
 * loop iterations - only on a hardware reset. R3 is never written by this
 * program, so it stays 0 (its reset value) for every pass and needs no
 * such clearing. With the explicit XOR clears, every iteration starts
 * from the same architectural state, so the program loops forever,
 * deterministically repeating the same load/add/compare/branch sequence -
 * useful for continuously toggling activity on the TinyTapeout outputs
 * during bring-up.
 *
 * See data_ram.v for the RAM[0]=10, RAM[1]=3 preload that this program
 * depends on, and register_file.v / cpu_top.v for the register-indirect
 * addressing scheme (LOAD/STORE address comes from a register value;
 * JMP/JZ target address also comes from a register value) that this
 * 8-bit-only instruction format requires.
 */

`default_nettype none

module program_rom (
    input  wire [5:0] addr,
    output reg  [7:0] data
);

  always @(*) begin
    case (addr)
      6'd0:  data = 8'b0101_0000;  // XOR  R0,R0
      6'd1:  data = 8'b1110_0000;  // LOAD R0,[R0]
      6'd2:  data = 8'b0101_0101;  // XOR  R1,R1
      6'd3:  data = 8'b1010_0001;  // INC  R1
      6'd4:  data = 8'b1110_0101;  // LOAD R1,[R1]
      6'd5:  data = 8'b0110_0010;  // MOV  R2,R0
      6'd6:  data = 8'b0001_0110;  // ADD  R2,R1
      6'd7:  data = 8'b0111_0110;  // CMP  R2,R1
      6'd8:  data = 8'b1101_1100;  // JZ   R3
      6'd9:  data = 8'b0010_0110;  // SUB  R2,R1
      6'd10: data = 8'b0111_0010;  // CMP  R2,R0
      6'd11: data = 8'b1101_1100;  // JZ   R3  (taken -> loops back to addr 0)
      default: data = 8'b0000_0000;  // NOP (unused ROM space)
    endcase
  end

endmodule
