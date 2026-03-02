package async_fifo_tests_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import async_fifo_pkg::*;

  class fifo_smoke_test extends fifo_base_test;
    `uvm_component_utils(fifo_smoke_test)
    function new(string n, uvm_component p); super.new(n,p); endfunction

    task run_phase(uvm_phase phase);
      fifo_smoke_vseq vseq;
      phase.raise_objection(this);

      // cfg is now actually consumed by stress vseq; smoke keeps fixed behavior
      cfg.allow_illegal_attempts = 0;

      vseq = fifo_smoke_vseq::type_id::create("vseq");
      vseq.start(vseqr);

      phase.drop_objection(this);
    endtask
  endclass

  class fifo_stress_test extends fifo_base_test;
    `uvm_component_utils(fifo_stress_test)
    function new(string n, uvm_component p); super.new(n,p); endfunction

    task run_phase(uvm_phase phase);
      fifo_stress_vseq vseq;
      phase.raise_objection(this);

      // Now meaningful: drives how many ops happen
      cfg.num_ops = 5000;

      // Choose behavior:
      // 0: wait until !full/!empty before asserting enables (clean traffic)
      // 1: attempt even when full/empty (negative testing / assertions)
      cfg.allow_illegal_attempts = 0;

      vseq = fifo_stress_vseq::type_id::create("vseq");
      vseq.start(vseqr);

      phase.drop_objection(this);
    endtask
  endclass

  class fifo_fill_drain_test extends fifo_base_test;
    `uvm_component_utils(fifo_fill_drain_test)
    function new(string n, uvm_component p); super.new(n,p); endfunction

    task run_phase(uvm_phase phase);
      fifo_fill_drain_vseq vseq;
      phase.raise_objection(this);

      cfg.allow_illegal_attempts = 0;

      vseq = fifo_fill_drain_vseq::type_id::create("vseq");
      vseq.start(vseqr);

      phase.drop_objection(this);
    endtask
  endclass

  class fifo_reset_stress_test extends fifo_base_test;
    `uvm_component_utils(fifo_reset_stress_test)
    function new(string n, uvm_component p); super.new(n,p); endfunction

    task run_phase(uvm_phase phase);
      fifo_stress_vseq vseq;
      phase.raise_objection(this);

      cfg.num_ops = 8000;
      cfg.allow_illegal_attempts = 0;

      vseq = fifo_stress_vseq::type_id::create("vseq");
      vseq.start(vseqr);

      phase.drop_objection(this);
    endtask
  endclass

endpackage