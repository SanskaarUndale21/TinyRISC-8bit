# TinyRISC-8 architecture

## Instruction format

```
 7 6 5 4 3 2 1 0
[  opcode ][Rs][Rd]
```

- `opcode` (4 bits): one of 16 instructions, see below.
- `Rs` (2 bits): source register - 00=R0, 01=R1, 10=R2, 11=R3.
- `Rd` (2 bits): destination register - same encoding.

There is no immediate field. Two-operand ALU instructions (ADD, SUB, AND,
OR, XOR, MOV, CMP) use the accumulator convention `Rd <= Rd OP Rs` (Rd is
both an input operand and the write-back destination). Single-operand
instructions (SHL, SHR, INC, DEC) only use `Rd`; `Rs` is don't-care.

## Instruction set

| Opcode | Mnemonic | Effect | Flags written |
|---|---|---|---|
| 0000 | NOP | no operation | none |
| 0001 | ADD Rd,Rs | Rd <= Rd + Rs | Z,C,N,V |
| 0010 | SUB Rd,Rs | Rd <= Rd - Rs | Z,C,N,V |
| 0011 | AND Rd,Rs | Rd <= Rd & Rs | Z,C,N,V |
| 0100 | OR  Rd,Rs | Rd <= Rd \| Rs | Z,C,N,V |
| 0101 | XOR Rd,Rs | Rd <= Rd ^ Rs | Z,C,N,V |
| 0110 | MOV Rd,Rs | Rd <= Rs | none |
| 0111 | CMP Rd,Rs | flags <= Rd - Rs (Rd unchanged) | Z,C,N,V |
| 1000 | SHL Rd | Rd <= Rd << 1 | Z,C,N,V |
| 1001 | SHR Rd | Rd <= Rd >> 1 (logical) | Z,C,N,V |
| 1010 | INC Rd | Rd <= Rd + 1 | Z,C,N,V |
| 1011 | DEC Rd | Rd <= Rd - 1 | Z,C,N,V |
| 1100 | JMP Rs | PC <= Rs | none |
| 1101 | JZ Rs | if Z: PC <= Rs, else PC <= PC+1 | none |
| 1110 | LOAD Rd,[Rs] | Rd <= RAM[Rs[3:0]] | none |
| 1111 | STORE Rs,[Rd] | RAM[Rd[3:0]] <= Rs | none |

Flag conventions (see `src/rtl/alu.v`):
- **C** (carry): for ADD/INC, the arithmetic carry-out of bit 7. For
  SUB/DEC/CMP, the *borrow* flag (1 = a borrow occurred, i.e. `Rd < Rs`).
- **Z** (zero): result == 0.
- **N** (negative): result bit 7.
- **V** (overflow): signed two's-complement overflow of the operation.

## Register-indirect addressing (why LOAD/STORE/JMP/JZ use a register)

An 8-bit instruction with a 4-bit opcode and two 2-bit register fields has
no bits left for an immediate address or jump target. This design resolves
that by taking addresses/targets from a register's *value* at execution
time:

- `LOAD Rd,[Rs]`: RAM address = `Rs[3:0]` (low 4 bits, since the RAM has
  16 entries), data goes into `Rd`.
- `STORE Rs,[Rd]`: RAM address = `Rd[3:0]`, data comes from `Rs`.
- `JMP Rs` / `JZ Rs`: branch target = `Rs` (all 8 bits, since the PC is
  8-bit and the ROM is addressed by `PC[5:0]`).

This is also why the instruction set has no immediate-load instruction:
the only way to get a concrete constant into a register is to `LOAD` it
from a known RAM address, or to build small constants with `INC`/`XOR`
(see the demo program below).

## Datapath

