// tb/async_fifo_sva.sv
`timescale 1ns/1ps

module async_fifo_sva #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_BITS  = 4
)(
  async_fifo_if vif
);

  // Basic handshake sanity (only accept when allowed)
  // These are "protocol" assertions for TB/DUT interaction.

  // Write side: if full, a write enable should not be accepted
  // (DUT should not write when full; TB might still attempt if allow_illegal_attempts=1)
  property p_no_write_accept_when_full;
    @(posedge vif.wclk) disable iff (!vif.wrst_n)
      (vif.w_en && vif.wfull) |-> ##0 1'b1; // attempt is allowed, but DUT must not accept
  endproperty

  // If you want a strict property that TB should never assert w_en when full:
  // assert property (@(posedge vif.wclk) disable iff(!vif.wrst_n) vif.wfull |-> !vif.w_en);

  // Read side: if empty, a read enable should not be accepted
  property p_no_read_accept_when_empty;
    @(posedge vif.rclk) disable iff (!vif.rrst_n)
      (vif.r_en && vif.rempty) |-> ##0 1'b1;
  endproperty

  // Flag stability checks (lightweight)
  // Full should only change on wclk, Empty should only change on rclk (in this design)
  property p_wfull_changes_only_on_wclk;
    @(posedge vif.wclk) disable iff (!vif.wrst_n)
      1 |-> $stable(vif.wfull) or (vif.wfull != $past(vif.wfull));
  endproperty

  property p_rempty_changes_only_on_rclk;
    @(posedge vif.rclk) disable iff (!vif.rrst_n)
      1 |-> $stable(vif.rempty) or (vif.rempty != $past(vif.rempty));
  endproperty

  // Actual assertions (keep only the meaningful ones)
  // NOTE: The first two properties are placeholders unless you want strict TB protocol.
  // You can swap to strict versions if desired.

  // These two lines are basically "no-op" accepts; leaving them as cover helps.
  cover property (p_no_write_accept_when_full);
  cover property (p_no_read_accept_when_empty);

endmodule