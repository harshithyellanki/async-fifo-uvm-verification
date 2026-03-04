// `timescale 1ns/1ps

// module top_tb;

//   import uvm_pkg::*;
//   `include "uvm_macros.svh"

//   import async_fifo_pkg::*;
//   import async_fifo_tests_pkg::*;

//   async_fifo_if vif();

//   async_fifo #(
//     .DATA_WIDTH(DATA_WIDTH),
//     .ADDR_BITS (ADDR_BITS)
//   ) dut (
//     .wclk   (vif.wclk),
//     .wrst_n (vif.wrst_n),
//     .w_en   (vif.w_en),
//     .wdata  (vif.wdata),
//     .wfull  (vif.wfull),

//     .rclk   (vif.rclk),
//     .rrst_n (vif.rrst_n),
//     .r_en   (vif.r_en),
//     .rdata  (vif.rdata),
//     .rempty (vif.rempty)
//   );

//   // Optional: Enable/disable SVA via plusarg
//   bit ENABLE_SVA = 1;
//   initial void'($value$plusargs("ENABLE_SVA=%d", ENABLE_SVA));

//   generate
//     if (1) begin : gen_sva_block
//       // We conditionally activate assertions by gating instantiation
//       if (ENABLE_SVA) begin : gen_sva_on
//         async_fifo_sva #(
//           .DATA_WIDTH(DATA_WIDTH),
//           .ADDR_BITS (ADDR_BITS)
//         ) sva_i (.vif(vif));
//       end
//     end
//   endgenerate

//   // ----------------------------
//   // Clocks
//   // ----------------------------
//   int WCLK_NS = 4;
//   int RCLK_NS = 7;

//   initial begin
//     void'($value$plusargs("WCLK_NS=%d", WCLK_NS));
//     void'($value$plusargs("RCLK_NS=%d", RCLK_NS));
//   end

//   initial begin
//     vif.wclk = 0;
//     forever #(WCLK_NS/2.0) vif.wclk = ~vif.wclk;
//   end

//   initial begin
//     vif.rclk = 0;
//     forever #(RCLK_NS/2.0) vif.rclk = ~vif.rclk;
//   end

//   // ----------------------------
//   // Resets
//   // ----------------------------
//   task automatic apply_resets(int unsigned hold_cycles_w = 5,
//                              int unsigned hold_cycles_r = 5);
//     vif.wrst_n = 1'b0;
//     vif.rrst_n = 1'b0;

//     repeat (hold_cycles_w) @(posedge vif.wclk);
//     repeat (hold_cycles_r) @(posedge vif.rclk);

//     @(posedge vif.wclk); vif.wrst_n = 1'b1;
//     @(posedge vif.rclk); vif.rrst_n = 1'b1;
//   endtask

//   bit INJECT_RESETS = 0;
//   int RESET_GAP_MIN = 200;
//   int RESET_GAP_MAX = 600;

//   initial begin
//     void'($value$plusargs("INJECT_RESETS=%d", INJECT_RESETS));
//     void'($value$plusargs("RESET_GAP_MIN=%d", RESET_GAP_MIN));
//     void'($value$plusargs("RESET_GAP_MAX=%d", RESET_GAP_MAX));
//   end

//   initial begin
//     apply_resets();

//     if (INJECT_RESETS) begin
//       fork
//         begin : reset_injector
//           int gap;
//           forever begin
//             gap = $urandom_range(RESET_GAP_MIN, RESET_GAP_MAX);
//             repeat (gap) @(posedge vif.wclk);
//             apply_resets(2,2);
//           end
//         end
//       join_none
//     end
//   end

//   // ----------------------------
//   // UVM start
//   // ----------------------------
//   initial begin
//   //  uvm_config_db#(virtual async_fifo_if#(DATA_WIDTH))::set(null, "*", "vif", vif);
//     uvm_config_db#(virtual async_fifo_if)::set(null, "*", "vif", vif);
//     run_test();
//   end

// endmodule


// `timescale 1ns/1ps

