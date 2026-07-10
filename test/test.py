# SPDX-FileCopyrightText: (c) 2026
# SPDX-License-Identifier: Apache-2.0
"""
Cocotb testbench for the TinyRISC-8 CPU (tt_um_sanskaarundale21_tinyrisc8).

Drives the demonstration program baked into src/rtl/program_rom.v (see the
comment header in that file for the full instruction listing) and checks
the CPU's architectural state - registers, flags, PC - after each
instruction completes. Every instruction takes exactly 4 clock cycles
(FETCH, DECODE, EXECUTE, WRITEBACK), so instruction boundaries fall on
multiples of 4 clock edges after reset is released.

Only the primary TinyTapeout I/O pins (clk, rst_n, ena, ui_in, uo_out,
uio_in, uio_out) are used - no internal hierarchy is peeked - so this
testbench runs unmodified against both the RTL (`make`) and the hardened
gate-level netlist (`GATES=yes make`), where internal signal/module names
no longer exist. Register values are read out through the debug-readback
feature (ui_in[7]=1, ui_in[1:0]=register index -> uo_out) built into
project.v for exactly this purpose.
"""

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, Timer

CYCLES_PER_INSTRUCTION = 4


async def reset_dut(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 1)


async def read_reg(dut, index):
    """Read register R<index> via the debug-readback mux on uo_out.

    ui_in only feeds the output mux (see project.v), not the CPU's control
    logic, so toggling it never disturbs the running program - it is safe
    to call at any point in the instruction cycle.
    """
    dut.ui_in.value = 0x80 | index
    await Timer(1, unit="ns")
    value = int(dut.uo_out.value)
    dut.ui_in.value = 0
    return value


def flags(dut):
    """Return (Z, C, N, V) from the uio_out flag nibble."""
    uio = int(dut.uio_out.value)
    z = (uio >> 4) & 1
    c = (uio >> 5) & 1
    n = (uio >> 6) & 1
    v = (uio >> 7) & 1
    return z, c, n, v


def pc_low_nibble(dut):
    return int(dut.uio_out.value) & 0xF


@cocotb.test()
async def test_reset_state(dut):
    """After reset, all registers, flags and the PC must be zero."""
    dut._log.info("Start reset test")

    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    assert await read_reg(dut, 0) == 0
    assert await read_reg(dut, 1) == 0
    assert await read_reg(dut, 2) == 0
    assert await read_reg(dut, 3) == 0
    assert flags(dut) == (0, 0, 0, 0)
    assert pc_low_nibble(dut) == 0


@cocotb.test()
async def test_demo_program_one_pass(dut):
    """Step through the 12-instruction demo program one instruction at a
    time and check the architectural state after each one."""
    dut._log.info("Start demo program test")

    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    async def step():
        await ClockCycles(dut.clk, CYCLES_PER_INSTRUCTION)

    # 0: XOR R0,R0     -> R0 = 0
    await step()
    assert await read_reg(dut, 0) == 0

    # 1: LOAD R0,[R0]  -> R0 = RAM[0] = 10
    await step()
    assert await read_reg(dut, 0) == 10

    # 2: XOR R1,R1     -> R1 = 0
    await step()
    assert await read_reg(dut, 1) == 0

    # 3: INC R1        -> R1 = 1
    await step()
    assert await read_reg(dut, 1) == 1

    # 4: LOAD R1,[R1]  -> R1 = RAM[1] = 3
    await step()
    assert await read_reg(dut, 1) == 3

    # 5: MOV R2,R0     -> R2 = 10
    await step()
    assert await read_reg(dut, 2) == 10

    # 6: ADD R2,R1     -> R2 = 13
    await step()
    assert await read_reg(dut, 2) == 13
    z, _, n, _ = flags(dut)
    assert (z, n) == (0, 0)

    # 7: CMP R2,R1     -> flags only, 13 vs 3 -> not equal, R2 unchanged
    await step()
    assert await read_reg(dut, 2) == 13
    z, _, n, _ = flags(dut)
    assert z == 0

    # 8: JZ R3         -> not taken (Z=0), PC falls through to 9
    await step()
    assert pc_low_nibble(dut) == 9

    # 9: SUB R2,R1     -> R2 = 13 - 3 = 10
    await step()
    assert await read_reg(dut, 2) == 10

    # 10: CMP R2,R0    -> 10 vs 10 -> equal
    await step()
    z, _, n, _ = flags(dut)
    assert z == 1

    # 11: JZ R3        -> taken (Z=1), PC <= R3 = 0 (loops back to start)
    await step()
    assert pc_low_nibble(dut) == 0
    assert await read_reg(dut, 3) == 0

    # Register/flag/PC state after one full pass through the program.
    assert await read_reg(dut, 0) == 10
    assert await read_reg(dut, 1) == 3
    assert await read_reg(dut, 2) == 10
    assert flags(dut) == (1, 0, 0, 0)


@cocotb.test()
async def test_demo_program_loops_forever(dut):
    """The program has no HALT, so a second full pass must reproduce
    exactly the same architectural state as the first pass."""
    dut._log.info("Start infinite-loop test")

    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    async def snapshot():
        return (
            await read_reg(dut, 0),
            await read_reg(dut, 1),
            await read_reg(dut, 2),
            await read_reg(dut, 3),
            flags(dut),
        )

    # Run two full 12-instruction passes (48 + 48 cycles).
    await ClockCycles(dut.clk, CYCLES_PER_INSTRUCTION * 12)
    first_pass = await snapshot()

    await ClockCycles(dut.clk, CYCLES_PER_INSTRUCTION * 12)
    second_pass = await snapshot()

    assert first_pass == second_pass
    assert first_pass == (10, 3, 10, 0, (1, 0, 0, 0))


@cocotb.test()
async def test_debug_register_readback(dut):
    """ui_in[7]=1 selects a register (ui_in[1:0]) to appear on uo_out
    instead of the live ALU result."""
    dut._log.info("Start debug readback test")

    clock = Clock(dut.clk, 100, unit="ns")
    cocotb.start_soon(clock.start())

    await reset_dut(dut)

    # Run one full pass so registers hold known non-zero values.
    await ClockCycles(dut.clk, CYCLES_PER_INSTRUCTION * 12)

    assert await read_reg(dut, 0) == 10
    assert await read_reg(dut, 1) == 3
    assert await read_reg(dut, 2) == 10
    assert await read_reg(dut, 3) == 0
