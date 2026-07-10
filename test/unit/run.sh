#!/bin/sh
# run.sh - run the supplementary local-only unit/coverage tests.
#
# These are plain Verilog (no cocotb) and separate from the official
# TinyTapeout test flow in test/Makefile: they exist to give confidence
# in the opcodes/edge-cases the shipped demo program (and therefore the
# official gl_test CI job, which simulates against the real ROM) never
# exercises. See the header comments in alu_tb.v and
# opcode_coverage_tb.v for what each one checks and why it's kept
# separate.
#
# Usage:
#   bash test/unit/run.sh
set -e

cd "$(dirname "$0")/../.."
SRC=src
UNIT=test/unit

echo "==> ALU unit test (all 16 opcodes, boundary cases)"
iverilog -g2001 -o /tmp/tinyrisc8_alu_tb.vvp "$UNIT/alu_tb.v" "$SRC/rtl/alu.v"
vvp /tmp/tinyrisc8_alu_tb.vvp | tail -5

echo
echo "==> Opcode coverage test (AND/OR/SHL/SHR/DEC/JMP/STORE/NOP)"
iverilog -g2001 -o /tmp/tinyrisc8_opcode_cov_tb.vvp \
  "$UNIT/opcode_coverage_tb.v" \
  "$SRC/project.v" \
  "$SRC/rtl/register_file.v" \
  "$SRC/rtl/program_counter.v" \
  "$SRC/rtl/instruction_register.v" \
  "$SRC/rtl/flags_register.v" \
  "$SRC/rtl/instruction_decoder.v" \
  "$UNIT/opcode_coverage_rom.v" \
  "$SRC/rtl/data_ram.v" \
  "$SRC/rtl/control_fsm.v" \
  "$SRC/rtl/cpu_top.v" \
  "$SRC/rtl/alu.v"
vvp /tmp/tinyrisc8_opcode_cov_tb.vvp | tail -20
