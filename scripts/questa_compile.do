# scripts/questa_compile.do
transcript on

# Create + map work lib (safe if it already exists)
if {[file exists work]} {
  vmap work work
} else {
  vlib work
  vmap work work
}

# Assume you run vsim from PROJECT ROOT (the folder that contains rtl/tb/tests/scripts)
set TB    tb
set RTL   rtl
set TESTS tests

# Compile (Tcl line continuation uses "\")
vlog -sv -timescale 1ns/1ps \
  +incdir+$TB \
  +incdir+$TESTS \
  $RTL/async_fifo.sv \
  $TB/async_fifo_if.sv \
  $TB/async_fifo_sva.sv \
  $TB/async_fifo_pkg.sv \
  $TESTS/async_fifo_tests_pkg.sv \
  $TB/top_tb.sv

quit -f