// module top_tb;

//   import uvm_pkg::*;
//   `include "uvm_macros.svh"

//   import async_fifo_pkg::*;
//   import async_fifo_tests_pkg::*;

//   // 1. Interface Instantiation
//   // Ensure the interface is instantiated with parameters matching the pkg
//   async_fifo_if vif();

//   // 2. DUT Instantiation
//   async_fifo #(
//     .DATA_WIDTH(DATA_WIDTH),
//     .ADDR_BITS (ADDR_BITS)
//   ) dut (
//     .wclk   (vif.wclk),
//     .wrst_n (vif.wrst_n),
//     .w_en   (vif.w_en),
//     .wdata  (vif.wdata),
//     .wfull  (vif.wfull),

//     .rclk   (vif.rclk),
//     .rrst_n (vif.rrst_n),
//     .r_en   (vif.r_en),
//     .rdata  (vif.rdata),
//     .rempty (vif.rempty)
//   );

//   // 3. SVA Gating
//   bit ENABLE_SVA = 1;
//   initial void'($value$plusargs("ENABLE_SVA=%d", ENABLE_SVA));

//   generate
//     if (ENABLE_SVA) begin : gen_sva_on
//       async_fifo_sva #(
//         .DATA_WIDTH(DATA_WIDTH),
//         .ADDR_BITS (ADDR_BITS)
//       ) sva_i (.vif(vif));
//     end
//   endgenerate

//   // 4. Clock Generation
//   // Using real for periods to handle division accurately (e.g., 7ns / 2 = 3.5ns)
//   real WCLK_NS = 4.0;
//   real RCLK_NS = 7.0;

//   initial begin
//     void'($value$plusargs("WCLK_NS=%f", WCLK_NS));
//     void'($value$plusargs("RCLK_NS=%f", RCLK_NS));
//   end

//   initial begin
//     vif.wclk = 0;
//     forever #(WCLK_NS/2.0) vif.wclk = ~vif.wclk;
//   end

//   initial begin
//     vif.rclk = 0;
//     forever #(RCLK_NS/2.0) vif.rclk = ~vif.rclk;
//   end

//   // 5. Reset Task
//   task automatic apply_resets(int unsigned hold_cycles_w = 5,
//                              int unsigned hold_cycles_r = 5);
//     vif.wrst_n = 1'b0;
//     vif.rrst_n = 1'b0;

//     repeat (hold_cycles_w) @(posedge vif.wclk);
//     repeat (hold_cycles_r) @(posedge vif.rclk);

//     @(posedge vif.wclk); vif.wrst_n = 1'b1;
//     @(posedge vif.rclk); vif.rrst_n = 1'b1;
//   endtask

//   bit INJECT_RESETS = 0;
//   initial begin
//     void'($value$plusargs("INJECT_RESETS=%d", INJECT_RESETS));
//     apply_resets();

//     if (INJECT_RESETS) begin
//       fork
//         forever begin
//           int gap = $urandom_range(200, 600);
//           repeat (gap) @(posedge vif.wclk);
//           apply_resets(2,2);
//         end
//       join_none
//     end
//   end

//   // 6. UVM Configuration & Start
//   initial begin
//     // Use the non-parameterized virtual interface type to match the package fix
//     uvm_config_db#(virtual async_fifo_if)::set(null, "*", "vif", vif);
    
//     // Set a timeout to prevent infinite simulation
//     uvm_top.set_report_verbosity_level(UVM_FULL);
//     uvm_top.set_timeout(10ms);
    
//     run_test();
//   end

// endmodule


// `timescale 1ns/1ps

// module top_tb;
//   import uvm_pkg::*;
//   `include "uvm_macros.svh"
//   import async_fifo_pkg::*;
//   import async_fifo_tests_pkg::*;

//   // Interface
//   async_fifo_if vif();

