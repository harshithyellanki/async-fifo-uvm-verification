vlib work
vmap work work

set TB    ../tb
set RTL   ../rtl
set TESTS ../tests

vlog -sv -timescale 1ns/1ps ^
  $RTL/async_fifo.sv ^
  $TB/async_fifo_if.sv ^
  $TB/async_fifo_sva.sv ^
  $TB/async_fifo_pkg.sv ^
  $TESTS/async_fifo_tests_pkg.sv ^
  $TB/top_tb.sv

quit -f
