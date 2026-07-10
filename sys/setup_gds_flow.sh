#!/bin/sh
# setup_gds_flow.sh - prepare the local RTL-to-GDS hardening toolchain.
#
# Mirrors what TinyTapeout's own devcontainer / GitHub Action does: clone
# tt-support-tools (the CLI that drives hardening + precheck) and install
# LibreLane into a dedicated virtual environment. This does NOT download
# the PDK yet - that happens automatically the first time you run the
# hardening flow (sys/run_gds_harden.sh), since it can be multiple
# gigabytes.
#
# tt-support-tools' requirements.txt pins contourpy==1.3.3, which requires
# Python >=3.11 - this needs a newer interpreter than plain RTL simulation
# does (cocotb is fine on 3.10+), so this uses its own venv
# (sys/venv-gds) instead of reusing sys/venv from setup_ubuntu.sh.
#
# Usage:
#   bash sys/setup_gds_flow.sh
set -e

cd "$(dirname "$0")/.."

VENV_DIR="sys/venv-gds"

find_python311_plus() {
  for candidate in python3.13 python3.12 python3.11; do
    if command -v "$candidate" >/dev/null 2>&1; then
      echo "$candidate"
      return 0
    fi
  done
  return 1
}

PYBIN=""
if [ -d "$VENV_DIR" ]; then
  existing_version="$("$VENV_DIR/bin/python3" -c 'import sys; print(f"{sys.version_info[0]}.{sys.version_info[1]}")')"
  major="$(echo "$existing_version" | cut -d. -f1)"
  minor="$(echo "$existing_version" | cut -d. -f2)"
  if [ "$major" -gt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -ge 11 ]; }; then
    echo "==> Reusing existing $VENV_DIR (Python $existing_version)"
  else
    echo "==> $VENV_DIR is Python $existing_version (need >=3.11 for LibreLane's deps) - recreating"
    rm -rf "$VENV_DIR"
  fi
fi

if [ ! -d "$VENV_DIR" ]; then
  PYBIN="$(find_python311_plus || true)"
  if [ -z "$PYBIN" ]; then
    echo "==> No Python >=3.11 found - installing python3.11 via apt..."
    sudo apt-get update
    sudo apt-get install -y python3.11 python3.11-venv python3.11-dev
    PYBIN="python3.11"
  fi
  echo "==> Creating $VENV_DIR with $PYBIN ($("$PYBIN" --version))"
  "$PYBIN" -m venv "$VENV_DIR"
fi

TT_SUPPORT_DIR="sys/tt-support-tools"
if [ ! -d "$TT_SUPPORT_DIR" ]; then
  echo "==> Cloning tt-support-tools..."
  git clone https://github.com/TinyTapeout/tt-support-tools "$TT_SUPPORT_DIR"
else
  echo "==> tt-support-tools already present, pulling latest..."
  git -C "$TT_SUPPORT_DIR" pull
fi

echo "==> Upgrading pip..."
"$VENV_DIR/bin/pip" install --upgrade pip

echo "==> Installing tt-support-tools + LibreLane into $VENV_DIR ..."
"$VENV_DIR/bin/pip" install -r "$TT_SUPPORT_DIR/requirements.txt"
"$VENV_DIR/bin/pip" install librelane==3.0.0.dev44

echo "==> Done. Next: bash sys/run_gds_harden.sh"