//   // DUT
//   async_fifo #(
//     .DATA_WIDTH(DATA_WIDTH),
//     .ADDR_BITS (ADDR_BITS)
//   ) dut (
//     .wclk(vif.wclk), .wrst_n(vif.wrst_n), .w_en(vif.w_en), .wdata(vif.wdata), .wfull(vif.wfull),
//     .rclk(vif.rclk), .rrst_n(vif.rrst_n), .r_en(vif.r_en), .rdata(vif.rdata), .rempty(vif.rempty)
//   );

//   // Clocks
//   initial begin
//     vif.wclk = 0; forever #2.0 vif.wclk = ~vif.wclk; // 4ns period
//   end
//   initial begin
//     vif.rclk = 0; forever #3.5 vif.rclk = ~vif.rclk; // 7ns period
//   end

//   // UVM Config & Run
//   initial begin
//     // Match the package's non-parameterized virtual interface
//     uvm_config_db#(virtual async_fifo_if)::set(null, "*", "vif", vif);
    
//     // Reset sequence
//     vif.wrst_n = 0; vif.rrst_n = 0;
//     #20;
//     vif.wrst_n = 1; vif.rrst_n = 1;

//     run_test();
//   end
// endmodule


// `timescale 1ns/1ps

// module top_tb;
//   import uvm_pkg::*;
//   `include "uvm_macros.svh"
//   import async_fifo_pkg::*;
//   import async_fifo_tests_pkg::*;

//   async_fifo_if vif();

//   async_fifo #(
//     .DATA_WIDTH(DATA_WIDTH),
//     .ADDR_BITS (ADDR_BITS)
//   ) dut (
//     .wclk(vif.wclk), .wrst_n(vif.wrst_n), .w_en(vif.w_en), .wdata(vif.wdata), .wfull(vif.wfull),
//     .rclk(vif.rclk), .rrst_n(vif.rrst_n), .r_en(vif.r_en), .rdata(vif.rdata), .rempty(vif.rempty)
//   );

//   initial begin
//     vif.wclk = 0; forever #2.0 vif.wclk = ~vif.wclk;
//   end
//   initial begin
//     vif.rclk = 0; forever #3.5 vif.rclk = ~vif.rclk;
//   end

//   initial begin
//     uvm_config_db#(virtual async_fifo_if)::set(null, "*", "vif", vif);
    
//     vif.wrst_n = 0; vif.rrst_n = 0;
//     #20;
//     vif.wrst_n = 1; vif.rrst_n = 1;

//     run_test();
//   end
// endmodule


// `timescale 1ns/1ps

// module top_tb;
//   import uvm_pkg::*;
//   `include "uvm_macros.svh"
//   import async_fifo_pkg::*;
//   import async_fifo_tests_pkg::*;

//   async_fifo_if vif();

//   async_fifo #(
//     .DATA_WIDTH(DATA_WIDTH),
//     .ADDR_BITS (ADDR_BITS)
//   ) dut (
//     .wclk(vif.wclk), .wrst_n(vif.wrst_n), .w_en(vif.w_en), .wdata(vif.wdata), .wfull(vif.wfull),
//     .rclk(vif.rclk), .rrst_n(vif.rrst_n), .r_en(vif.r_en), .rdata(vif.rdata), .rempty(vif.rempty)
//   );

//   initial begin
//     vif.wclk = 0; forever #2.0 vif.wclk = ~vif.wclk;
//   end
//   initial begin
//     vif.rclk = 0; forever #3.5 vif.rclk = ~vif.rclk;
//   end

//   // Reset Task
//   task automatic apply_resets(int hold_w = 5, int hold_r = 5);
//     vif.wrst_n = 0; vif.rrst_n = 0;
//     repeat(hold_w) @(posedge vif.wclk);
//     repeat(hold_r) @(posedge vif.rclk);
//     vif.wrst_n = 1; vif.rrst_n = 1;
//   endtask

//   initial begin
//     uvm_config_db#(virtual async_fifo_if)::set(null, "*", "vif", vif);
//     apply_resets();

