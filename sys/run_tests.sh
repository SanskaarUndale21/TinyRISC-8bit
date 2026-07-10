#!/bin/sh
# run_tests.sh - run the cocotb testbench against the RTL with Icarus Verilog.
#
# Usage:
#   bash sys/run_tests.sh
set -e

cd "$(dirname "$0")/.."

VENV_DIR="sys/venv"
if [ -x "$VENV_DIR/bin/activate" ] || [ -f "$VENV_DIR/bin/activate" ]; then
  . "$VENV_DIR/bin/activate"
else
  echo "No venv found at $VENV_DIR - run sys/setup_ubuntu.sh first, or make sure" \
       "cocotb/pytest are already on your PATH."
fi

cd test
make clean
make
echo "==> Results: test/results.xml, waveform: test/tb.fst (open with gtkwave/surfer)"
