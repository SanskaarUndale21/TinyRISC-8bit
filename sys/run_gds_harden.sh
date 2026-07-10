#!/bin/sh
# run_gds_harden.sh - run the RTL-to-GDS hardening flow locally (LibreLane).
#
# This is the same flow the gds GitHub Action runs in CI
# (.github/workflows/gds.yaml, via TinyTapeout/tt-gds-action), but driven
# locally through tt-support-tools' tt_tool.py. The PDK (ihp-sg13g2) is
# downloaded automatically on first run into $PDK_ROOT, and the run can
# take a long time (tens of minutes) and needs a few GB of disk space.
#
# Usage:
#   bash sys/setup_gds_flow.sh   # once
#   bash sys/run_gds_harden.sh
#
# Results land in ./runs/ (gitignored). Copy whatever you want to keep
# (GDS, LEF, reports, PNG previews) into ./gds/ before it gets clobbered by
# your next run.
set -e

cd "$(dirname "$0")/.."

# Force these rather than defaulting-if-unset: this project targets the
# IHP shuttle (ihp-sg13g2), and if your shell already has PDK/PDK_ROOT set
# from other OpenLane/sky130 work, a mere ${VAR:-default} would silently
# pick that up and harden against the wrong PDK entirely.
export PDK_ROOT="$HOME/.ttsetup/pdk"
export PDK="ihp-sg13g2"

VENV_DIR="sys/venv-gds"
TT_SUPPORT_DIR="sys/tt-support-tools"

if [ ! -d "$TT_SUPPORT_DIR" ]; then
  echo "tt-support-tools not found - run sys/setup_gds_flow.sh first." >&2
  exit 1
fi

. "$VENV_DIR/bin/activate"

echo "==> Hardening with LibreLane (PDK_ROOT=$PDK_ROOT, PDK=$PDK)..."
python "$TT_SUPPORT_DIR/tt_tool.py" --harden

echo "==> Done. Inspect ./runs/<run-id>/final/ for the GDS/LEF/reports."
echo "==> Copy anything you want to keep into ./gds/, e.g.:"
echo "      cp runs/*/final/gds/*.gds gds/"