//     // Check for Reset Injector
//     automatic bit INJECT_RESETS = 0;
//     void'($value$plusargs("INJECT_RESETS=%d", INJECT_RESETS));
//     if (INJECT_RESETS) begin
//       fork
//         forever begin
//           automatic int gap = $urandom_range(200, 600);
//           repeat (gap) @(posedge vif.wclk);
//           apply_resets(2,2);
//         end
//       join_none
//     end

//     run_test();
//   end
// endmodule


// `timescale 1ns/1ps

// module top_tb;

//   import uvm_pkg::*;
//   `include "uvm_macros.svh"

//   // Import our environment and test packages
//   import async_fifo_pkg::*;
//   import async_fifo_tests_pkg::*;

//   // 1. Interface Instantiation
//   async_fifo_if vif();

//   // 2. DUT Instantiation
//   async_fifo #(
//     .DATA_WIDTH(DATA_WIDTH),
//     .ADDR_BITS (ADDR_BITS)
//   ) dut (
//     .wclk   (vif.wclk),
//     .wrst_n (vif.wrst_n),
//     .w_en   (vif.w_en),
//     .wdata  (vif.wdata),
//     .wfull  (vif.wfull),

//     .rclk   (vif.rclk),
//     .rrst_n (vif.rrst_n),
//     .r_en   (vif.r_en),
//     .rdata  (vif.rdata),
//     .rempty (vif.rempty)
//   );

//   // 3. SVA Instantiation (Optional gating)
//   //bit ENABLE_SVA = 1;
//   localparam bit ENABLE_SVA = 1;
//   initial void'($value$plusargs("ENABLE_SVA=%d", ENABLE_SVA));

//   generate
//     if (ENABLE_SVA) begin : gen_sva_on
//       async_fifo_sva #(
//         .DATA_WIDTH(DATA_WIDTH),
//         .ADDR_BITS (ADDR_BITS)
//       ) sva_i (.vif(vif));
//     end
//   endgenerate

//   // 4. Clock Generation
//   // Using real to ensure accurate division for the 7ns clock
//   real WCLK_NS = 4.0;
//   real RCLK_NS = 7.0;

//   initial begin
//     void'($value$plusargs("WCLK_NS=%f", WCLK_NS));
//     void'($value$plusargs("RCLK_NS=%f", RCLK_NS));
//   end

//   initial begin
//     vif.wclk = 0;
//     forever #(WCLK_NS/2.0) vif.wclk = ~vif.wclk;
//   end

//   initial begin
//     vif.rclk = 0;
//     forever #(RCLK_NS/2.0) vif.rclk = ~vif.rclk;
//   end

//   // 5. Reset Task
//   task automatic apply_resets(int hold_w = 5, int hold_r = 5);
//     vif.wrst_n = 1'b0;
//     vif.rrst_n = 1'b0;
//     repeat(hold_w) @(posedge vif.wclk);
//     repeat(hold_r) @(posedge vif.rclk);
//     vif.wrst_n = 1'b1;
//     vif.rrst_n = 1'b1;
//   endtask

//   // 6. Main UVM Execution Block
//   initial begin
//     // DECLARATIONS FIRST (Fixes "Illegal declaration after statement" error)
//     automatic bit INJECT_RESETS = 0;
    
//     // UVM Configuration
//     uvm_config_db#(virtual async_fifo_if)::set(null, "*", "vif", vif);
    
//     // Initial Reset
//     apply_resets();

//     // Check for runtime reset injection
//     void'($value$plusargs("INJECT_RESETS=%d", INJECT_RESETS));
    
//     if (INJECT_RESETS) begin
//       fork
//         forever begin
//           automatic int gap = $urandom_range(200, 600);
//           repeat (gap) @(posedge vif.wclk);
//           apply_resets(2,2);
//         end
//       join_none
//     end

//     // Start UVM Test
//     run_test();
//   end

// endmodule


// `timescale 1ns/1ps

// module top_tb;

//   import uvm_pkg::*;
//   `include "uvm_macros.svh"

//   import async_fifo_pkg::*;
//   import async_fifo_tests_pkg::*;

