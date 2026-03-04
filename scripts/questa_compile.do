transcript on

# 1. Setup Library
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
# Order is critical: RTL -> Interface -> Package -> Tests -> Top
vlog -sv -timescale 1ns/1ps \
    +incdir+$TB \
    +incdir+$TESTS \
    +define+UVM_NO_DEPRECATED \
    $RTL/async_fifo.sv \
    $TB/async_fifo_if.sv \
    $TB/async_fifo_sva.sv \
    $TB/async_fifo_pkg.sv \
    $TESTS/async_fifo_tests_pkg.sv \
    $TB/top_tb.sv

# 4. Success message
puts "Compilation Finished Successfully"

# Optional: Uncomment 'quit -f' if you want the shell to close after compiling
# quit -f