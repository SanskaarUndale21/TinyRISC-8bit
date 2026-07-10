# sys/

Environment and flow scripts for running this project's RTL simulation and
RTL-to-GDS hardening on Ubuntu (native or WSL). These are not consumed by
TinyTapeout's own CI (`.github/workflows/`); they exist so you can reproduce
the whole flow yourself on your own machine before/after submitting.

See [../docs/TESTING.md](../docs/TESTING.md) for the full walkthrough. Quick
reference:

| Script | Purpose |
|---|---|
| `setup_ubuntu.sh` | Install iverilog/cocotb/Python toolchain needed for RTL simulation |
| `run_tests.sh` | Run the cocotb testbench (`test/`) against the RTL |
| `setup_gds_flow.sh` | Clone `tt-support-tools`, install LibreLane, prep the PDK for hardening |
| `run_gds_harden.sh` | Run the actual RTL-to-GDS hardening flow (LibreLane) |

All scripts assume they are run from the repository root, e.g.:

```sh
bash sys/setup_ubuntu.sh
bash sys/run_tests.sh
```
