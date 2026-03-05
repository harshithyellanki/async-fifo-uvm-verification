
package async_fifo_pkg;
import uvm_pkg::*;
`include "uvm_macros.svh"

// 1. Parameters
parameter int DATA_WIDTH = 32;
parameter int ADDR_BITS  = 4;
parameter int DEPTH      = (1 << ADDR_BITS);

typedef enum {OP_WRITE, OP_READ, OP_IDLE} fifo_op_e;

// 2. Configuration Class
class fifo_env_cfg extends uvm_object;
  `uvm_object_utils(fifo_env_cfg)
  int unsigned num_ops = 2000;
  bit allow_illegal_attempts = 0;
  bit enable_assertions = 1;
  function new(string name="fifo_env_cfg"); super.new(name); endfunction
endclass

// 3. Sequence Items
class fifo_item extends uvm_sequence_item;
  rand fifo_op_e             op;
  rand bit [DATA_WIDTH-1:0]  data;
  rand int unsigned          idle_cycles;
  `uvm_object_utils_begin(fifo_item)
    `uvm_field_enum(fifo_op_e, op, UVM_ALL_ON)
    `uvm_field_int(data, UVM_ALL_ON)
    `uvm_field_int(idle_cycles, UVM_ALL_ON)
  `uvm_object_utils_end
  function new(string name="fifo_item"); super.new(name); endfunction
  constraint c_idle_small { idle_cycles inside {0}; }
  constraint c_op_dist { op dist {OP_WRITE:=45, OP_READ:=45, OP_IDLE:=10}; }
endclass

class fifo_write_obs extends uvm_sequence_item;
  bit [DATA_WIDTH-1:0] data;
  `uvm_object_utils(fifo_write_obs)
  function new(string name="fifo_write_obs"); super.new(name); endfunction
endclass

class fifo_read_obs extends uvm_sequence_item;
  bit [DATA_WIDTH-1:0] data;
  `uvm_object_utils(fifo_read_obs)
  function new(string name="fifo_read_obs"); super.new(name); endfunction
endclass

// 4. Sequencer & Driver & Monitor
class fifo_w_sequencer extends uvm_sequencer #(fifo_item);
  `uvm_component_utils(fifo_w_sequencer)
  function new(string n, uvm_component p); super.new(n,p); endfunction
endclass

