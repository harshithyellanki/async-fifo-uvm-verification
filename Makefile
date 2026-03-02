SIM ?= vsim

all: run_smoke

compile:
	cd scripts && $(SIM) -c -do questa_compile.do

run_smoke: compile
	$(SIM) -c -do "do scripts/questa_run.do" +UVM_TESTNAME=fifo_smoke_test

run_stress: compile
	$(SIM) -c -do "do scripts/questa_run.do" +UVM_TESTNAME=fifo_stress_test

run_fill: compile
	$(SIM) -c -do "do scripts/questa_run.do" +UVM_TESTNAME=fifo_fill_drain_test

run_reset: compile
	$(SIM) -c -do "do scripts/questa_run.do" +UVM_TESTNAME=fifo_reset_stress_test +INJECT_RESETS=1

clean:
	rm -rf work transcript vsim.wlf
