module async_fifo_sva #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_BITS  = 4
)(
  async_fifo_if #(DATA_WIDTH) vif
);

  // ----------------------------
  // Write domain assertions
  // ----------------------------
  property p_no_write_when_full;
    @(posedge vif.wclk) disable iff (!vif.wrst_n)
      (vif.w_en && vif.wfull) |-> $stable(vif.wdata);
  endproperty
  a_no_write_when_full: assert property(p_no_write_when_full)
    else $error("WRITE attempted while FULL");

  property p_wfull_only_changes_on_wclk;
    @(negedge vif.wclk) disable iff (!vif.wrst_n)
      $stable(vif.wfull);
  endproperty
  a_wfull_only_changes_on_wclk: assert property(p_wfull_only_changes_on_wclk)
    else $error("wfull changed outside posedge wclk (glitch?)");

  // ----------------------------
  // Read domain assertions
  // ----------------------------
  property p_no_read_when_empty;
    @(posedge vif.rclk) disable iff (!vif.rrst_n)
      (vif.r_en && vif.rempty) |-> 1'b1;
  endproperty
  a_no_read_when_empty: assert property(p_no_read_when_empty)
    else $error("READ attempted while EMPTY");

  property p_rempty_only_changes_on_rclk;
    @(negedge vif.rclk) disable iff (!vif.rrst_n)
      $stable(vif.rempty);
  endproperty
  a_rempty_only_changes_on_rclk: assert property(p_rempty_only_changes_on_rclk)
    else $error("rempty changed outside posedge rclk (glitch?)");

  // ----------------------------
  // Reset behavior
  // ----------------------------
  property p_reset_sets_empty;
    @(posedge vif.rclk)
      (!vif.rrst_n) |-> (vif.rempty == 1'b1);
  endproperty
  a_reset_sets_empty: assert property(p_reset_sets_empty)
    else $error("rempty not asserted during rrst_n=0");

  property p_reset_clears_full;
    @(posedge vif.wclk)
      (!vif.wrst_n) |-> (vif.wfull == 1'b0);
  endproperty
  a_reset_clears_full: assert property(p_reset_clears_full)
    else $error("wfull not deasserted during wrst_n=0");

endmodule
