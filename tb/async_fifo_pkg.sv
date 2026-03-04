package async_fifo_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ----------------------------
  // Parameters shared by TB
  // ----------------------------
  parameter int DATA_WIDTH = 32;
  parameter int ADDR_BITS  = 4;
  parameter int DEPTH      = (1 << ADDR_BITS);

  // ----------------------------
  // Transaction types
  // ----------------------------
  typedef enum {OP_WRITE, OP_READ, OP_IDLE} fifo_op_e;

  class fifo_item extends uvm_sequence_item;
    rand fifo_op_e             op;
    rand bit [DATA_WIDTH-1:0]  data;
    rand int unsigned          idle_cycles;

    `uvm_object_utils_begin(fifo_item)
      `uvm_field_enum(fifo_op_e, op, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(idle_cycles, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="fifo_item");
      super.new(name);
      idle_cycles = 0;
    endfunction

    constraint c_idle_small { idle_cycles inside {[0:10]}; }
    constraint c_op_dist { op dist {OP_WRITE:=45, OP_READ:=45, OP_IDLE:=10}; }
  endclass

  // Observed events from monitors
  class fifo_write_obs extends uvm_sequence_item;
    bit [DATA_WIDTH-1:0] data;
    `uvm_object_utils_begin(fifo_write_obs)
      `uvm_field_int(data, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="fifo_write_obs"); super.new(name); endfunction
  endclass

  class fifo_read_obs extends uvm_sequence_item;
    bit [DATA_WIDTH-1:0] data;
    `uvm_object_utils_begin(fifo_read_obs)
      `uvm_field_int(data, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="fifo_read_obs"); super.new(name); endfunction
  endclass

  // ----------------------------
  // Config
  // ----------------------------
  class fifo_env_cfg extends uvm_object;
    `uvm_object_utils(fifo_env_cfg)

    // Used by virtual sequences to determine stimulus length
    int unsigned num_ops = 2000;

    // 0 => drivers will WAIT for !full / !empty before asserting enables
    // 1 => drivers may still assert enables even when full/empty (negative testing)
    bit allow_illegal_attempts = 0;

    // (Optional knob; in this version SVA enable is controlled by plusarg in top_tb)
    bit enable_assertions = 1;

    function new(string name="fifo_env_cfg");
      super.new(name);
    endfunction
  endclass

  // ----------------------------
  // Write agent: sequencer/driver/monitor
  // ----------------------------
  class fifo_w_sequencer extends uvm_sequencer #(fifo_item);
    `uvm_component_utils(fifo_w_sequencer)
    function new(string n, uvm_component p); super.new(n,p); endfunction
  endclass

  class fifo_w_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_w_driver)

    //virtual async_fifo_if #(DATA_WIDTH) vif;
  virtual async_fifo_if
    fifo_env_cfg cfg;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fifo_w_driver missing vif")
      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","fifo_w_driver missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_item tr;

      vif.cb_w.w_en   <= 1'b0;
      vif.cb_w.wdata  <= '0;

      wait (vif.wrst_n === 1'b1);
      repeat (2) @(vif.cb_w);

      forever begin
        seq_item_port.get_next_item(tr);

        // Optional idle insertion
        repeat (tr.idle_cycles) begin
          vif.cb_w.w_en <= 1'b0;
          @(vif.cb_w);
        end

        if (tr.op == OP_WRITE) begin
          // If illegal attempts are not allowed, wait until FIFO is not full
          if (!cfg.allow_illegal_attempts) begin
            while (vif.cb_w.wfull) begin
              vif.cb_w.w_en <= 1'b0;
              @(vif.cb_w);
            end
          end

          vif.cb_w.wdata <= tr.data;
          vif.cb_w.w_en  <= 1'b1;
          @(vif.cb_w);
          vif.cb_w.w_en  <= 1'b0;
        end
        else begin
          // OP_READ/OP_IDLE do nothing on write interface
          vif.cb_w.w_en <= 1'b0;
          @(vif.cb_w);
        end

        seq_item_port.item_done();
      end
    endtask
  endclass

  class fifo_w_monitor extends uvm_component;
    `uvm_component_utils(fifo_w_monitor)

    //virtual async_fifo_if #(DATA_WIDTH) vif;
  virtual async_fifo_if
    uvm_analysis_port #(fifo_write_obs) ap;
    fifo_env_cfg cfg;

    function new(string n, uvm_component p);
      super.new(n,p);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fifo_w_monitor missing vif")
      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","fifo_w_monitor missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_write_obs obs;
      wait (vif.wrst_n === 1'b1);
      forever begin
        @(posedge vif.wclk);
        // Only count ACCEPTED writes (i.e., write handshake when not full)
        if (vif.w_en && !vif.wfull) begin
          obs = fifo_write_obs::type_id::create("obs");
          obs.data = vif.wdata;
          ap.write(obs);
        end
      end
    endtask
  endclass

  class fifo_w_agent extends uvm_component;
    `uvm_component_utils(fifo_w_agent)

    fifo_w_sequencer sqr;
    fifo_w_driver    drv;
    fifo_w_monitor   mon;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = fifo_w_sequencer::type_id::create("sqr", this);
      drv = fifo_w_driver   ::type_id::create("drv", this);
      mon = fifo_w_monitor  ::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ----------------------------
  // Read agent
  // ----------------------------
  class fifo_r_sequencer extends uvm_sequencer #(fifo_item);
    `uvm_component_utils(fifo_r_sequencer)
    function new(string n, uvm_component p); super.new(n,p); endfunction
  endclass

  class fifo_r_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_r_driver)

   // virtual async_fifo_if #(DATA_WIDTH) vif;
  virtual async_fifo_if
    fifo_env_cfg cfg;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fifo_r_driver missing vif")
      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","fifo_r_driver missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_item tr;

      vif.cb_r.r_en <= 1'b0;

      wait (vif.rrst_n === 1'b1);
      repeat (2) @(vif.cb_r);

      forever begin
        seq_item_port.get_next_item(tr);

        // Optional idle insertion
        repeat (tr.idle_cycles) begin
          vif.cb_r.r_en <= 1'b0;
          @(vif.cb_r);
        end

        if (tr.op == OP_READ) begin
          // If illegal attempts are not allowed, wait until FIFO is not empty
          if (!cfg.allow_illegal_attempts) begin
            while (vif.cb_r.rempty) begin
              vif.cb_r.r_en <= 1'b0;
              @(vif.cb_r);
            end
          end

          vif.cb_r.r_en <= 1'b1;
          @(vif.cb_r);
          vif.cb_r.r_en <= 1'b0;
        end
        else begin
          // OP_WRITE/OP_IDLE do nothing on read interface
          vif.cb_r.r_en <= 1'b0;
          @(vif.cb_r);
        end

        seq_item_port.item_done();
      end
    endtask
  endclass

  class fifo_r_monitor extends uvm_component;
    `uvm_component_utils(fifo_r_monitor)

   // virtual async_fifo_if #(DATA_WIDTH) vif;
  virtual async_fifo_if
    uvm_analysis_port #(fifo_read_obs) ap;
    fifo_env_cfg cfg;

    function new(string n, uvm_component p);
      super.new(n,p);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fifo_r_monitor missing vif")
      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","fifo_r_monitor missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_read_obs obs;
      wait (vif.rrst_n === 1'b1);
      forever begin
        @(posedge vif.rclk);
        // Only count ACCEPTED reads (i.e., read handshake when not empty)
        if (vif.r_en && !vif.rempty) begin
          obs = fifo_read_obs::type_id::create("obs");
          obs.data = vif.rdata;
          ap.write(obs);
        end
      end
    endtask
  endclass

  class fifo_r_agent extends uvm_component;
    `uvm_component_utils(fifo_r_agent)

    fifo_r_sequencer sqr;
    fifo_r_driver    drv;
    fifo_r_monitor   mon;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = fifo_r_sequencer::type_id::create("sqr", this);
      drv = fifo_r_driver   ::type_id::create("drv", this);
      mon = fifo_r_monitor  ::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ----------------------------
  // Scoreboard: data integrity + ordering
  // ----------------------------
  // class fifo_scoreboard extends uvm_component;
  //   `uvm_component_utils(fifo_scoreboard)

  //   uvm_analysis_imp #(fifo_write_obs, fifo_scoreboard) w_imp;
  //   uvm_analysis_imp #(fifo_read_obs,  fifo_scoreboard) r_imp;

  //   fifo_env_cfg cfg;

  //   bit [DATA_WIDTH-1:0] exp_q[$];

  //   longint unsigned writes_seen;
  //   longint unsigned reads_seen;
  //   longint unsigned mismatches;

  //   function new(string n, uvm_component p);
  //     super.new(n,p);
  //     w_imp = new("w_imp", this);
  //     r_imp = new("r_imp", this);
  //   endfunction

  //   function void build_phase(uvm_phase phase);
  //     super.build_phase(phase);
  //     if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
  //       `uvm_fatal("NOCFG","scoreboard missing cfg")
  //   endfunction

  //   function void write(fifo_write_obs t);
  //     exp_q.push_back(t.data);
  //     writes_seen++;
  //   endfunction

  //   function void write(fifo_read_obs t);
  //     bit [DATA_WIDTH-1:0] exp;
  //     reads_seen++;
  //     if (exp_q.size() == 0) begin
  //       mismatches++;
  //       `uvm_error("SB", $sformatf("Read observed (0x%0h) but expected queue is empty!", t.data))
  //     end else begin
  //       exp = exp_q.pop_front();
  //       if (t.data !== exp) begin
  //         mismatches++;
  //         `uvm_error("SB", $sformatf("Data mismatch: got 0x%0h exp 0x%0h", t.data, exp))
  //       end
  //     end
  //   endfunction

  //   function void report_phase(uvm_phase phase);
  //     super.report_phase(phase);
  //     `uvm_info("SB", $sformatf("Writes=%0d Reads=%0d Mismatches=%0d ExpQ_left=%0d",
  //                               writes_seen, reads_seen, mismatches, exp_q.size()), UVM_LOW)
  //     if (mismatches != 0) begin
  //       `uvm_error("SB", "TEST FAILED due to mismatches")
  //     end
  //   endfunction
  // endclass

  class fifo_scoreboard extends uvm_component;
  `uvm_component_utils(fifo_scoreboard)

  // Two different imps with different callback names: write_w / write_r
  uvm_analysis_imp_w #(fifo_write_obs, fifo_scoreboard) w_imp;
  uvm_analysis_imp_r #(fifo_read_obs,  fifo_scoreboard) r_imp;

  fifo_env_cfg cfg;
  bit [DATA_WIDTH-1:0] exp_q[$];

  longint unsigned writes_seen;
  longint unsigned reads_seen;
  longint unsigned mismatches;

  function new(string n, uvm_component p);
    super.new(n,p);
    w_imp = new("w_imp", this);
    r_imp = new("r_imp", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG","scoreboard missing cfg")
  endfunction

  // Called for write-side observed ACCEPTED writes
  function void write_w(fifo_write_obs t);
    exp_q.push_back(t.data);
    writes_seen++;
  endfunction

  // Called for read-side observed ACCEPTED reads
  function void write_r(fifo_read_obs t);
    bit [DATA_WIDTH-1:0] exp;
    reads_seen++;

    if (exp_q.size() == 0) begin
      mismatches++;
      `uvm_error("SB", $sformatf("Read observed (0x%0h) but expected queue is empty!", t.data))
    end else begin
      exp = exp_q.pop_front();
      if (t.data !== exp) begin
        mismatches++;
        `uvm_error("SB", $sformatf("Data mismatch: got 0x%0h exp 0x%0h", t.data, exp))
      end
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("SB", $sformatf("Writes=%0d Reads=%0d Mismatches=%0d ExpQ_left=%0d",
                              writes_seen, reads_seen, mismatches, exp_q.size()), UVM_LOW)
    if (mismatches != 0) `uvm_error("SB", "TEST FAILED due to mismatches")
  endfunction
endclass

  // ----------------------------
  // Functional coverage
  // ----------------------------
  // class fifo_coverage extends uvm_component;
  //   `uvm_component_utils(fifo_coverage)

  //   uvm_analysis_imp #(fifo_write_obs, fifo_coverage) w_imp;
  //   uvm_analysis_imp #(fifo_read_obs,  fifo_coverage) r_imp;

  //   virtual async_fifo_if #(DATA_WIDTH) vif;
  //   int unsigned fill_level;
  //   fifo_env_cfg cfg;

  //   covergroup cg_ops;
  //     option.per_instance = 1;

  //     cp_full   : coverpoint vif.wfull  { bins no = {0}; bins yes = {1}; }
  //     cp_empty  : coverpoint vif.rempty { bins no = {0}; bins yes = {1}; }

  //     cp_fill : coverpoint fill_level {
  //       bins zero     = {0};
  //       bins low      = {[1:DEPTH/4]};
  //       bins mid      = {[DEPTH/4+1:3*DEPTH/4]};
  //       bins high     = {[3*DEPTH/4+1:DEPTH-1]};
  //       bins maxish   = {DEPTH};
  //     }

  //     x_fill_full  : cross cp_fill, cp_full;
  //     x_fill_empty : cross cp_fill, cp_empty;
  //   endgroup

  //   function new(string n, uvm_component p);
  //     super.new(n,p);
  //     w_imp = new("w_imp", this);
  //     r_imp = new("r_imp", this);
  //     cg_ops = new();
  //     fill_level = 0;
  //   endfunction

  //   function void build_phase(uvm_phase phase);
  //     super.build_phase(phase);
  //     if (!uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::get(this,"","vif",vif))
  //       `uvm_fatal("NOVIF","coverage missing vif")
  //     if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
  //       `uvm_fatal("NOCFG","coverage missing cfg")
  //   endfunction

  //   function void write(fifo_write_obs t);
  //     if (fill_level < DEPTH) fill_level++;
  //     cg_ops.sample();
  //   endfunction

  //   function void write(fifo_read_obs t);
  //     if (fill_level > 0) fill_level--;
  //     cg_ops.sample();
  //   endfunction
  // endclass

// class fifo_coverage extends uvm_component;
//   `uvm_component_utils(fifo_coverage)

//   uvm_analysis_imp_w #(fifo_write_obs, fifo_coverage) w_imp;
//   uvm_analysis_imp_r #(fifo_read_obs,  fifo_coverage) r_imp;

//   virtual async_fifo_if
//   int unsigned fill_level;
//   fifo_env_cfg cfg;

//   covergroup cg_ops;
//     option.per_instance = 1;

//     cp_full   : coverpoint vif.wfull  { bins no = {0}; bins yes = {1}; }
//     cp_empty  : coverpoint vif.rempty { bins no = {0}; bins yes = {1}; }

//     cp_fill : coverpoint fill_level {
//       bins zero   = {0};
//       bins low    = {[1:DEPTH/4]};
//       bins mid    = {[DEPTH/4+1:3*DEPTH/4]};
//       bins high   = {[3*DEPTH/4+1:DEPTH-1]};
//       bins maxish = {DEPTH};
//     }

//     x_fill_full  : cross cp_fill, cp_full;
//     x_fill_empty : cross cp_fill, cp_empty;
//   endgroup

//   function new(string n, uvm_component p);
//     super.new(n,p);
//     w_imp = new("w_imp", this);
//     r_imp = new("r_imp", this);
//     cg_ops = new();
//     fill_level = 0;
//   endfunction

//   function void build_phase(uvm_phase phase);
//     super.build_phase(phase);
//     if (!uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::get(this,"","vif",vif))
//       `uvm_fatal("NOVIF","coverage missing vif")
//     if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
//       `uvm_fatal("NOCFG","coverage missing cfg")
//   endfunction

//   function void write_w(fifo_write_obs t);
//     if (fill_level < DEPTH) fill_level++;
//     cg_ops.sample();
//   endfunction

//   function void write_r(fifo_read_obs t);
//     if (fill_level > 0) fill_level--;
//     cg_ops.sample();
//   endfunction
// endclass

//   // ----------------------------
//   // Environment
//   // ----------------------------
//   class fifo_env extends uvm_env;
//     `uvm_component_utils(fifo_env)

//     fifo_w_agent     w_agent;
//     fifo_r_agent     r_agent;
//     fifo_scoreboard  sb;
//     fifo_coverage    cov;

//     fifo_env_cfg cfg;

//     function new(string n, uvm_component p); super.new(n,p); endfunction

//     function void build_phase(uvm_phase phase);
//       super.build_phase(phase);

//       // If test didn’t provide cfg, create defaults
//       if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg)) begin
//         cfg = fifo_env_cfg::type_id::create("cfg");
//         `uvm_info("ENV", "No cfg supplied; using defaults", UVM_LOW)
//       end

//       // Create components
//       w_agent = fifo_w_agent    ::type_id::create("w_agent", this);
//       r_agent = fifo_r_agent    ::type_id::create("r_agent", this);
//       sb      = fifo_scoreboard ::type_id::create("sb", this);
//       cov     = fifo_coverage   ::type_id::create("cov", this);

//       // Propagate cfg to all descendants under env
//       uvm_config_db#(fifo_env_cfg)::set(this, "*", "cfg", cfg);
//     endfunction

//     function void connect_phase(uvm_phase phase);
//       super.connect_phase(phase);

//       // Scoreboard connections
//       w_agent.mon.ap.connect(sb.w_imp);
//       r_agent.mon.ap.connect(sb.r_imp);

//       // Coverage connections
//       w_agent.mon.ap.connect(cov.w_imp);
//       r_agent.mon.ap.connect(cov.r_imp);
//     endfunction
//   endclass

//   // ----------------------------
//   // Virtual sequencer
//   // ----------------------------
//   class fifo_vseqr extends uvm_sequencer #(uvm_sequence_item);
//     `uvm_component_utils(fifo_vseqr)
//     fifo_w_sequencer w_sqr;
//     fifo_r_sequencer r_sqr;
//     function new(string n, uvm_component p); super.new(n,p); endfunction
//   endclass

//   // ----------------------------
//   // Base virtual sequence
//   // ----------------------------
//   class fifo_base_vseq extends uvm_sequence #(uvm_sequence_item);
//     `uvm_object_utils(fifo_base_vseq)

//     fifo_vseqr    vseqr_h;
//     fifo_env_cfg  cfg;

//     function new(string name="fifo_base_vseq"); super.new(name); endfunction

//     task pre_body();
//       if (!$cast(vseqr_h, m_sequencer))
//         `uvm_fatal("VSEQ","No virtual sequencer")

//       // Fetch cfg (set by test or env)
//       if (!uvm_config_db#(fifo_env_cfg)::get(null, "*", "cfg", cfg))
//         `uvm_fatal("VSEQ","No fifo_env_cfg found in config_db")
//     endtask
//   endclass

//   // ----------------------------
//   // Concrete sequences (run on real sequencers)
//   // ----------------------------
//   class fifo_write_burst_seq extends uvm_sequence #(fifo_item);
//     `uvm_object_utils(fifo_write_burst_seq)
//     rand int unsigned n = 50;
//     function new(string name="fifo_write_burst_seq"); super.new(name); endfunction

//     task body();
//       fifo_item tr;
//       repeat (n) begin
//         tr = fifo_item::type_id::create("tr");
//         tr.op = OP_WRITE;
//         assert(tr.randomize() with { op==OP_WRITE; idle_cycles inside {[0:2]}; });
//         start_item(tr);
//         finish_item(tr);
//       end
//     endtask
//   endclass

//   class fifo_read_burst_seq extends uvm_sequence #(fifo_item);
//     `uvm_object_utils(fifo_read_burst_seq)
//     rand int unsigned n = 50;
//     function new(string name="fifo_read_burst_seq"); super.new(name); endfunction

//     task body();
//       fifo_item tr;
//       repeat (n) begin
//         tr = fifo_item::type_id::create("tr");
//         tr.op = OP_READ;
//         assert(tr.randomize() with { op==OP_READ; idle_cycles inside {[0:2]}; });
//         start_item(tr);
//         finish_item(tr);
//       end
//     endtask
//   endclass

//   class fifo_random_mix_seq extends uvm_sequence #(fifo_item);
//     `uvm_object_utils(fifo_random_mix_seq)
//     rand int unsigned n = 500;
//     function new(string name="fifo_random_mix_seq"); super.new(name); endfunction

//     task body();
//       fifo_item tr;
//       repeat (n) begin
//         tr = fifo_item::type_id::create("tr");
//         assert(tr.randomize() with { idle_cycles inside {[0:5]}; });
//         start_item(tr);
//         finish_item(tr);
//       end
//     endtask
//   endclass

//   // ----------------------------
//   // Virtual sequences (coordinate both domains)
//   // ----------------------------
//   class fifo_smoke_vseq extends fifo_base_vseq;
//     `uvm_object_utils(fifo_smoke_vseq)
//     function new(string name="fifo_smoke_vseq"); super.new(name); endfunction

//     task body();
//       fifo_write_burst_seq wseq;
//       fifo_read_burst_seq  rseq;

//       // Small deterministic smoke
//       wseq = fifo_write_burst_seq::type_id::create("wseq"); wseq.n = 40;
//       rseq = fifo_read_burst_seq ::type_id::create("rseq"); rseq.n = 40;

//       // sequential: fill a bit, then drain
//       wseq.start(vseqr_h.w_sqr);
//       rseq.start(vseqr_h.r_sqr);
//     endtask
//   endclass

//   class fifo_stress_vseq extends fifo_base_vseq;
//     `uvm_object_utils(fifo_stress_vseq)
//     function new(string name="fifo_stress_vseq"); super.new(name); endfunction

//     task body();
//       fifo_random_mix_seq wmix, rmix;

//       wmix = fifo_random_mix_seq::type_id::create("wmix");
//       rmix = fifo_random_mix_seq::type_id::create("rmix");

//       // IMPORTANT: now uses cfg.num_ops (so cfg is actually used)
//       wmix.n = cfg.num_ops;
//       rmix.n = cfg.num_ops;

//       fork
//         wmix.start(vseqr_h.w_sqr);
//         rmix.start(vseqr_h.r_sqr);
//       join
//     endtask
//   endclass

//   class fifo_fill_drain_vseq extends fifo_base_vseq;
//     `uvm_object_utils(fifo_fill_drain_vseq)
//     function new(string name="fifo_fill_drain_vseq"); super.new(name); endfunction

//     task body();
//       fifo_write_burst_seq wseq;
//       fifo_read_burst_seq  rseq;

//       wseq = fifo_write_burst_seq::type_id::create("wseq");
//       rseq = fifo_read_burst_seq ::type_id::create("rseq");

//       // Fill & drain aggressively
//       wseq.n = DEPTH * 3;
//       rseq.n = DEPTH * 3;

//       wseq.start(vseqr_h.w_sqr);
//       rseq.start(vseqr_h.r_sqr);
//     endtask
//   endclass

//   // ----------------------------
//   // Base test
//   // ----------------------------
//   class fifo_base_test extends uvm_test;
//     `uvm_component_utils(fifo_base_test)

//     fifo_env     env;
//     fifo_vseqr   vseqr;
//     fifo_env_cfg cfg;

//     virtual async_fifo_if vif;

//     function new(string n, uvm_component p); super.new(n,p); endfunction

//     function void build_phase(uvm_phase phase);
//       super.build_phase(phase);

//       // Create cfg FIRST and publish it
//       cfg = fifo_env_cfg::type_id::create("cfg");

//       // Make cfg visible to env + virtual sequences + everything
//       uvm_config_db#(fifo_env_cfg)::set(this, "*",   "cfg", cfg);
//       uvm_config_db#(fifo_env_cfg)::set(this, "env", "cfg", cfg);

//       // Create components
//       env   = fifo_env  ::type_id::create("env", this);
//       vseqr = fifo_vseqr::type_id::create("vseqr", this);

//       // Get interface
//       if (!uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::get(this,"","vif",vif))
//         `uvm_fatal("NOVIF","test missing vif")

//       // Provide vif to env children
//       uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::set(this, "env.*", "vif", vif);
//     endfunction

//     function void connect_phase(uvm_phase phase);
//       super.connect_phase(phase);
//       // Hook real sequencers into virtual sequencer
//       vseqr.w_sqr = env.w_agent.sqr;
//       vseqr.r_sqr = env.r_agent.sqr;
//     endfunction
//   endclass

// endpackage


package async_fifo_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  // ----------------------------
  // Parameters shared by TB
  // ----------------------------
  parameter int DATA_WIDTH = 32;
  parameter int ADDR_BITS  = 4;
  parameter int DEPTH      = (1 << ADDR_BITS);

  // ----------------------------
  // Transaction types
  // ----------------------------
  typedef enum {OP_WRITE, OP_READ, OP_IDLE} fifo_op_e;

  class fifo_item extends uvm_sequence_item;
    rand fifo_op_e             op;
    rand bit [DATA_WIDTH-1:0]  data;
    rand int unsigned          idle_cycles;

    `uvm_object_utils_begin(fifo_item)
      `uvm_field_enum(fifo_op_e, op, UVM_ALL_ON)
      `uvm_field_int(data, UVM_ALL_ON)
      `uvm_field_int(idle_cycles, UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name="fifo_item");
      super.new(name);
      idle_cycles = 0;
    endfunction

    constraint c_idle_small { idle_cycles inside {[0:10]}; }
    constraint c_op_dist { op dist {OP_WRITE:=45, OP_READ:=45, OP_IDLE:=10}; }
  endclass

  // Observed events from monitors
  class fifo_write_obs extends uvm_sequence_item;
    bit [DATA_WIDTH-1:0] data;
    `uvm_object_utils_begin(fifo_write_obs)
      `uvm_field_int(data, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="fifo_write_obs"); super.new(name); endfunction
  endclass

  class fifo_read_obs extends uvm_sequence_item;
    bit [DATA_WIDTH-1:0] data;
    `uvm_object_utils_begin(fifo_read_obs)
      `uvm_field_int(data, UVM_ALL_ON)
    `uvm_object_utils_end
    function new(string name="fifo_read_obs"); super.new(name); endfunction
  endclass

  // ----------------------------
  // Config
  // ----------------------------
  class fifo_env_cfg extends uvm_object;
    `uvm_object_utils(fifo_env_cfg)

    int unsigned num_ops = 2000;
    bit allow_illegal_attempts = 0;
    bit enable_assertions = 1;

    function new(string name="fifo_env_cfg");
      super.new(name);
    endfunction
  endclass

  // ----------------------------
  // Write agent
  // ----------------------------
  class fifo_w_sequencer extends uvm_sequencer #(fifo_item);
    `uvm_component_utils(fifo_w_sequencer)
    function new(string n, uvm_component p); super.new(n,p); endfunction
  endclass

  class fifo_w_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_w_driver)

    // IMPORTANT: no #(DATA_WIDTH) for Questa/UVM-1.1d robustness
    virtual async_fifo_if vif;
    fifo_env_cfg cfg;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fifo_w_driver missing vif")
      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","fifo_w_driver missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_item tr;

      vif.cb_w.w_en   <= 1'b0;
      vif.cb_w.wdata  <= '0;

      wait (vif.wrst_n === 1'b1);
      repeat (2) @(vif.cb_w);

      forever begin
        seq_item_port.get_next_item(tr);

        repeat (tr.idle_cycles) begin
          vif.cb_w.w_en <= 1'b0;
          @(vif.cb_w);
        end

        if (tr.op == OP_WRITE) begin
          if (!cfg.allow_illegal_attempts) begin
            while (vif.cb_w.wfull) begin
              vif.cb_w.w_en <= 1'b0;
              @(vif.cb_w);
            end
          end

          vif.cb_w.wdata <= tr.data;
          vif.cb_w.w_en  <= 1'b1;
          @(vif.cb_w);
          vif.cb_w.w_en  <= 1'b0;
        end else begin
          vif.cb_w.w_en <= 1'b0;
          @(vif.cb_w);
        end

        seq_item_port.item_done();
      end
    endtask
  endclass

  class fifo_w_monitor extends uvm_component;
    `uvm_component_utils(fifo_w_monitor)

    virtual async_fifo_if vif;
    uvm_analysis_port #(fifo_write_obs) ap;
    fifo_env_cfg cfg;

    function new(string n, uvm_component p);
      super.new(n,p);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fifo_w_monitor missing vif")
      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","fifo_w_monitor missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_write_obs obs;
      wait (vif.wrst_n === 1'b1);
      forever begin
        @(posedge vif.wclk);
        if (vif.w_en && !vif.wfull) begin
          obs = fifo_write_obs::type_id::create("obs");
          obs.data = vif.wdata;
          ap.write(obs);
        end
      end
    endtask
  endclass

  class fifo_w_agent extends uvm_component;
    `uvm_component_utils(fifo_w_agent)

    fifo_w_sequencer sqr;
    fifo_w_driver    drv;
    fifo_w_monitor   mon;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = fifo_w_sequencer::type_id::create("sqr", this);
      drv = fifo_w_driver   ::type_id::create("drv", this);
      mon = fifo_w_monitor  ::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ----------------------------
  // Read agent
  // ----------------------------
  class fifo_r_sequencer extends uvm_sequencer #(fifo_item);
    `uvm_component_utils(fifo_r_sequencer)
    function new(string n, uvm_component p); super.new(n,p); endfunction
  endclass

  class fifo_r_driver extends uvm_driver #(fifo_item);
    `uvm_component_utils(fifo_r_driver)

    virtual async_fifo_if vif;
    fifo_env_cfg cfg;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fifo_r_driver missing vif")
      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","fifo_r_driver missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_item tr;

      vif.cb_r.r_en <= 1'b0;

      wait (vif.rrst_n === 1'b1);
      repeat (2) @(vif.cb_r);

      forever begin
        seq_item_port.get_next_item(tr);

        repeat (tr.idle_cycles) begin
          vif.cb_r.r_en <= 1'b0;
          @(vif.cb_r);
        end

        if (tr.op == OP_READ) begin
          if (!cfg.allow_illegal_attempts) begin
            while (vif.cb_r.rempty) begin
              vif.cb_r.r_en <= 1'b0;
              @(vif.cb_r);
            end
          end

          vif.cb_r.r_en <= 1'b1;
          @(vif.cb_r);
          vif.cb_r.r_en <= 1'b0;
        end else begin
          vif.cb_r.r_en <= 1'b0;
          @(vif.cb_r);
        end

        seq_item_port.item_done();
      end
    endtask
  endclass

  class fifo_r_monitor extends uvm_component;
    `uvm_component_utils(fifo_r_monitor)

    virtual async_fifo_if vif;
    uvm_analysis_port #(fifo_read_obs) ap;
    fifo_env_cfg cfg;

    function new(string n, uvm_component p);
      super.new(n,p);
      ap = new("ap", this);
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","fifo_r_monitor missing vif")
      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","fifo_r_monitor missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_read_obs obs;
      wait (vif.rrst_n === 1'b1);
      forever begin
        @(posedge vif.rclk);
        if (vif.r_en && !vif.rempty) begin
          obs = fifo_read_obs::type_id::create("obs");
          obs.data = vif.rdata;
          ap.write(obs);
        end
      end
    endtask
  endclass

  class fifo_r_agent extends uvm_component;
    `uvm_component_utils(fifo_r_agent)

    fifo_r_sequencer sqr;
    fifo_r_driver    drv;
    fifo_r_monitor   mon;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      sqr = fifo_r_sequencer::type_id::create("sqr", this);
      drv = fifo_r_driver   ::type_id::create("drv", this);
      mon = fifo_r_monitor  ::type_id::create("mon", this);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
  endclass

  // ----------------------------
  // Scoreboard (UVM-1.1d safe): use analysis FIFOs
  // ----------------------------
  class fifo_scoreboard extends uvm_component;
    `uvm_component_utils(fifo_scoreboard)

    uvm_tlm_analysis_fifo #(fifo_write_obs) w_fifo;
    uvm_tlm_analysis_fifo #(fifo_read_obs)  r_fifo;

    fifo_env_cfg cfg;

    bit [DATA_WIDTH-1:0] exp_q[$];
    longint unsigned writes_seen;
    longint unsigned reads_seen;
    longint unsigned mismatches;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      w_fifo = new("w_fifo", this);
      r_fifo = new("r_fifo", this);

      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","scoreboard missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_write_obs wobs;
      fifo_read_obs  robs;
      bit [DATA_WIDTH-1:0] exp;

      fork
        // Consume writes
        forever begin
          w_fifo.get(wobs);
          exp_q.push_back(wobs.data);
          writes_seen++;
        end

        // Consume reads and compare
        forever begin
          r_fifo.get(robs);
          reads_seen++;

          if (exp_q.size() == 0) begin
            mismatches++;
            `uvm_error("SB", $sformatf("Read 0x%0h but expected queue empty!", robs.data))
          end else begin
            exp = exp_q.pop_front();
            if (robs.data !== exp) begin
              mismatches++;
              `uvm_error("SB", $sformatf("Mismatch: got 0x%0h exp 0x%0h", robs.data, exp))
            end
          end
        end
      join_none
    endtask

    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("SB", $sformatf("Writes=%0d Reads=%0d Mismatches=%0d ExpQ_left=%0d",
                                writes_seen, reads_seen, mismatches, exp_q.size()), UVM_LOW)
      if (mismatches != 0) `uvm_error("SB", "TEST FAILED due to mismatches")
    endfunction
  endclass

  // ----------------------------
  // Coverage (UVM-1.1d safe): also use analysis FIFOs
  // ----------------------------
  class fifo_coverage extends uvm_component;
    `uvm_component_utils(fifo_coverage)

    uvm_tlm_analysis_fifo #(fifo_write_obs) w_fifo;
    uvm_tlm_analysis_fifo #(fifo_read_obs)  r_fifo;

    virtual async_fifo_if vif;
    fifo_env_cfg cfg;
    int unsigned fill_level;

    covergroup cg_ops;
      option.per_instance = 1;

      cp_full  : coverpoint vif.wfull  { bins no={0}; bins yes={1}; }
      cp_empty : coverpoint vif.rempty { bins no={0}; bins yes={1}; }

      cp_fill : coverpoint fill_level {
        bins zero   = {0};
        bins low    = {[1:DEPTH/4]};
        bins mid    = {[DEPTH/4+1:3*DEPTH/4]};
        bins high   = {[3*DEPTH/4+1:DEPTH-1]};
        bins maxish = {DEPTH};
      }

      x_fill_full  : cross cp_fill, cp_full;
      x_fill_empty : cross cp_fill, cp_empty;
    endgroup

    function new(string n, uvm_component p);
      super.new(n,p);
      cg_ops = new();
      fill_level = 0;
    endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      w_fifo = new("w_fifo", this);
      r_fifo = new("r_fifo", this);

      if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","coverage missing vif")
      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
        `uvm_fatal("NOCFG","coverage missing cfg")
    endfunction

    task run_phase(uvm_phase phase);
      fifo_write_obs wobs;
      fifo_read_obs  robs;

      fork
        forever begin
          w_fifo.get(wobs);
          if (fill_level < DEPTH) fill_level++;
          cg_ops.sample();
        end

        forever begin
          r_fifo.get(robs);
          if (fill_level > 0) fill_level--;
          cg_ops.sample();
        end
      join_none
    endtask
  endclass

  // ----------------------------
  // Environment
  // ----------------------------
  class fifo_env extends uvm_env;
    `uvm_component_utils(fifo_env)

    fifo_w_agent     w_agent;
    fifo_r_agent     r_agent;
    fifo_scoreboard  sb;
    fifo_coverage    cov;

    fifo_env_cfg cfg;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg)) begin
        cfg = fifo_env_cfg::type_id::create("cfg");
        `uvm_info("ENV","No cfg supplied; using defaults", UVM_LOW)
      end

      w_agent = fifo_w_agent    ::type_id::create("w_agent", this);
      r_agent = fifo_r_agent    ::type_id::create("r_agent", this);
      sb      = fifo_scoreboard ::type_id::create("sb", this);
      cov     = fifo_coverage   ::type_id::create("cov", this);

      uvm_config_db#(fifo_env_cfg)::set(this, "*", "cfg", cfg);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);

      // Connect monitor APs to FIFOs
      w_agent.mon.ap.connect(sb.w_fifo.analysis_export);
      r_agent.mon.ap.connect(sb.r_fifo.analysis_export);

      w_agent.mon.ap.connect(cov.w_fifo.analysis_export);
      r_agent.mon.ap.connect(cov.r_fifo.analysis_export);
    endfunction
  endclass

  // ----------------------------
  // Virtual sequencer + sequences
  // ----------------------------
  class fifo_vseqr extends uvm_sequencer #(uvm_sequence_item);
    `uvm_component_utils(fifo_vseqr)
    fifo_w_sequencer w_sqr;
    fifo_r_sequencer r_sqr;
    function new(string n, uvm_component p); super.new(n,p); endfunction
  endclass

  class fifo_base_vseq extends uvm_sequence #(uvm_sequence_item);
    `uvm_object_utils(fifo_base_vseq)

    fifo_vseqr   vseqr_h;
    fifo_env_cfg cfg;

    function new(string name="fifo_base_vseq"); super.new(name); endfunction

    task pre_body();
      if (!$cast(vseqr_h, m_sequencer))
        `uvm_fatal("VSEQ","No virtual sequencer")
      if (!uvm_config_db#(fifo_env_cfg)::get(null, "*", "cfg", cfg))
        `uvm_fatal("VSEQ","No fifo_env_cfg found")
    endtask
  endclass

  class fifo_write_burst_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_write_burst_seq)
    rand int unsigned n = 50;
    function new(string name="fifo_write_burst_seq"); super.new(name); endfunction
    task body();
      fifo_item tr;
      repeat (n) begin
        tr = fifo_item::type_id::create("tr");
        assert(tr.randomize() with { op==OP_WRITE; idle_cycles inside {[0:2]}; });
        start_item(tr); finish_item(tr);
      end
    endtask
  endclass

  class fifo_read_burst_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_read_burst_seq)
    rand int unsigned n = 50;
    function new(string name="fifo_read_burst_seq"); super.new(name); endfunction
    task body();
      fifo_item tr;
      repeat (n) begin
        tr = fifo_item::type_id::create("tr");
        assert(tr.randomize() with { op==OP_READ; idle_cycles inside {[0:2]}; });
        start_item(tr); finish_item(tr);
      end
    endtask
  endclass

  class fifo_random_mix_seq extends uvm_sequence #(fifo_item);
    `uvm_object_utils(fifo_random_mix_seq)
    rand int unsigned n = 500;
    function new(string name="fifo_random_mix_seq"); super.new(name); endfunction
    task body();
      fifo_item tr;
      repeat (n) begin
        tr = fifo_item::type_id::create("tr");
        assert(tr.randomize() with { idle_cycles inside {[0:5]}; });
        start_item(tr); finish_item(tr);
      end
    endtask
  endclass

  class fifo_smoke_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_smoke_vseq)
    function new(string name="fifo_smoke_vseq"); super.new(name); endfunction
    task body();
      fifo_write_burst_seq wseq;
      fifo_read_burst_seq  rseq;
      wseq = fifo_write_burst_seq::type_id::create("wseq"); wseq.n = 40;
      rseq = fifo_read_burst_seq ::type_id::create("rseq"); rseq.n = 40;
      wseq.start(vseqr_h.w_sqr);
      rseq.start(vseqr_h.r_sqr);
    endtask
  endclass

  class fifo_stress_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_stress_vseq)
    function new(string name="fifo_stress_vseq"); super.new(name); endfunction
    task body();
      fifo_random_mix_seq wmix, rmix;
      wmix = fifo_random_mix_seq::type_id::create("wmix");
      rmix = fifo_random_mix_seq::type_id::create("rmix");
      wmix.n = cfg.num_ops;
      rmix.n = cfg.num_ops;
      fork
        wmix.start(vseqr_h.w_sqr);
        rmix.start(vseqr_h.r_sqr);
      join
    endtask
  endclass

  class fifo_fill_drain_vseq extends fifo_base_vseq;
    `uvm_object_utils(fifo_fill_drain_vseq)
    function new(string name="fifo_fill_drain_vseq"); super.new(name); endfunction
    task body();
      fifo_write_burst_seq wseq;
      fifo_read_burst_seq  rseq;
      wseq = fifo_write_burst_seq::type_id::create("wseq"); wseq.n = DEPTH*3;
      rseq = fifo_read_burst_seq ::type_id::create("rseq"); rseq.n = DEPTH*3;
      wseq.start(vseqr_h.w_sqr);
      rseq.start(vseqr_h.r_sqr);
    endtask
  endclass

  class fifo_base_test extends uvm_test;
    `uvm_component_utils(fifo_base_test)

    fifo_env     env;
    fifo_vseqr   vseqr;
    fifo_env_cfg cfg;

    virtual async_fifo_if vif;

    function new(string n, uvm_component p); super.new(n,p); endfunction

    function void build_phase(uvm_phase phase);
      super.build_phase(phase);

      cfg = fifo_env_cfg::type_id::create("cfg");
      uvm_config_db#(fifo_env_cfg)::set(this, "*", "cfg", cfg);

      env   = fifo_env  ::type_id::create("env", this);
      vseqr = fifo_vseqr::type_id::create("vseqr", this);

      if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
        `uvm_fatal("NOVIF","test missing vif")

      uvm_config_db#(virtual async_fifo_if)::set(this, "env.*", "vif", vif);
    endfunction

    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      vseqr.w_sqr = env.w_agent.sqr;
      vseqr.r_sqr = env.r_agent.sqr;
    endfunction
  endclass

endpackage