import axi_frontend_pkg::*;

module axi_frontend #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int STRB_WIDTH = DATA_WIDTH/8
)(
  input  logic clk,
  input  logic rstn,

  // AXI slave-side pins
  input  logic                   awvalid,
  output logic                   awready,
  input  logic [ADDR_WIDTH-1:0]  awaddr,
  input  logic [3:0]             awlen,
  input  logic [2:0]             awsize,
  input  logic [1:0]             awburst,

  input  logic                   wvalid,
  output logic                   wready,
  input  logic [DATA_WIDTH-1:0]  wdata,
  input  logic [STRB_WIDTH-1:0]  wstrb,
  input  logic                   wlast,

  output logic                   bvalid,
  input  logic                   bready,
  output logic [1:0]             bresp,

  input  logic                   arvalid,
  output logic                   arready,
  input  logic [ADDR_WIDTH-1:0]  araddr,
  input  logic [3:0]             arlen,
  input  logic [2:0]             arsize,
  input  logic [1:0]             arburst,

  output logic                   rvalid,
  input  logic                   rready,
  output logic [DATA_WIDTH-1:0]  rdata,
  output logic [1:0]             rresp,
  output logic                   rlast,

  // interface to request FIFOs
  input  logic                   aw_fifo_full,
  output logic                   aw_push,
  output aw_item_t               aw_wdata,

  input  logic                   w_fifo_full,
  output logic                   w_push,
  output w_item_t                w_wdata,

  input  logic                   ar_fifo_full,
  output logic                   ar_push,
  output ar_item_t               ar_wdata,

  // interface to read response fifo
  input  logic                   r_fifo_empty,
  input  r_item_t                r_head,
  output logic                   r_pop,

  // interface to write response generator from controller / bridge_core
  input  logic                   b_set_valid,
  output logic                   b_set_ready,
  input  logic [1:0]             b_set_resp,

  // debug
  output logic [1:0]             wr_state_dbg,
  output logic [4:0]             wr_beats_expected_dbg,
  output logic [4:0]             wr_beats_rcvd_dbg,
  output logic                   wr_req_illegal_dbg,

  output logic                   r_fire_dbg,
  output logic                   b_pending_dbg,
  output logic                   b_set_fire_dbg,
  output logic                   b_fire_dbg
);

  logic                   fe_b_set_valid;
  logic                   fe_b_set_ready;
  logic [1:0]             fe_b_set_resp;
  logic                   fe_r_set_valid;
  logic                   fe_r_set_ready;
  logic [DATA_WIDTH-1:0]  fe_r_set_data;
  logic [1:0]             fe_r_set_resp;
  logic [4:0]             fe_r_set_beats;

  axi_req_capture #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .STRB_WIDTH (STRB_WIDTH)
  ) u_axi_req_capture (
    .clk                   (clk),
    .rstn                  (rstn),
    .awvalid               (awvalid),
    .awready               (awready),
    .awaddr                (awaddr),
    .awlen                 (awlen),
    .awsize                (awsize),
    .awburst               (awburst),
    .wvalid                (wvalid),
    .wready                (wready),
    .wdata                 (wdata),
    .wstrb                 (wstrb),
    .wlast                 (wlast),
    .arvalid               (arvalid),
    .arready               (arready),
    .araddr                (araddr),
    .arlen                 (arlen),
    .arsize                (arsize),
    .arburst               (arburst),
    .aw_fifo_full          (aw_fifo_full),
    .aw_push               (aw_push),
    .aw_wdata              (aw_wdata),
    .w_fifo_full           (w_fifo_full),
    .w_push                (w_push),
    .w_wdata               (w_wdata),
    .ar_fifo_full          (ar_fifo_full),
    .ar_push               (ar_push),
    .ar_wdata              (ar_wdata),
    .illegal_wr_resp_valid (fe_b_set_valid),
    .illegal_wr_resp_ready (fe_b_set_ready),
    .illegal_wr_resp       (fe_b_set_resp),
    .illegal_rd_resp_valid (fe_r_set_valid),
    .illegal_rd_resp_ready (fe_r_set_ready),
    .illegal_rd_resp       (fe_r_set_resp),
    .illegal_rd_data       (fe_r_set_data),
    .illegal_rd_beats      (fe_r_set_beats),
    .wr_state_dbg          (wr_state_dbg),
    .wr_beats_expected_dbg (wr_beats_expected_dbg),
    .wr_beats_received_dbg (wr_beats_rcvd_dbg),
    .wr_req_illegal_dbg    (wr_req_illegal_dbg)
  );

  axi_rresp_gen #(
    .DATA_WIDTH (DATA_WIDTH)
  ) u_axi_rresp_gen (
    .clk                   (clk),
    .rstn                  (rstn),
    .r_fifo_empty          (r_fifo_empty),
    .r_head                (r_head),
    .r_pop                 (r_pop),
    .fe_set_valid          (fe_r_set_valid),
    .fe_set_ready          (fe_r_set_ready),
    .fe_set_data           (fe_r_set_data),
    .fe_set_resp           (fe_r_set_resp),
    .fe_set_beats          (fe_r_set_beats),
    .rvalid                (rvalid),
    .rready                (rready),
    .rdata                 (rdata),
    .rresp                 (rresp),
    .rlast                 (rlast),
    .r_fire_dbg            (r_fire_dbg)
  );

  axi_bresp_gen u_axi_bresp_gen (
    .clk                   (clk),
    .rstn                  (rstn),
    .set_valid             (b_set_valid),
    .set_ready             (b_set_ready),
    .set_resp              (b_set_resp),
    .fe_set_valid          (fe_b_set_valid),
    .fe_set_ready          (fe_b_set_ready),
    .fe_set_resp           (fe_b_set_resp),
    .bvalid                (bvalid),
    .bready                (bready),
    .bresp                 (bresp),
    .pending_dbg           (b_pending_dbg),
    .set_fire_dbg          (b_set_fire_dbg),
    .b_fire_dbg            (b_fire_dbg)
  );

endmodule
