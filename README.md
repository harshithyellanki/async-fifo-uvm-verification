# Async FIFO + UVM Verification (Questa)

A complete, runnable example of a classic asynchronous FIFO (Gray pointers + 2FF sync) verified with a UVM testbench.

## Folder structure

```
async_fifo_uvm/
  rtl/      # DUT
  tb/       # interfaces, SVA, UVM env, top
  tests/    # UVM tests
  scripts/  # Questa .do scripts
  Makefile
  README.md
```

## Requirements
- Questa/ModelSim with UVM support (`vlog -sv`, `vsim`)

## Quick start

```bash
make run_smoke
```

## Other tests

```bash
make run_stress
make run_fill
make run_reset
```

## Useful plusargs
- Clock periods:
  - `+WCLK_NS=4 +RCLK_NS=7`
- Reset injection during stress:
  - `+INJECT_RESETS=1 +RESET_GAP_MIN=200 +RESET_GAP_MAX=600`

Example:

```bash
vsim -c -do "do scripts/questa_run.do" +UVM_TESTNAME=fifo_stress_test +WCLK_NS=3 +RCLK_NS=11
```

## Upload to GitHub (typical)
```bash
git init
git add .
git commit -m "Initial commit: async fifo + uvm"
git branch -M main
git remote add origin <YOUR_REPO_URL>
git push -u origin main
```