//   // 1. Interface Instantiation
//   async_fifo_if vif();

//   // 2. DUT Instantiation
//   async_fifo #(
//     .DATA_WIDTH(DATA_WIDTH),
//     .ADDR_BITS (ADDR_BITS)
//   ) dut (
//     .wclk   (vif.wclk),
//     .wrst_n (vif.wrst_n),
//     .w_en   (vif.w_en),
//     .wdata  (vif.wdata),
//     .wfull  (vif.wfull),

//     .rclk   (vif.rclk),
//     .rrst_n (vif.rrst_n),
//     .r_en   (vif.r_en),
//     .rdata  (vif.rdata),
//     .rempty (vif.rempty)
//   );

//   // 3. Clock Generation
//   initial begin
//     vif.wclk = 0; 
//     forever #2.0 vif.wclk = ~vif.wclk; // 4ns period
//   end

//   initial begin
//     vif.rclk = 0; 
//     forever #3.5 vif.rclk = ~vif.rclk; // 7ns period
//   end

//   // 4. Reset Task
//   task automatic apply_resets(int hold_w = 5, int hold_r = 5);
//     vif.wrst_n = 1'b0;
//     vif.rrst_n = 1'b0;
//     repeat(hold_w) @(posedge vif.wclk);
//     repeat(hold_r) @(posedge vif.rclk);
//     vif.wrst_n = 1'b1;
//     vif.rrst_n = 1'b1;
//   endtask

//   // 5. Main Execution
//   initial begin
//     // Pass interface to UVM
//     uvm_config_db#(virtual async_fifo_if)::set(null, "*", "vif", vif);
    
//     // Apply initial power-on reset
//     apply_resets();

//     // Start the UVM test defined in tests_pkg
//     run_test();
//   end

// endmodule


`timescale 1ns/1ps

module top_tb;

  import uvm_pkg::*;
  `include "uvm_macros.svh"

  import async_fifo_pkg::*;
  import async_fifo_tests_pkg::*;

  // 1. Interface Instantiation
  async_fifo_if vif();

  // 2. DUT Instantiation
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

  // 3. SVA Instantiation (ENABLE_SVA removed to fix constant expression error)
  async_fifo_sva #(
    .DATA_WIDTH(DATA_WIDTH),
    .ADDR_BITS (ADDR_BITS)
  ) sva_i (.vif(vif));

  // 4. Clock Generation
  real WCLK_NS = 4.0;
  real RCLK_NS = 7.0;

  initial begin
    void'($value$plusargs("WCLK_NS=%f", WCLK_NS));
    void'($value$plusargs("RCLK_NS=%f", RCLK_NS));
  end

  initial begin
    vif.wclk = 0;
    forever #(WCLK_NS/2.0) vif.wclk = ~vif.wclk;
  end

  initial begin
    vif.rclk = 0;
    forever #(RCLK_NS/2.0) vif.rclk = ~vif.rclk;
  end

  // 5. Reset Task
  task automatic apply_resets(int hold_w = 5, int hold_r = 5);
    vif.wrst_n <= 1'b0;
    vif.rrst_n <= 1'b0;
    repeat(hold_w) @(posedge vif.wclk);
    repeat(hold_r) @(posedge vif.rclk);
    vif.wrst_n <= 1'b1;
    vif.rrst_n <= 1'b1;
  endtask

  // 6. Main UVM Execution Block
  initial begin
    automatic bit INJECT_RESETS = 0;
    
    uvm_config_db#(virtual async_fifo_if)::set(null, "*", "vif", vif);
    vif.wrst_n <= 1'b0;
    vif.rrst_n <= 1'b0;


    apply_resets();

    void'($value$plusargs("INJECT_RESETS=%d", INJECT_RESETS));
    
    if (INJECT_RESETS) begin
      fork
        forever begin
          automatic int gap = $urandom_range(200, 600);
          repeat (gap) @(posedge vif.wclk);
          apply_resets(2,2);
        end
      join_none
    end

    run_test();
  end

endmodule