// class fifo_w_driver extends uvm_driver #(fifo_item);
//   `uvm_component_utils(fifo_w_driver)
//   virtual async_fifo_if vif;
//   fifo_env_cfg cfg;
//   function new(string n, uvm_component p); super.new(n,p); endfunction
//   function void build_phase(uvm_phase phase);
//     super.build_phase(phase);
//     void'(uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif));
//     void'(uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg));
//   endfunction
//   task run_phase(uvm_phase phase);
//     vif.cb_w.w_en <= 1'b0; wait(vif.wrst_n === 1'b1);
//     forever begin
//       seq_item_port.get_next_item(req);
//       repeat (req.idle_cycles) @(vif.cb_w);
//       if (req.op == OP_WRITE) begin
//         if (!cfg.allow_illegal_attempts) while (vif.cb_w.wfull) @(vif.cb_w);
//         vif.cb_w.wdata <= req.data; vif.cb_w.w_en <= 1'b1;
//         @(vif.cb_w); vif.cb_w.w_en <= 1'b0;
//       end else @(vif.cb_w);
//       seq_item_port.item_done();
//     end
//   endtask
// endclass
// 
// 
class fifo_w_driver extends uvm_driver #(fifo_item);
  `uvm_component_utils(fifo_w_driver)

  virtual async_fifo_if vif;
  fifo_env_cfg cfg;

  // ----------------------------
  // Debug counters
  // ----------------------------
  int unsigned items_seen;
  int unsigned op_write_seen, op_read_seen, op_idle_seen;

  int unsigned w_attempts;   // w_en pulses
  int unsigned w_accepted;   // w_en && !wfull
  int unsigned w_dropped;    // w_en &&  wfull

  function new(string n, uvm_component p); super.new(n,p); endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF", $sformatf("%s: missing vif", get_full_name()))
    if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG", $sformatf("%s: missing cfg", get_full_name()))
  endfunction

  task run_phase(uvm_phase phase);
    fifo_item req;

    vif.cb_w.w_en  <= 1'b0;
    vif.cb_w.wdata <= '0;

    wait (vif.wrst_n === 1'b1);
    repeat (2) @(vif.cb_w);

    forever begin
      // If reset re-asserts, re-sync outputs
      if (vif.wrst_n !== 1'b1) begin
        vif.cb_w.w_en  <= 1'b0;
        vif.cb_w.wdata <= '0;
        wait (vif.wrst_n === 1'b1);
        repeat (2) @(vif.cb_w);
      end

      seq_item_port.get_next_item(req);

      // Count item arrival + type distribution
      items_seen++;
      if ((items_seen % 100) == 0)
             `uvm_info("WDRV_CNT", $sformatf("progress items_seen=%0d w_attempts=%0d w_accepted=%0d w_dropped=%0d",
                                 items_seen, w_attempts, w_accepted, w_dropped), UVM_LOW)
      case (req.op)
        OP_WRITE: op_write_seen++;
        OP_READ : op_read_seen++;
        OP_IDLE : op_idle_seen++;
      endcase

      // idle cycles
      repeat (req.idle_cycles) begin
        vif.cb_w.w_en <= 1'b0;
        @(vif.cb_w);
      end

      if (req.op == OP_WRITE) begin
        // Attempt 1 cycle regardless of full
        vif.cb_w.wdata <= req.data;
        vif.cb_w.w_en  <= 1'b1;
        w_attempts++;

        @(vif.cb_w);

        // Handshake accounting (sampled after the edge)
        if (!vif.wfull) w_accepted++;
        else            w_dropped++;

        vif.cb_w.w_en  <= 1'b0;
      end else begin
        vif.cb_w.w_en <= 1'b0;
        @(vif.cb_w);
      end

      seq_item_port.item_done();
    end
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("WDRV_CNT",
      $sformatf("items_seen=%0d (WRITE=%0d READ=%0d IDLE=%0d) | w_attempts=%0d w_accepted=%0d w_dropped=%0d",
                items_seen, op_write_seen, op_read_seen, op_idle_seen,
                w_attempts, w_accepted, w_dropped),
      UVM_LOW)
  endfunction

endclass