```
        +-----------+      +-----------------+      +-------------------+
  PC -->| program_rom|---->| instruction_reg  |----->| instruction_decoder|
 (pc_out)| (64x8,    | rom  |  (captures on   | ir_out |  opcode, Rs, Rd,   |
        |  comb read)| data |   ir_write)     |       |  is_*, *_write_en  |
        +-----------+      +-----------------+      +----------+---------+
              ^                                                |
              | pc_next                                        v
        +-----------+                                +-------------------+
        |  program_  |<-------------- pc_write -------|    control_fsm    |
        |  counter   |                                 | FETCH/DECODE/    |
        +-----------+                                 | EXECUTE/WRITEBACK |
                                                        +---------+---------+
                                                                  |
     src_sel, dst_sel                                            | reg_write,
        |                                                        | flags_write,
        v                                                        | ram_write, pc_write
  +------------+   src_data (Rs)      +-----+                    |
  | register_  |--------------------->|     |  result             |
  |   file     |   dst_data (Rd)      | alu |------------------->(writeback mux)
  | R0..R3     |--------------------->|     |  carry/zero/neg/ovf      |
  +-----+------+                      +-----+          |                |
        ^                                               v                v
        |                                        +-------------+   +-----------+
        +---------------- write_data -------------| flags_reg   |   |  data_ram  |
                    (ALU result, or RAM data       |  Z C N V    |   | 16x8, sync |
                     for LOAD)                     +-------------+   | write /    |
                                                                        | comb read |
                                                                        +-----------+
```

Every module is described with extensive header comments in
`src/rtl/*.v`; `src/rtl/cpu_top.v` has the full signal-level wiring and a
stage-by-stage walkthrough in its header comment.

## Control FSM

Four states, one clock cycle each, uniform 4-cycle-per-instruction timing:

1. **FETCH** - `program_rom[pc[5:0]]` is addressed combinationally;
   `ir_write` is asserted so the instruction register captures the ROM
   output on this cycle's clock edge.
2. **DECODE** - the now-stable instruction register feeds
   `instruction_decoder`, which combinationally produces the opcode,
   register-select fields, and the `is_*` / `reg_write_en` /
   `flags_write_en` control signals.
3. **EXECUTE** - the ALU (and, for LOAD/STORE, the data RAM address mux)
   combinationally compute this instruction's result. Kept as its own
   state to give the combinational ALU/RAM path a full cycle to settle
   before WRITEBACK samples it, and to keep the classic
   fetch/decode/execute/writeback structure explicit in the RTL.
4. **WRITEBACK** - `reg_write`, `flags_write`, `ram_write` and `pc_write`
   pulse as appropriate for the decoded instruction, committing the ALU
   result (or loaded RAM data) into the register file, updating the
   flags, writing RAM (STORE only), and updating the PC (increment, or
   the branch target for JMP / a taken JZ).

`ena` (the TinyTapeout enable signal) freezes the state register itself,
so the entire CPU is inert whenever TinyTapeout has not selected/powered
this project - every other module's writes are gated by FSM-driven pulses.

## Demonstration program and execution trace

The program baked into `src/rtl/program_rom.v` (12 instructions, addresses
0-11) with `data_ram` preloaded as `RAM[0]=10, RAM[1]=3`:

| Addr | Instruction | Effect |
|---|---|---|
| 0 | XOR R0,R0 | R0 <= 0 (unconditional clear, see note below) |
| 1 | LOAD R0,[R0] | R0 <= RAM[0] = 10 |
| 2 | XOR R1,R1 | R1 <= 0 |
| 3 | INC R1 | R1 <= 1 |
| 4 | LOAD R1,[R1] | R1 <= RAM[1] = 3 |
| 5 | MOV R2,R0 | R2 <= 10 |
| 6 | ADD R2,R1 | R2 <= 13; Z=0 |
| 7 | CMP R2,R1 | 13 vs 3 -> Z=0 (not equal) |
| 8 | JZ R3 | not taken (Z=0); PC <= 9 |
| 9 | SUB R2,R1 | R2 <= 13 - 3 = 10 |
| 10 | CMP R2,R0 | 10 vs 10 -> Z=1 (equal) |
| 11 | JZ R3 | taken (Z=1); PC <= R3 = 0 -> loops |

