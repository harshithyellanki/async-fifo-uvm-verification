# scripts/run_gui.do
transcript on

# 1. Clean and Setup Library
# If 'vdel' fails due to NFS locks, we try to create a fresh lib
if {[file exists work]} {
    vdel -all -lib work
}
vlib work
vmap work work

# 2. Define Paths
set TB    tb
set RTL   rtl
set TESTS tests

# 3. Compile Files
# CRITICAL: async_fifo_sva.sv MUST be compiled before top_tb.sv
vlog -sv -timescale 1ns/1ps \
    +incdir+$TB \
    +incdir+$TESTS \
    $RTL/async_fifo.sv \
    $TB/async_fifo_if.sv \
    $TB/async_fifo_sva.sv \
    $TB/async_fifo_pkg.sv \
    $TESTS/async_fifo_tests_pkg.sv \
    $TB/top_tb.sv

# 4. Optimization
# +acc ensures you can see all signals and variables in the GUI wave window
vopt top_tb -o top_opt +acc

# 5. Launch Simulator in GUI
# -classdebug allows you to inspect UVM objects and classes
vsim -gui top_opt +UVM_TESTNAME= fifo_smoke_test -classdebug

# 6. Automatic GUI Setup
# Add Interface and DUT signals to the waveform
add wave -group "VIF" sim:/top_tb/vif/*
add wave -group "DUT" sim:/top_tb/dut/*

# Open helpful UVM debug windows
view classbrowser
view uvm_windows

# Note: Simulation is paused at 0ns. 
# Click the 'Run All' icon or type 'run -all' in the console to start.