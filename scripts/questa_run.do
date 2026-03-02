# Usage:
# vsim -c -do "do scripts/questa_run.do" +UVM_TESTNAME=fifo_smoke_test
# vsim -c -do "do scripts/questa_run.do" +UVM_TESTNAME=fifo_stress_test +WCLK_NS=3 +RCLK_NS=11
# vsim -c -do "do scripts/questa_run.do" +UVM_TESTNAME=fifo_reset_stress_test +INJECT_RESETS=1

vsim -c top_tb -sv_seed random +UVM_VERBOSITY=UVM_LOW
run -all
quit -f