**Why the XOR-clear at addresses 0 and 2:** registers are *not* reset
between loop iterations, only on a hardware reset. Without explicitly
zeroing R0/R1 first, `LOAD R0,[R0]` would use R0's value from the *end of
the previous pass* (10) as the RAM address on every iteration after the
first, instead of address 0, and the program would not repeat identically.
`XOR Rx,Rx` always yields 0 regardless of Rx's prior value, making each
pass through the loop start from the same architectural state. R3 is never
written by this program, so it stays at its reset value (0) forever and
needs no such clearing - which is exactly why it is used as the fixed
`JZ`/loop-target register.

Each instruction above takes 4 clock cycles; the whole 12-instruction loop
takes 48 cycles and then repeats forever, identically, since every
register/flag value at the end of a pass exactly matches the state at the
start.

## TinyTapeout compatibility notes

- Written entirely in Verilog-2001: no SystemVerilog constructs, no
  `always_comb`/`always_ff`, no interfaces.
- No `#` delays and no `initial` blocks other than none needed (ROM/RAM
  contents are fully combinational `case`/synchronous-reset assignments,
  not `$readmemh`, so there is nothing to initialize with `initial`).
- Fully synchronous design: a single clock domain, asynchronous active-low
  reset (`rst_n`) on every flip-flop, matching the TinyTapeout IHP
  (`ihp-sg13g2`) shuttle's standard-cell library and the
  `ttihp-verilog-template` CI/hardening flow unmodified.
- `ena` gates the control FSM's state register so the whole design is
  inert when not selected/powered, following the template's guidance.
- All 8 `uo_out` and all 8 `uio_out`/`uio_oe` pins are always driven (no
  floating outputs); unused input bits are tied into a `_unused` wire to
  avoid synthesis/lint warnings, per TinyTapeout's coding conventions.
- Occupies a single tile (`tiles: "1x1"` in `info.yaml`) - this is a very
  small design (see gate count estimate below).

## Estimated gate count

Rough hand estimate, in 2-input NAND-equivalent gates, for a typical
standard-cell flow (numbers will vary with the actual PDK cell library and
LibreLane optimization/synthesis settings - see `docs/TESTING.md` to get an
exact count from the real hardening run's `metrics.csv`):

| Block | Approx. gates | Notes |
|---|---|---|
| Register file (4x8 regs) | ~256 | 32 flip-flops (~6-8 gates each) |
| Program counter (8-bit) | ~64 | 8 flip-flops |
| Instruction register (8-bit) | ~64 | 8 flip-flops |
| Flags register (4-bit) | ~32 | 4 flip-flops |
| Data RAM (16x8) | ~1024 | 128 flip-flops (16x8, no dedicated SRAM macro) |
| ALU (adder/subtractor + logic muxing) | ~250 | 8-bit adder ~150, muxing/logic ~100 |
| Instruction decoder | ~80 | combinational opcode decode |
| Control FSM | ~40 | 2 flip-flops + next-state/output logic |
| Program ROM (64x8, case-statement) | ~150-300 | depends heavily on synthesis constant-folding of the case statement |
| Misc muxing/glue in cpu_top/project.v | ~100 | |
| **Total** | **~2,100-2,300 gate-equivalents** | Comfortably fits a single TinyTapeout tile |

The data RAM dominates the count because it is built from flip-flops
(no SRAM macro was used, to keep the design simple, fully synchronous, and
portable across PDKs) - this is the single largest opportunity for area
reduction if a future revision needs to shrink further.

## Suggested testbench

See `test/test.py` for the full implementation. Structure:

1. **Reset test** - after `rst_n` is released, all registers, flags and
   the PC must read 0.
2. **Single-step demo program test** - step 4 clock cycles at a time
   (one per instruction) through all 12 instructions, checking the
   architectural state after each one against the trace above.
3. **Infinite-loop test** - run two full 12-instruction passes and assert
   the architectural state is bit-for-bit identical, proving the loop is
   stable forever (this is exactly the bug this project's development
   caught and fixed: without the `XOR Rx,Rx` clears, the second pass
   would diverge from the first).
4. **Debug-readback test** - `ui_in[7:0] = 0x80 | reg_index` and check
   `uo_out` reflects that register's value.

Run it with `cd test && make` (uses Icarus Verilog + cocotb, see
`docs/TESTING.md` for full environment setup).
