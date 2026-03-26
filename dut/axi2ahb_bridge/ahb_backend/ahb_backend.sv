module ahb_backend #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int STRB_WIDTH = DATA_WIDTH/8
)(
  input  logic clk,
  input  logic rstn,

  // ============================================================
  // from bridge_core
  // ============================================================
  input  logic                  beat_req_valid,
  output logic                  beat_req_ready,
  input  logic                  beat_req_write,
  input  logic                  beat_req_first,
  input  logic [ADDR_WIDTH-1:0] beat_req_addr,
  input  logic [2:0]            beat_req_size,
  input  logic [DATA_WIDTH-1:0] beat_req_wdata,
  input  logic [STRB_WIDTH-1:0] beat_req_wstrb,

  output logic                  beat_rsp_valid,
  output logic                  beat_rsp_error,
  output logic                  beat_rsp_rdata_valid,
  output logic [DATA_WIDTH-1:0] beat_rsp_rdata,

  output logic                  beat_busy_dbg,

  // ============================================================
  // AHB-Lite master side pins
  // ============================================================
  output logic [ADDR_WIDTH-1:0] haddr,
  output logic [1:0]            htrans,
  output logic                  hwrite,
  output logic [2:0]            hsize,
  output logic [2:0]            hburst,
  output logic [DATA_WIDTH-1:0] hwdata,
  output logic [STRB_WIDTH-1:0] hstrb,

  input  logic [DATA_WIDTH-1:0] hrdata,
  input  logic                  hready,
  input  logic                  hresp,

  // ============================================================
  // debug
  // ============================================================
  output logic                  inflight_dbg,
  output logic                  accepted_dbg,
  output logic                  completed_dbg,
  output logic [ADDR_WIDTH-1:0] cur_addr_dbg,
  output logic                  cur_write_dbg,
  output logic [2:0]            cur_size_dbg,
  output logic [DATA_WIDTH-1:0] cur_wdata_dbg,
  output logic [STRB_WIDTH-1:0] cur_wstrb_dbg
);

  ahb_beat_executor #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .STRB_WIDTH (STRB_WIDTH)
  ) u_ahb_beat_executor (
    .clk             (clk),
    .rstn            (rstn),

    .req_valid       (beat_req_valid),
    .req_ready       (beat_req_ready),
    .req_write       (beat_req_write),
    .req_first       (beat_req_first),
    .req_addr        (beat_req_addr),
    .req_size        (beat_req_size),
    .req_wdata       (beat_req_wdata),
    .req_wstrb       (beat_req_wstrb),

    .rsp_valid       (beat_rsp_valid),
    .rsp_error       (beat_rsp_error),
    .rsp_rdata_valid (beat_rsp_rdata_valid),
    .rsp_rdata       (beat_rsp_rdata),

    .busy            (beat_busy_dbg),

    .haddr           (haddr),
    .htrans          (htrans),
    .hwrite          (hwrite),
    .hsize           (hsize),
    .hburst          (hburst),
    .hwdata          (hwdata),
    .hstrb           (hstrb),

    .hrdata          (hrdata),
    .hready          (hready),
    .hresp           (hresp),

    .inflight_dbg    (inflight_dbg),
    .accepted_dbg    (accepted_dbg),
    .completed_dbg   (completed_dbg),
    .cur_addr_dbg    (cur_addr_dbg),
    .cur_write_dbg   (cur_write_dbg),
    .cur_size_dbg    (cur_size_dbg),
    .cur_wdata_dbg   (cur_wdata_dbg),
    .cur_wstrb_dbg   (cur_wstrb_dbg)
  );

endmodule
