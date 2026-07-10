#!/bin/sh
# setup_ubuntu.sh - install the RTL simulation toolchain on Ubuntu (or WSL Ubuntu).
#
# Installs Icarus Verilog + GTKWave and creates a Python virtual environment
# with cocotb and pytest (test/requirements.txt) so `sys/run_tests.sh` /
# `test/Makefile` work out of the box.
#
# Usage:
#   bash sys/setup_ubuntu.sh
set -e

cd "$(dirname "$0")/.."

echo "==> Installing apt packages (iverilog, gtkwave, python3-venv)..."
sudo apt-get update
sudo apt-get install -y iverilog gtkwave python3 python3-pip python3-venv

VENV_DIR="sys/venv"

echo "==> Creating Python virtual environment at $VENV_DIR ..."
python3 -m venv "$VENV_DIR"

# cocotb 2.0.1 declares a max supported Python version; on very new distros
# (e.g. Ubuntu shipping Python 3.14) this metadata check can be stricter than
# the actual code. If the plain install fails, retry with the check ignored -
# this project's testbench only uses stable, long-standing cocotb APIs.
echo "==> Installing test/requirements.txt ..."
if ! "$VENV_DIR/bin/pip" install -r test/requirements.txt; then
  echo "==> Standard install failed (likely a Python-version guard); retrying with COCOTB_IGNORE_PYTHON_REQUIRES=1"
  COCOTB_IGNORE_PYTHON_REQUIRES=1 "$VENV_DIR/bin/pip" install -r test/requirements.txt
fi

echo "==> Done. Activate with: source $VENV_DIR/bin/activate"
