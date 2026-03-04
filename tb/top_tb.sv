`timescale 1ns/1ps

module top_tb;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import async_fifo_pkg::*;
  import async_fifo_tests_pkg::*;

  async_fifo_if vif();

  async_fifo #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_BITS (ADDR_BITS)
  ) dut (
    .wclk   (vif.wclk),
    .wrst_n (vif.wrst_n),
    .w_en   (vif.w_en),
    .wdata  (vif.wdata),
    .wfull  (vif.wfull),

    .rclk   (vif.rclk),
    .rrst_n (vif.rrst_n),
    .r_en   (vif.r_en),
    .rdata  (vif.rdata),
    .rempty (vif.rempty)
  );

  // Optional: Enable/disable SVA via plusarg
  bit ENABLE_SVA = 1;
  initial void'($value$plusargs("ENABLE_SVA=%d", ENABLE_SVA));

  generate
    if (1) begin : gen_sva_block
      // We conditionally activate assertions by gating instantiation
      if (ENABLE_SVA) begin : gen_sva_on
        async_fifo_sva #(
          .DATA_WIDTH(DATA_WIDTH),
          .ADDR_BITS (ADDR_BITS)
        ) sva_i (.vif(vif));
      end
    end
  endgenerate

  // ----------------------------
  // Clocks
  // ----------------------------
  int WCLK_NS = 4;
  int RCLK_NS = 7;

  initial begin
    void'($value$plusargs("WCLK_NS=%d", WCLK_NS));
    void'($value$plusargs("RCLK_NS=%d", RCLK_NS));
  end

  initial begin
    vif.wclk = 0;
    forever #(WCLK_NS/2.0) vif.wclk = ~vif.wclk;
  end

  initial begin
    vif.rclk = 0;
    forever #(RCLK_NS/2.0) vif.rclk = ~vif.rclk;
  end

  // ----------------------------
  // Resets
  // ----------------------------
  task automatic apply_resets(int unsigned hold_cycles_w = 5,
                             int unsigned hold_cycles_r = 5);
    vif.wrst_n = 1'b0;
    vif.rrst_n = 1'b0;

    repeat (hold_cycles_w) @(posedge vif.wclk);
    repeat (hold_cycles_r) @(posedge vif.rclk);

    @(posedge vif.wclk); vif.wrst_n = 1'b1;
    @(posedge vif.rclk); vif.rrst_n = 1'b1;
  endtask

  bit INJECT_RESETS = 0;
  int RESET_GAP_MIN = 200;
  int RESET_GAP_MAX = 600;

  initial begin
    void'($value$plusargs("INJECT_RESETS=%d", INJECT_RESETS));
    void'($value$plusargs("RESET_GAP_MIN=%d", RESET_GAP_MIN));
    void'($value$plusargs("RESET_GAP_MAX=%d", RESET_GAP_MAX));
  end

  initial begin
    apply_resets();

    if (INJECT_RESETS) begin
      fork
        begin : reset_injector
          int gap;
          forever begin
            gap = $urandom_range(RESET_GAP_MIN, RESET_GAP_MAX);
            repeat (gap) @(posedge vif.wclk);
            apply_resets(2,2);
          end
        end
      join_none
    end
  end

  // ----------------------------
  // UVM start
  // ----------------------------
  initial begin
  //  uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::set(null, "*", "vif", vif);
    uvm_config_db#(virtual async_fifo_if)::set(null, "*", "vif", vif);
    run_test();
  end

endmodule