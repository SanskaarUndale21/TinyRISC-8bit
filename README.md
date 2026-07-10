![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# TinyRISC-8

An 8-bit RISC CPU in synthesizable Verilog-2001, built for [TinyTapeout](https://tinytapeout.com).
4 general-purpose registers, 16 instructions, internal ROM/RAM, a classic
fetch/decode/execute/writeback FSM, and a baked-in demo program that runs
forever on the chip with no external stimulus required.

- [Architecture, datapath, FSM, execution trace](docs/ARCHITECTURE.md)
- [TinyTapeout datasheet source](docs/info.md)
- [RTL-to-GDS testing guide (Ubuntu/WSL)](docs/TESTING.md)
- [info.yaml](info.yaml)

## Repository layout

```
.
├── src/
│   ├── project.v         # TinyTapeout top level (tt_um_sanskaarundale21_tinyrisc8)
│   ├── config.json        # LibreLane/OpenLane hardening config (do not edit lightly)
│   └── rtl/                # CPU internals
│       ├── alu.v
│       ├── register_file.v
│       ├── program_counter.v
│       ├── instruction_register.v
│       ├── flags_register.v
│       ├── instruction_decoder.v
│       ├── program_rom.v
│       ├── data_ram.v
│       ├── control_fsm.v
│       └── cpu_top.v
├── test/                  # cocotb testbench (Icarus Verilog)
├── sys/                   # Ubuntu/WSL environment setup + RTL-to-GDS flow scripts
├── gds/                   # place to copy exported GDS/reports from a local hardening run
├── docs/                  # datasheet + architecture + testing docs
├── info.yaml              # TinyTapeout project manifest (pinout, top module, sources)
└── .github/workflows/     # test / gds / docs / fpga CI, unmodified from the TT template
```

## CPU at a glance

| | |
|---|---|
| Data width | 8-bit |
| Registers | R0-R3 (8-bit each) |
| Flags | Z (zero), C (carry/borrow), N (negative), V (overflow) |
| Program ROM | 64 x 8, demo program baked in at addresses 0-11 |
| Data RAM | 16 x 8, synchronous write / combinational read |
| Instruction format | `[7:4] opcode`, `[3:2] Rs`, `[1:0] Rd` |
| Instructions | NOP, ADD, SUB, AND, OR, XOR, MOV, CMP, SHL, SHR, INC, DEC, JMP, JZ, LOAD, STORE |
| Cycles/instruction | 4 (FETCH, DECODE, EXECUTE, WRITEBACK) |

Full details, the register-indirect addressing scheme (LOAD/STORE/JMP/JZ all
take their address from a register, since 8 bits leaves no room for an
immediate), and a full execution trace of the demo program are in
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## How to test

The demo program in `src/rtl/program_rom.v` runs automatically as soon as
`rst_n` is released and `ena` is high - no external stimulus is needed. It
loops forever, so `uio_out` (PC low nibble + flags) and `uo_out` (live ALU
result) toggle continuously, which is useful for confirming the chip is
alive on a scope/logic analyzer after fabrication.

Set `ui_in[7] = 1` and `ui_in[1:0]` to a register number (0-3) to read that
register's value out on `uo_out` instead of the live ALU result - a simple
debug/bring-up aid.

Run the full RTL simulation locally with cocotb + Icarus Verilog:

```sh
cd test
make -B
```

See [docs/TESTING.md](docs/TESTING.md) for the complete RTL-to-GDS walkthrough
(Ubuntu/WSL setup, simulation, LibreLane hardening, gate-level simulation).

## What is Tiny Tapeout?

Tiny Tapeout is an educational project that aims to make it easier and cheaper than ever to get your digital and analog designs manufactured on a real chip.

To learn more, visit https://tinytapeout.com.
