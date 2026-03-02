interface async_fifo_if #(
  parameter int DATA_WIDTH = 32
);

  // Write domain signals
  logic                  wclk;
  logic                  wrst_n;
  logic                  w_en;
  logic [DATA_WIDTH-1:0] wdata;
  logic                  wfull;

  // Read domain signals
  logic                  rclk;
  logic                  rrst_n;
  logic                  r_en;
  logic [DATA_WIDTH-1:0] rdata;
  logic                  rempty;

  // Clocking blocks for clean TB timing
  clocking cb_w @(posedge wclk);
    output w_en, wdata;
    input  wfull;
  endclocking

  clocking cb_r @(posedge rclk);
    output r_en;
    input  rempty, rdata;
  endclocking

  modport dut (
    input  wclk, wrst_n, w_en, wdata,
    output wfull,
    input  rclk, rrst_n, r_en,
    output rdata, rempty
  );

  modport tb_w (clocking cb_w, input wclk, input wrst_n);
  modport tb_r (clocking cb_r, input rclk, input rrst_n);

endinterface
