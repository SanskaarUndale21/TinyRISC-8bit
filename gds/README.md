# gds/

Empty by design. This is where you copy the artifacts you want to keep from
a local RTL-to-GDS hardening run (`sys/run_gds_harden.sh`), since the raw
`runs/` directory is gitignored and gets overwritten on every run.

Typical contents after a hardening run:

```sh
cp runs/*/final/gds/*.gds gds/
cp runs/*/final/lef/*.lef gds/
cp -r runs/*/final/metrics.csv gds/
```

The canonical, CI-produced GDS for this project lives in the `gds` GitHub
Actions workflow artifact / the `gds` branch that TinyTapeout's tooling
manages automatically - this folder is just a convenience for local
inspection, not the source of truth used for tapeout.
