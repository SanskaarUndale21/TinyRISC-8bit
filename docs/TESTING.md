# Testing guide: RTL to GDS on Ubuntu / WSL

This walks through everything from "clone the repo" to "have a hardened
GDS", entirely on Ubuntu (native or WSL2). All commands assume the repo
root as the working directory unless noted.

## 0. Prerequisites

- Ubuntu 22.04/24.04+ (or WSL2 with an Ubuntu distro: `wsl --install -d Ubuntu`).
- `git`, and enough disk space for the PDK if you do the GDS hardening
  step (a few GB).
- On WSL specifically: the repo can live on the Windows filesystem
  (`/mnt/c/...`) - all commands below work fine from there, just expect
  filesystem I/O to be somewhat slower than on native ext4.

## 1. Clone

```sh
git clone https://github.com/SanskaarUndale21/TinyRISC-8bit.git
cd TinyRISC-8bit
```

## 2. RTL simulation (fast path, no PDK needed)

Installs Icarus Verilog + a Python venv with cocotb, then runs the full
testbench:

```sh
bash sys/setup_ubuntu.sh
bash sys/run_tests.sh
```

Expected output ends with something like:

```
** TESTS=4 PASS=4 FAIL=0 SKIP=0
```

Under the hood this just runs `cd test && make`, which:
1. Compiles `src/project.v` + everything in `src/rtl/*.v` + `test/tb.v`
   with `iverilog -g2001`.
2. Runs the cocotb tests in `test/test.py` under `vvp`.
3. Writes `test/results.xml` (JUnit XML) and `test/tb.fst` (waveform,
   viewable with `gtkwave test/tb.fst` or the `test/tb.gtkw` save file).

This is exactly what `.github/workflows/test.yaml` runs in CI on every
push.

> **Note on Python versions:** cocotb 2.0.1 currently declares a maximum
> supported Python version. If your Ubuntu ships a newer Python than that
> (e.g. 3.14), `sys/setup_ubuntu.sh` automatically retries the install with
> `COCOTB_IGNORE_PYTHON_REQUIRES=1` - this project's testbench only uses
> long-stable cocotb APIs (`Clock`, `ClockCycles`, signal `.value`), which
> work fine even when the package's own version gate is overly strict. If
> you'd rather not do that, install Python 3.11-3.13 (e.g.
> `sudo apt install python3.12 python3.12-venv` and point the venv at it)
> and skip the override entirely.

## 3. Gate-level netlist check (optional, after hardening)

Once you have a hardened gate-level netlist (`test/gate_level_netlist.v`,
produced by the GDS action or a local LibreLane run), you can re-run the
same testbench against it instead of the RTL:

```sh
cd test
make clean
GATES=yes make
```

This links in the PDK's standard-cell/IO Verilog models instead of the
RTL, so it needs `PDK_ROOT`/`PDK` set up (see step 4).

## 4. Full RTL-to-GDS hardening (LibreLane)

This reproduces what `.github/workflows/gds.yaml` does in CI
(`TinyTapeout/tt-gds-action`), but locally, using the same underlying
tool (`tt-support-tools` + LibreLane) TinyTapeout's own devcontainer uses.

```sh
bash sys/setup_gds_flow.sh   # clones tt-support-tools, installs LibreLane
bash sys/run_gds_harden.sh   # runs the hardening flow; downloads the PDK
                              # (ihp-sg13g2) on first run
```

`run_gds_harden.sh` sets `PDK_ROOT=$HOME/.ttsetup/pdk` and
`PDK=ihp-sg13g2` by default (override either as an env var before running
if you want a different location). Expect the first run to take a while:
the PDK download alone can take several minutes depending on your
connection, and the hardening flow (synthesis -> floorplan -> placement ->
CTS -> routing -> signoff) is CPU/time intensive even for a design this
small.

Results land in `./runs/<run-id>/final/` - copy anything you want to keep
into `./gds/` (which is otherwise empty and gitignored-by-content, see
`gds/README.md`), e.g.:

```sh
cp runs/*/final/gds/*.gds gds/
cp runs/*/final/metrics.csv gds/
```

`metrics.csv` has the actual synthesized cell/gate count, die area, and
timing - the authoritative numbers versus the hand estimate in
`docs/ARCHITECTURE.md`.

## 5. Precheck

TinyTapeout runs an automated precheck (`tt-gds-action/precheck` in CI)
that validates the hardened design against shuttle rules (area, IO,
antenna, DRC/LVS summaries, etc.) before it's eligible for submission.
Locally, once you have a successful hardening run:

```sh
. sys/venv/bin/activate
python sys/tt-support-tools/tt_tool.py --print-warnings
python sys/tt-support-tools/tt_tool.py --create-yaml   # regenerate info.yaml-derived files if needed
```

Check `sys/tt-support-tools/README.md` (cloned in step 4) for the full,
up-to-date set of `tt_tool.py` flags - this evolves with the TinyTapeout
tooling, so treat it as the source of truth over any specific flags
mentioned here.

## 6. Verify a fresh clone works end-to-end

Before trusting any of the above, it's worth confirming it works from a
completely clean checkout (no leftover build artifacts from your working
copy):

```sh
cd /tmp
git clone https://github.com/SanskaarUndale21/TinyRISC-8bit.git tt-verify
cd tt-verify
bash sys/setup_ubuntu.sh
bash sys/run_tests.sh
```

If this passes on a bare clone, the CI workflow (`.github/workflows/test.yaml`,
which runs on every push) will pass too.

## 7. Checking your chip on the TinyTapeout site

After pushing to GitHub with the `gds` and `docs` workflows green (see the
badges at the top of `README.md`), submit the design at
https://app.tinytapeout.com/ for the shuttle you're targeting. Once the
shuttle is fabricated and delivered, TinyTapeout publishes a chip explorer
where you can look up your project by GitHub repo/username and see its
die-shot placement and pinout - watch the TinyTapeout Discord/site for the
specific shuttle's timeline.