class fifo_w_monitor extends uvm_component;
  `uvm_component_utils(fifo_w_monitor)
  virtual async_fifo_if vif; uvm_analysis_port #(fifo_write_obs) ap;
  function new(string n, uvm_component p); super.new(n,p); ap=new("ap",this); endfunction
  function void build_phase(uvm_phase phase);
    void'(uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif));
  endfunction
  task run_phase(uvm_phase phase);
    fifo_write_obs obs;
    forever begin @(posedge vif.wclk);

    if (vif.wrst_n !== 1'b1)  // reset active
      continue;
      if (vif.w_en && !vif.wfull) begin
        obs = fifo_write_obs::type_id::create("obs");
        obs.data = vif.wdata; ap.write(obs);
      end
    end
  endtask
endclass

class fifo_w_agent extends uvm_component;
  `uvm_component_utils(fifo_w_agent)
  fifo_w_sequencer sqr; fifo_w_driver drv; fifo_w_monitor mon;
  function new(string n, uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    sqr=fifo_w_sequencer::type_id::create("sqr",this);
    drv=fifo_w_driver::type_id::create("drv",this);
    mon=fifo_w_monitor::type_id::create("mon",this);
  endfunction
  function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(sqr.seq_item_export); endfunction
endclass

// (Similar setup for R_Agent, R_Driver, R_Monitor)
class fifo_r_sequencer extends uvm_sequencer #(fifo_item);
  `uvm_component_utils(fifo_r_sequencer)
  function new(string n, uvm_component p); super.new(n,p); endfunction
endclass

// class fifo_r_driver extends uvm_driver #(fifo_item);
//   `uvm_component_utils(fifo_r_driver)
//   virtual async_fifo_if vif; fifo_env_cfg cfg;
//   function new(string n, uvm_component p); super.new(n,p); endfunction
//   function void build_phase(uvm_phase phase);
//     void'(uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif));
//     void'(uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg));
//   endfunction
//   task run_phase(uvm_phase phase);
//     vif.cb_r.r_en <= 1'b0; wait(vif.rrst_n === 1'b1);
//     forever begin
//       seq_item_port.get_next_item(req);
//       if (req.op == OP_READ) begin
//         if (!cfg.allow_illegal_attempts) while (vif.cb_r.rempty) @(vif.cb_r);
//         vif.r_en <= 1'b1;
//         @(posedge vif.rclk);
//         vif.r_en <= 1'b0;
//       end else @(vif.cb_r);
//       seq_item_port.item_done();
//     end
//   endtask
// endclass


// class fifo_r_driver extends uvm_driver #(fifo_item);
//   `uvm_component_utils(fifo_r_driver)

//   virtual async_fifo_if vif;
//   fifo_env_cfg cfg;

//   int unsigned EMPTY_WAIT_TIMEOUT = 20000; // rclk cycles

//   function new(string n, uvm_component p);
//     super.new(n,p);
//   endfunction

//   function void build_phase(uvm_phase phase);
//     super.build_phase(phase);

//     if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
//       `uvm_fatal("NOVIF", $sformatf("%s: missing vif", get_full_name()))

//     if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
//       `uvm_fatal("NOCFG", $sformatf("%s: missing cfg", get_full_name()))
//   endfunction

//   task run_phase(uvm_phase phase);
//     fifo_item req;

//     // Default drives
//     vif.cb_r.r_en <= 1'b0;
//     vif.r_en      <= 1'b0; // if you prefer raw driving; otherwise remove

//     // Wait for reset release
//     wait (vif.rrst_n === 1'b1);
//     repeat (2) @(vif.cb_r);

//     forever begin
//       // If reset re-asserts mid-run, re-sync cleanly
//       if (vif.rrst_n !== 1'b1) begin
//         vif.cb_r.r_en <= 1'b0;
//         vif.r_en      <= 1'b0;
//         wait (vif.rrst_n === 1'b1);
//         repeat (2) @(vif.cb_r);
//       end

//       seq_item_port.get_next_item(req);

//       // Idle cycles requested by seq item
//       repeat (req.idle_cycles) begin
//         vif.cb_r.r_en <= 1'b0;
//         vif.r_en      <= 1'b0;
//         @(vif.cb_r);
//       end

//       if (req.op == OP_READ) begin
//         // In legal mode, wait until not empty (bounded)
//         if (!cfg.allow_illegal_attempts) begin
//           int unsigned wait_cnt = 0;
//           while (vif.rempty) begin
//             @(vif.cb_r);
//             wait_cnt++;
//             if (wait_cnt > EMPTY_WAIT_TIMEOUT) begin
//               `uvm_fatal("RDRV",
//                 $sformatf("Timeout waiting for rempty to deassert after %0d rclk cycles.", wait_cnt))
//             end
//             if (vif.rrst_n !== 1'b1) break;
//           end
//         end

//         // 1-cycle read pulse
//         // Prefer clocking block drive if cb_r is correct:
//         vif.cb_r.r_en <= 1'b1;
//         @(vif.cb_r);
//         vif.cb_r.r_en <= 1'b0;

//         // If you want RAW drive instead, replace above with:
//         // vif.r_en <= 1'b1; @(posedge vif.rclk); vif.r_en <= 1'b0;

//       end else begin
//         // Not a read -> do nothing for 1 cycle
//         vif.cb_r.r_en <= 1'b0;
//         @(vif.cb_r);
//       end

//       seq_item_port.item_done();
//     end
//   endtask
// endclass


// class fifo_r_driver extends uvm_driver #(fifo_item);
//   `uvm_component_utils(fifo_r_driver)

//   virtual async_fifo_if vif;
//   fifo_env_cfg cfg;

//   function new(string n, uvm_component p); super.new(n,p); endfunction

//   function void build_phase(uvm_phase phase);
//     super.build_phase(phase);
//     if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
//       `uvm_fatal("NOVIF", $sformatf("%s: missing vif", get_full_name()))
//     if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
//       `uvm_fatal("NOCFG", $sformatf("%s: missing cfg", get_full_name()))
//   endfunction

//   task run_phase(uvm_phase phase);
//     fifo_item req;

//     vif.cb_r.r_en <= 1'b0;

//     wait (vif.rrst_n === 1'b1);
//     repeat (2) @(vif.cb_r);

//     forever begin
//       if (vif.rrst_n !== 1'b1) begin
//         vif.cb_r.r_en <= 1'b0;
//         wait (vif.rrst_n === 1'b1);
//         repeat (2) @(vif.cb_r);
//       end

//       seq_item_port.get_next_item(req);

//       // idle cycles
//       repeat (req.idle_cycles) begin
//         vif.cb_r.r_en <= 1'b0;
//         @(vif.cb_r);
//       end

//       if (req.op == OP_READ) begin
//         // Attempt 1 cycle regardless of empty
//         vif.cb_r.r_en <= 1'b1;
//         @(vif.cb_r);
//         vif.cb_r.r_en <= 1'b0;
//       end else begin
//         vif.cb_r.r_en <= 1'b0;
//         @(vif.cb_r);
//       end

//       seq_item_port.item_done();
//     end
//   endtask
// endclass

class fifo_r_driver extends uvm_driver #(fifo_item);
  `uvm_component_utils(fifo_r_driver)

  virtual async_fifo_if vif;
  fifo_env_cfg cfg;

  // ----------------------------
  // Debug counters
  // ----------------------------
  int unsigned items_seen;
  int unsigned op_write_seen, op_read_seen, op_idle_seen;

  int unsigned r_attempts;   // r_en pulses
  int unsigned r_accepted;   // r_en && !rempty
  int unsigned r_dropped;    // r_en &&  rempty

  function new(string n, uvm_component p); super.new(n,p); endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF", $sformatf("%s: missing vif", get_full_name()))
    if (!uvm_config_db#(fifo_env_cfg)::get(this,"","cfg",cfg))
      `uvm_fatal("NOCFG", $sformatf("%s: missing cfg", get_full_name()))
  endfunction

  task run_phase(uvm_phase phase);
    fifo_item req;

    vif.cb_r.r_en <= 1'b0;

    wait (vif.rrst_n === 1'b1);
    repeat (2) @(vif.cb_r);

    forever begin
      if (vif.rrst_n !== 1'b1) begin
        vif.cb_r.r_en <= 1'b0;
        wait (vif.rrst_n === 1'b1);
        repeat (2) @(vif.cb_r);
      end

      seq_item_port.get_next_item(req);

      // Count item arrival + type distribution
      items_seen++;

      if ((items_seen % 100) == 0)
            `uvm_info("RDRV_CNT", $sformatf("progress items_seen=%0d r_attempts=%0d r_accepted=%0d r_dropped=%0d",
                                 items_seen, r_attempts, r_accepted, r_dropped), UVM_LOW)
      case (req.op)
        OP_WRITE: op_write_seen++;
        OP_READ : op_read_seen++;
        OP_IDLE : op_idle_seen++;
      endcase

      // idle cycles
      repeat (req.idle_cycles) begin
        vif.cb_r.r_en <= 1'b0;
        @(vif.cb_r);
      end

      if (req.op == OP_READ) begin
        // Attempt 1 cycle regardless of empty
        vif.cb_r.r_en <= 1'b1;
        r_attempts++;

        @(vif.cb_r);

        // Handshake accounting
        if (!vif.rempty) r_accepted++;
        else             r_dropped++;

        vif.cb_r.r_en <= 1'b0;
      end else begin
        vif.cb_r.r_en <= 1'b0;
        @(vif.cb_r);
      end

      seq_item_port.item_done();
    end
  endtask

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info("RDRV_CNT",
      $sformatf("items_seen=%0d (WRITE=%0d READ=%0d IDLE=%0d) | r_attempts=%0d r_accepted=%0d r_dropped=%0d",
                items_seen, op_write_seen, op_read_seen, op_idle_seen,
                r_attempts, r_accepted, r_dropped),
      UVM_LOW)
  endfunction

endclass

// class fifo_r_monitor extends uvm_component;
//   `uvm_component_utils(fifo_r_monitor)
//   virtual async_fifo_if vif; uvm_analysis_port #(fifo_read_obs) ap;
//   function new(string n, uvm_component p); super.new(n,p); ap=new("ap",this); endfunction
//   function void build_phase(uvm_phase phase);
//     void'(uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif));
//   endfunction
//   task run_phase(uvm_phase phase);
//     fifo_read_obs obs;
//     forever begin @(posedge vif.rclk);
//       if (vif.r_en && !vif.rempty) begin
//         obs = fifo_read_obs::type_id::create("obs");
//         obs.data = vif.rdata; ap.write(obs);
//       end
//     end
//   endtask
// endclass

class fifo_r_monitor extends uvm_component;
  `uvm_component_utils(fifo_r_monitor)

  virtual async_fifo_if vif;
  uvm_analysis_port #(fifo_read_obs) ap;

  function new(string n, uvm_component p);
    super.new(n,p);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","fifo_r_monitor missing vif")
  endfunction

  task run_phase(uvm_phase phase);
    fifo_read_obs obs;

    // 1-cycle pipeline flag: "a read was accepted in the previous cycle"
    bit prev_read_accept;
    prev_read_accept = 0;

    // Optional: wait for reset deassert if you want clean start
    wait (vif.rrst_n === 1'b1);

    forever begin
      @(posedge vif.rclk);

      // If reset is asserted, clear pipeline and skip
      if (vif.rrst_n !== 1'b1) begin
        prev_read_accept = 0;
        continue;
      end

      // If a read was accepted last cycle, rdata is valid now
      if (prev_read_accept) begin
        obs = fifo_read_obs::type_id::create("obs", this);
        obs.data = vif.rdata;
        ap.write(obs);
      end

      // Update pipeline for next cycle
      prev_read_accept = (vif.r_en && !vif.rempty);
    end
  endtask

endclass

class fifo_r_agent extends uvm_component;
  `uvm_component_utils(fifo_r_agent)
  fifo_r_sequencer sqr; fifo_r_driver drv; fifo_r_monitor mon;
  function new(string n, uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    sqr=fifo_r_sequencer::type_id::create("sqr",this);
    drv=fifo_r_driver::type_id::create("drv",this);
    mon=fifo_r_monitor::type_id::create("mon",this);
  endfunction
  function void connect_phase(uvm_phase phase); drv.seq_item_port.connect(sqr.seq_item_export); endfunction
endclass

// 5. Scoreboard & Env
// class fifo_scoreboard extends uvm_component;
//   `uvm_component_utils(fifo_scoreboard)
//   uvm_tlm_analysis_fifo #(fifo_write_obs) w_fifo;
//   uvm_tlm_analysis_fifo #(fifo_read_obs)  r_fifo;
//   bit [DATA_WIDTH-1:0] exp_q[$];
//   function new(string n, uvm_component p); super.new(n,p); w_fifo=new("w_fifo",this); r_fifo=new("r_fifo",this); endfunction
  // task run_phase(uvm_phase phase);
  //   fifo_write_obs wobs; fifo_read_obs robs;
  //   fork
  //     forever begin w_fifo.get(wobs); exp_q.push_back(wobs.data); end
  //     forever begin r_fifo.get(robs); 
  //       if (exp_q.size() > 0) begin
  //         bit [DATA_WIDTH-1:0] exp = exp_q.pop_front();
  //         if (robs.data !== exp) `uvm_error("SB", "Mismatch")
  //       end
  //     end
  //   join_none
  // endtask

//   task run_phase(uvm_phase phase);
//   fifo_write_obs wobs; 
//   fifo_read_obs  robs;
  
//   fork
//     // Write Loop
//     forever begin 
//       w_fifo.get(wobs); 
//       exp_q.push_back(wobs.data); 
//       `uvm_info("SB_WRITE", $sformatf("Captured Write Data: %h", wobs.data), UVM_HIGH)
//     end
    
//     // Read Loop
//     forever begin 
//       r_fifo.get(robs); 
//       // Ensure the write side has had a delta-cycle to update the queue
//       wait(exp_q.size() > 0); 
//       begin
//         bit [DATA_WIDTH-1:0] exp = exp_q.pop_front();
//         if (robs.data !== exp) begin
//           `uvm_error("SB_MISMATCH", $sformatf("Mismatch! Got:%h Exp:%h", robs.data, exp))
//         end else begin
//           `uvm_info("SB_MATCH", $sformatf("Match: %h", robs.data), UVM_LOW)
//         end
//       end
//     end
//   join_none
// endtask
// endclass

class fifo_scoreboard extends uvm_component;
  `uvm_component_utils(fifo_scoreboard)

  uvm_tlm_analysis_fifo #(fifo_write_obs) w_fifo;
  uvm_tlm_analysis_fifo #(fifo_read_obs)  r_fifo;

  virtual async_fifo_if vif;

  bit [DATA_WIDTH-1:0] exp_q[$];

  function new(string n, uvm_component p);
    super.new(n,p);
    w_fifo = new("w_fifo", this);
    r_fifo = new("r_fifo", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(virtual async_fifo_if)::get(this,"","vif",vif))
      `uvm_fatal("NOVIF","fifo_scoreboard missing vif")
  endfunction

  task run_phase(uvm_phase phase);
    fifo_write_obs wobs;
    fifo_read_obs  robs;

    fork
      // ---------------------------------------
      // Reset watcher: flush model on reset
      // ---------------------------------------
      forever begin
        @(negedge vif.wrst_n or negedge vif.rrst_n);
        exp_q.delete();
        `uvm_info("SB_RST", "Reset detected -> flushed expected queue", UVM_LOW)

        // wait until both resets are deasserted
        wait (vif.wrst_n === 1'b1 && vif.rrst_n === 1'b1);

        // CDC settle: give a couple clocks on each side
        repeat (2) @(posedge vif.wclk);
        repeat (2) @(posedge vif.rclk);

        `uvm_info("SB_RST", "Post-reset settle done", UVM_LOW)
      end

      // ---------------------------------------
      // Write Loop: push expected on accepted writes
      // ---------------------------------------
      forever begin
        w_fifo.get(wobs);

        // ignore while in reset
        if (vif.wrst_n !== 1'b1 || vif.rrst_n !== 1'b1)
          continue;

        exp_q.push_back(wobs.data);
        `uvm_info("SB_WRITE", $sformatf("Captured Write Data: %h (qsize=%0d)", wobs.data, exp_q.size()), UVM_HIGH)
      end

      // ---------------------------------------
      // Read Loop: compare in order
      // ---------------------------------------
      forever begin
        r_fifo.get(robs);

        // ignore while in reset
        if (vif.wrst_n !== 1'b1 || vif.rrst_n !== 1'b1)
          continue;

        if (exp_q.size() == 0) begin
          `uvm_error("SB_UNDERFLOW", $sformatf("Read %h but expected queue empty", robs.data))
        end else begin
          bit [DATA_WIDTH-1:0] exp = exp_q.pop_front();
          if (robs.data !== exp) begin
            `uvm_error("SB_MISMATCH", $sformatf("Mismatch! Got:%h Exp:%h (qsize_after=%0d)",
                                               robs.data, exp, exp_q.size()))
          end else begin
            `uvm_info("SB_MATCH", $sformatf("Match: %h", robs.data), UVM_LOW)
          end
        end
      end
    join_none
  endtask

endclass

class fifo_env extends uvm_env;
  `uvm_component_utils(fifo_env)
  fifo_w_agent w_agent; fifo_r_agent r_agent; fifo_scoreboard sb;
  function new(string n, uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    w_agent = fifo_w_agent::type_id::create("w_agent", this);
    r_agent = fifo_r_agent::type_id::create("r_agent", this);
    sb = fifo_scoreboard::type_id::create("sb", this);
  endfunction
  function void connect_phase(uvm_phase phase);
    w_agent.mon.ap.connect(sb.w_fifo.analysis_export);
    r_agent.mon.ap.connect(sb.r_fifo.analysis_export);
  endfunction
endclass

// 6. Virtual Sequencer & Sequences
class fifo_vseqr extends uvm_sequencer #(uvm_sequence_item);
  `uvm_component_utils(fifo_vseqr)
  fifo_w_sequencer w_sqr; fifo_r_sequencer r_sqr;
  function new(string n, uvm_component p); super.new(n,p); endfunction
endclass

class fifo_base_vseq extends uvm_sequence #(uvm_sequence_item);
  `uvm_object_utils(fifo_base_vseq)
  fifo_vseqr vseqr_h; fifo_env_cfg cfg;
  function new(string n="fifo_base_vseq"); super.new(n); endfunction
  task pre_body();
    if (!$cast(vseqr_h, m_sequencer)) `uvm_fatal("VSEQ","Cast Failed")
    if (!uvm_config_db#(fifo_env_cfg)::get(null, "*", "cfg", cfg)) `uvm_fatal("VSEQ","No Cfg")
  endtask
endclass

class fifo_write_burst_seq extends uvm_sequence #(fifo_item);
  `uvm_object_utils(fifo_write_burst_seq)
  int n = 50; function new(string name="fifo_write_burst_seq"); super.new(name); endfunction
  task body();
    repeat (n) begin
      fifo_item tr = fifo_item::type_id::create("tr");
      assert(tr.randomize() with { op==OP_WRITE; });
      start_item(tr); finish_item(tr);
    end
  endtask
endclass

class fifo_read_burst_seq extends uvm_sequence #(fifo_item);
  `uvm_object_utils(fifo_read_burst_seq)
  int n = 50; function new(string name="fifo_read_burst_seq"); super.new(name); endfunction
  task body();
    repeat (n) begin
      fifo_item tr = fifo_item::type_id::create("tr");
      assert(tr.randomize() with { op==OP_READ; });
      start_item(tr); finish_item(tr);
    end
  endtask
endclass

class fifo_random_mix_seq extends uvm_sequence #(fifo_item);
  `uvm_object_utils(fifo_random_mix_seq)
  int n = 500; function new(string name="fifo_random_mix_seq"); super.new(name); endfunction
  task body();
    repeat (n) begin
      fifo_item tr = fifo_item::type_id::create("tr");
      assert(tr.randomize()); start_item(tr); finish_item(tr);
    end
  endtask
endclass

class fifo_smoke_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_smoke_vseq)
  function new(string name="fifo_smoke_vseq"); super.new(name); endfunction
  task body();
    fifo_write_burst_seq wseq = fifo_write_burst_seq::type_id::create("wseq");
    fifo_read_burst_seq  rseq = fifo_read_burst_seq ::type_id::create("rseq");
    wseq.n = 40; rseq.n = 40;
    fork
      wseq.start(vseqr_h.w_sqr);
    join
    
    fork
      rseq.start(vseqr_h.r_sqr);
    join
  endtask
endclass

class fifo_stress_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_stress_vseq)
  function new(string name="fifo_stress_vseq"); super.new(name); endfunction
  task body();
    fifo_random_mix_seq wmix = fifo_random_mix_seq::type_id::create("wmix");
    fifo_random_mix_seq rmix = fifo_random_mix_seq::type_id::create("rmix");
    wmix.n = cfg.num_ops; rmix.n = cfg.num_ops;
    fork wmix.start(vseqr_h.w_sqr); rmix.start(vseqr_h.r_sqr); join
  endtask
endclass

class fifo_fill_drain_vseq extends fifo_base_vseq;
  `uvm_object_utils(fifo_fill_drain_vseq)
  function new(string name="fifo_fill_drain_vseq"); super.new(name); endfunction
  task body();
    fifo_write_burst_seq wseq = fifo_write_burst_seq::type_id::create("wseq");
    fifo_read_burst_seq  rseq = fifo_read_burst_seq ::type_id::create("rseq");
    wseq.n = DEPTH * 3; rseq.n = DEPTH * 3;
    wseq.start(vseqr_h.w_sqr); 
    rseq.start(vseqr_h.r_sqr);
  endtask
endclass

// 7. Base Test
class fifo_base_test extends uvm_test;
  `uvm_component_utils(fifo_base_test)
  fifo_env env; fifo_vseqr vseqr; fifo_env_cfg cfg; virtual async_fifo_if vif;
  function new(string n, uvm_component p); super.new(n,p); endfunction
  function void build_phase(uvm_phase phase);
    cfg = fifo_env_cfg::type_id::create("cfg");
    uvm_config_db#(fifo_env_cfg)::set(null, "*", "cfg", cfg);
    env = fifo_env::type_id::create("env", this);
    vseqr = fifo_vseqr::type_id::create("vseqr", this);
    if(!uvm_config_db#(virtual async_fifo_if)::get(this, "", "vif", vif)) `uvm_fatal("TEST", "No VIF")
  endfunction
  function void connect_phase(uvm_phase phase);
    vseqr.w_sqr = env.w_agent.sqr; vseqr.r_sqr = env.r_agent.sqr;
  endfunction
endclass

endpackage