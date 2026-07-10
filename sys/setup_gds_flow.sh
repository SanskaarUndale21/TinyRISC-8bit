#!/bin/sh
# setup_gds_flow.sh - prepare the local RTL-to-GDS hardening toolchain.
#
# Mirrors what TinyTapeout's own devcontainer / GitHub Action does: clone
# tt-support-tools (the CLI that drives hardening + precheck) and install
# LibreLane into the same virtual environment used for simulation. This
# does NOT download the PDK yet - that happens automatically the first
# time you run the hardening flow (sys/run_gds_harden.sh), since it can be
# multiple gigabytes.
#
# Usage:
#   bash sys/setup_gds_flow.sh
set -e

cd "$(dirname "$0")/.."

VENV_DIR="sys/venv"
if [ ! -d "$VENV_DIR" ]; then
  echo "==> No venv at $VENV_DIR yet, running setup_ubuntu.sh first..."
  bash sys/setup_ubuntu.sh
fi

TT_SUPPORT_DIR="sys/tt-support-tools"
if [ ! -d "$TT_SUPPORT_DIR" ]; then
  echo "==> Cloning tt-support-tools..."
  git clone https://github.com/TinyTapeout/tt-support-tools "$TT_SUPPORT_DIR"
else
  echo "==> tt-support-tools already present, pulling latest..."
  git -C "$TT_SUPPORT_DIR" pull
fi

echo "==> Upgrading pip (an old pip can fail to find wheels for newer"
echo "    pinned deps like contourpy, e.g. 'No matching distribution found')..."
"$VENV_DIR/bin/pip" install --upgrade pip

echo "==> Installing tt-support-tools + LibreLane into $VENV_DIR ..."
"$VENV_DIR/bin/pip" install -r "$TT_SUPPORT_DIR/requirements.txt"
"$VENV_DIR/bin/pip" install librelane==3.0.0.dev44

echo "==> Done. Next: bash sys/run_gds_harden.sh"
