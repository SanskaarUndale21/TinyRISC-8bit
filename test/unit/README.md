# test/unit/

Supplementary, local-only verification - separate from the official
TinyTapeout cocotb flow in `test/` (which the `test` and `gl_test` CI jobs
run). These exist because the shipped demo program
(`src/rtl/program_rom.v`) only ever runs XOR, LOAD, INC, MOV, ADD, CMP,
SUB and JZ, so the official testbench never exercises AND, OR, SHL, SHR,
DEC, JMP, STORE or NOP against real hardware.

| File | What it checks |
|---|---|
| `alu_tb.v` | `src/rtl/alu.v` in isolation: all 16 opcodes, plus zero/carry/borrow/signed-overflow boundary cases (e.g. `0x7F + 1`, `0x80 - 1`) |
| `opcode_coverage_tb.v` + `opcode_coverage_rom.v` | The full CPU (`tt_um_...` top level) running a scratch program that exercises AND, OR, SHL, SHR, DEC, JMP, STORE and NOP - the opcodes the shipped demo skips. Register values are read the same way the real chip is meant to be debugged: through the `ui_in[7]`/`uo_out` debug-readback mux, never by peeking internal hierarchy. |

`opcode_coverage_rom.v` is a drop-in replacement for
`src/rtl/program_rom.v`, used only by these two files - it is never
substituted into the real build, and is deliberately kept out of
`test/Makefile` / `info.yaml` so it can never accidentally end up in the
hardened netlist. The official `gl_test` CI job simulates the *actual*
hardened netlist against the *actual* shipped ROM contents; swapping ROMs
here would defeat that check, which is why this lives in a separate,
plain-Verilog (no cocotb) testbench instead.

Run both with:

```sh
bash test/unit/run.sh
```
