transcript on
if {[file exists work]} { vdel -all -lib work }
vlib work
vmap work work

vlog -sv -timescale 1ns/1ps \
    +incdir+tb +incdir+tests \
    rtl/async_fifo.sv \
    tb/async_fifo_if.sv \
    tb/async_fifo_sva.sv \
    tb/async_fifo_pkg.sv \
    tests/async_fifo_tests_pkg.sv \
    tb/top_tb.sv

vsim -c top_tb +UVM_TESTNAME=fifo_smoke_test -do "run -all; quit"
