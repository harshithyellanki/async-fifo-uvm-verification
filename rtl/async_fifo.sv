module async_fifo #(
  parameter int DATA_WIDTH = 32,
  parameter int ADDR_BITS  = 4   // DEPTH = 2**ADDR_BITS
)(
  // Write domain
  input  logic                   wclk,
  input  logic                   wrst_n,     // async assert, active low
  input  logic                   w_en,
  input  logic [DATA_WIDTH-1:0]  wdata,
  output logic                   wfull,

  // Read domain
  input  logic                   rclk,
  input  logic                   rrst_n,     // async assert, active low
  input  logic                   r_en,
  output logic [DATA_WIDTH-1:0]  rdata,
  output logic                   rempty
);

  localparam int DEPTH = 1 << ADDR_BITS;

  // Storage
  logic [DATA_WIDTH-1:0] mem [0:DEPTH-1];

  // Binary pointers (ADDR_BITS+1 for full/empty detection)
  logic [ADDR_BITS:0] wptr_bin, wptr_bin_n;
  logic [ADDR_BITS:0] rptr_bin, rptr_bin_n;

  // Gray pointers
  logic [ADDR_BITS:0] wptr_gray, wptr_gray_n;
  logic [ADDR_BITS:0] rptr_gray, rptr_gray_n;

  // Synchronized gray pointers across domains (2FF)
  logic [ADDR_BITS:0] rptr_gray_wclk_q1, rptr_gray_wclk_q2;
  logic [ADDR_BITS:0] wptr_gray_rclk_q1, wptr_gray_rclk_q2;

  // ----------------------------
  // Helpers
  // ----------------------------
  function automatic logic [ADDR_BITS:0] bin2gray(input logic [ADDR_BITS:0] b);
    return (b >> 1) ^ b;
  endfunction

  // ----------------------------
  // Write-domain next state
  // ----------------------------
  always_comb begin
    wptr_bin_n  = wptr_bin;
    if (w_en && !wfull) wptr_bin_n = wptr_bin + 1'b1;
    wptr_gray_n = bin2gray(wptr_bin_n);
  end

  // Memory write
  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      // no need to clear mem for correctness
    end else if (w_en && !wfull) begin
      mem[wptr_bin[ADDR_BITS-1:0]] <= wdata;
    end
  end

  // Write pointer regs
  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wptr_bin  <= '0;
      wptr_gray <= '0;
    end else begin
      wptr_bin  <= wptr_bin_n;
      wptr_gray <= wptr_gray_n;
    end
  end

  // Sync read gray pointer into write clock domain
  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      rptr_gray_wclk_q1 <= '0;
      rptr_gray_wclk_q2 <= '0;
    end else begin
      rptr_gray_wclk_q1 <= rptr_gray;
      rptr_gray_wclk_q2 <= rptr_gray_wclk_q1;
    end
  end

  // Full detection:
  // Full when next write gray == synchronized read gray with MSBs inverted (classic async FIFO)
  logic [ADDR_BITS:0] rptr_gray_wclk_sync;
  assign rptr_gray_wclk_sync = rptr_gray_wclk_q2;

  logic [ADDR_BITS:0] wptr_gray_full_cmp;
  assign wptr_gray_full_cmp = {~rptr_gray_wclk_sync[ADDR_BITS:ADDR_BITS-1],
                               rptr_gray_wclk_sync[ADDR_BITS-2:0]};

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wfull <= 1'b0;
    end else begin
      wfull <= (wptr_gray_n == wptr_gray_full_cmp);
    end
  end

  // ----------------------------
  // Read-domain next state
  // ----------------------------
  always_comb begin
    rptr_bin_n  = rptr_bin;
    if (r_en && !rempty) rptr_bin_n = rptr_bin + 1'b1;
    rptr_gray_n = bin2gray(rptr_bin_n);
  end

  // Read pointer regs
  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rptr_bin  <= '0;
      rptr_gray <= '0;
    end else begin
      rptr_bin  <= rptr_bin_n;
      rptr_gray <= rptr_gray_n;
    end
  end

  // Sync write gray pointer into read clock domain
  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      wptr_gray_rclk_q1 <= '0;
      wptr_gray_rclk_q2 <= '0;
    end else begin
      wptr_gray_rclk_q1 <= wptr_gray;
      wptr_gray_rclk_q2 <= wptr_gray_rclk_q1;
    end
  end

  // Empty detection: empty when next read gray == synchronized write gray
  logic [ADDR_BITS:0] wptr_gray_rclk_sync;
  assign wptr_gray_rclk_sync = wptr_gray_rclk_q2;

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rempty <= 1'b1;
    end else begin
      rempty <= (rptr_gray_n == wptr_gray_rclk_sync);
    end
  end

  // Read data: registered output (typical)
  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rdata <= '0;
    end else if (r_en && !rempty) begin
      rdata <= mem[rptr_bin[ADDR_BITS-1:0]];
    end
  end

endmodule
