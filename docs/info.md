## How it works

TinyRISC-8 is a small 8-bit RISC CPU with 4 general-purpose registers
(R0-R3), a classic fetch/decode/execute/writeback control FSM, a 64-byte
internal program ROM and a 16-byte internal data RAM. There is no external
program loading mechanism - the ROM contents (a small demonstration
program) are fixed at synthesis time.

Instructions are a single byte: `[7:4]` opcode, `[3:2]` source register,
`[1:0]` destination register. Two-operand instructions (ADD, SUB, AND, OR,
XOR, MOV, CMP) follow the accumulator convention `Rd <= Rd OP Rs`.
Single-operand instructions (SHL, SHR, INC, DEC) only use `Rd`. Because an
8-bit instruction leaves no room for an immediate address, LOAD/STORE and
JMP/JZ all take their address/target from a register's current value
(register-indirect addressing) - see [ARCHITECTURE.md](ARCHITECTURE.md)
for the full instruction set, datapath and a worked execution trace.

The baked-in demo program continuously loads two values from RAM, adds
them, subtracts them, compares the results, and branches - looping forever
- so the chip shows continuous activity on its outputs as soon as it is
reset, with no external stimulus required.

## How to test

Power the design, hold `rst_n` low for a few clock cycles, then release
it. The CPU starts running the demo program immediately:

- `uo_out` shows the live ALU result of the instruction currently in the
  WRITEBACK stage.
- `uio_out[3:0]` shows the low 4 bits of the program counter.
- `uio_out[7:4]` shows the flags, packed as `{V, N, C, Z}`.

Since the program loops forever, you should see `uio_out` and `uo_out`
toggling continuously on a logic analyzer or scope - a simple way to
confirm the chip is alive.

For a closer look at internal register values, set `ui_in[7] = 1` and
`ui_in[1:0]` to a register number (0-3): `uo_out` will then show that
register's value instead of the live ALU result.

The `test/` directory contains a full cocotb testbench (run with
`cd test && make`) that single-steps the demo program instruction by
instruction and checks the architectural state (registers, flags, PC) at
each point, plus a debug-readback test.

## External hardware

None. This project is entirely self-contained (internal ROM/RAM, no
external memory or peripherals). `ui_in` is only used for the optional
debug register readback described above; `uio_in` is unused.
