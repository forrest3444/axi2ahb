module fifo_wrapper #(
  parameter int unsigned AW_DEPTH = 8,
  parameter int unsigned W_DEPTH  = 128,
  parameter int unsigned AR_DEPTH = 8,
  parameter int unsigned R_DEPTH  = 128
)(
  input  logic clk,
  input  logic rstn,

  // ============================================================
  // AW FIFO interface
  // ============================================================
  input  logic     aw_push,
  input  axi_frontend_pkg::aw_item_t aw_wdata,
  input  logic     aw_pop,
  output axi_frontend_pkg::aw_item_t aw_head,
  output logic     aw_full,
  output logic     aw_empty,
  output logic     aw_almost_full,
  output logic     aw_almost_empty,
  output logic [$clog2(AW_DEPTH+1)-1:0] aw_count,

  // ============================================================
  // W FIFO interface
  // ============================================================
  input  logic    w_push,
  input  axi_frontend_pkg::w_item_t w_wdata,
  input  logic    w_pop,
  output axi_frontend_pkg::w_item_t w_head,
  output logic    w_full,
  output logic    w_empty,
  output logic    w_almost_full,
  output logic    w_almost_empty,
  output logic [$clog2(W_DEPTH+1)-1:0] w_count,

  // ============================================================
  // AR FIFO interface
  // ============================================================
  input  logic     ar_push,
  input  axi_frontend_pkg::ar_item_t ar_wdata,
  input  logic     ar_pop,
  output axi_frontend_pkg::ar_item_t ar_head,
  output logic     ar_full,
  output logic     ar_empty,
  output logic     ar_almost_full,
  output logic     ar_almost_empty,
  output logic [$clog2(AR_DEPTH+1)-1:0] ar_count,

  // ============================================================
  // R FIFO interface
  // ============================================================
  input  logic    r_push,
  input  axi_frontend_pkg::r_item_t r_wdata,
  input  logic    r_pop,
  output axi_frontend_pkg::r_item_t r_head,
  output logic    r_full,
  output logic    r_empty,
  output logic    r_almost_full,
  output logic    r_almost_empty,
  output logic [$clog2(R_DEPTH+1)-1:0] r_count,

  // ============================================================
  // debug - AW FIFO
  // ============================================================
  output logic aw_wr_fire_dbg,
  output logic aw_rd_fire_dbg,
  output logic aw_overflow_dbg,
  output logic aw_underflow_dbg,
  output logic [$clog2(AW_DEPTH)-1:0] aw_wr_ptr_dbg,
  output logic [$clog2(AW_DEPTH)-1:0] aw_rd_ptr_dbg,
  output logic [$bits(axi_frontend_pkg::aw_item_t)-1:0] aw_head_raw_dbg,
  output logic [$bits(axi_frontend_pkg::aw_item_t)-1:0] aw_tail_raw_dbg,

  // ============================================================
  // debug - W FIFO
  // ============================================================
  output logic w_wr_fire_dbg,
  output logic w_rd_fire_dbg,
  output logic w_overflow_dbg,
  output logic w_underflow_dbg,
  output logic [$clog2(W_DEPTH)-1:0] w_wr_ptr_dbg,
  output logic [$clog2(W_DEPTH)-1:0] w_rd_ptr_dbg,
  output logic [$bits(axi_frontend_pkg::w_item_t)-1:0] w_head_raw_dbg,
  output logic [$bits(axi_frontend_pkg::w_item_t)-1:0] w_tail_raw_dbg,

  // ============================================================
  // debug - AR FIFO
  // ============================================================
  output logic ar_wr_fire_dbg,
  output logic ar_rd_fire_dbg,
  output logic ar_overflow_dbg,
  output logic ar_underflow_dbg,
  output logic [$clog2(AR_DEPTH)-1:0] ar_wr_ptr_dbg,
  output logic [$clog2(AR_DEPTH)-1:0] ar_rd_ptr_dbg,
  output logic [$bits(axi_frontend_pkg::ar_item_t)-1:0] ar_head_raw_dbg,
  output logic [$bits(axi_frontend_pkg::ar_item_t)-1:0] ar_tail_raw_dbg,

  // ============================================================
  // debug - R FIFO
  // ============================================================
  output logic r_wr_fire_dbg,
  output logic r_rd_fire_dbg,
  output logic r_overflow_dbg,
  output logic r_underflow_dbg,
  output logic [$clog2(R_DEPTH)-1:0] r_wr_ptr_dbg,
  output logic [$clog2(R_DEPTH)-1:0] r_rd_ptr_dbg,
  output logic [$bits(axi_frontend_pkg::r_item_t)-1:0] r_head_raw_dbg,
  output logic [$bits(axi_frontend_pkg::r_item_t)-1:0] r_tail_raw_dbg
);

  // ============================================================
  // local raw buses for fifo payload mapping
  // ============================================================
  logic [$bits(axi_frontend_pkg::aw_item_t)-1:0] aw_wdata_raw;
  logic [$bits(axi_frontend_pkg::aw_item_t)-1:0] aw_head_raw;

  logic [$bits(axi_frontend_pkg::w_item_t)-1:0]  w_wdata_raw;
  logic [$bits(axi_frontend_pkg::w_item_t)-1:0]  w_head_raw;

  logic [$bits(axi_frontend_pkg::ar_item_t)-1:0] ar_wdata_raw;
  logic [$bits(axi_frontend_pkg::ar_item_t)-1:0] ar_head_raw;

  logic [$bits(axi_frontend_pkg::r_item_t)-1:0]  r_wdata_raw;
  logic [$bits(axi_frontend_pkg::r_item_t)-1:0]  r_head_raw_local;

  // ============================================================
  // struct <-> raw mapping
  // ============================================================
  assign aw_wdata_raw   = aw_wdata;
  assign aw_head        = aw_head_raw;

  assign w_wdata_raw    = w_wdata;
  assign w_head         = w_head_raw;

  assign ar_wdata_raw   = ar_wdata;
  assign ar_head        = ar_head_raw;

  assign r_wdata_raw    = r_wdata;
  assign r_head         = r_head_raw_local;

  // expose raw head for debug
  assign aw_head_raw_dbg = aw_head_raw;
  assign w_head_raw_dbg  = w_head_raw;
  assign ar_head_raw_dbg = ar_head_raw;
  assign r_head_raw_dbg  = r_head_raw_local;

  // ============================================================
  // AW FIFO
  // ============================================================
  sync_fifo #(
    .DEPTH      (AW_DEPTH),
    .WIDTH      ($bits(axi_frontend_pkg::aw_item_t)),
    .AFULL_TH   ((AW_DEPTH > 1) ? (AW_DEPTH - 1) : 1),
    .AEMPTY_TH  (1)
  ) u_aw_fifo (
    .clk              (clk),
    .rstn             (rstn),

    .write_en         (aw_push),
    .data_in          (aw_wdata_raw),

    .read_en          (aw_pop),
    .data_out         (aw_head_raw),

    .full             (aw_full),
    .empty            (aw_empty),
    .almost_full      (aw_almost_full),
    .almost_empty     (aw_almost_empty),
    .count            (aw_count),

    .wr_fire          (aw_wr_fire_dbg),
    .rd_fire          (aw_rd_fire_dbg),
    .overflow_pulse   (aw_overflow_dbg),
    .underflow_pulse  (aw_underflow_dbg),

    .wr_ptr_dbg       (aw_wr_ptr_dbg),
    .rd_ptr_dbg       (aw_rd_ptr_dbg),
    .head_dbg         (),
    .tail_dbg         (aw_tail_raw_dbg)
  );

  // ============================================================
  // W FIFO
  // ============================================================
  sync_fifo #(
    .DEPTH      (W_DEPTH),
    .WIDTH      ($bits(axi_frontend_pkg::w_item_t)),
    .AFULL_TH   ((W_DEPTH > 1) ? (W_DEPTH - 1) : 1),
    .AEMPTY_TH  (1)
  ) u_w_fifo (
    .clk              (clk),
    .rstn             (rstn),

    .write_en         (w_push),
    .data_in          (w_wdata_raw),

    .read_en          (w_pop),
    .data_out         (w_head_raw),

    .full             (w_full),
    .empty            (w_empty),
    .almost_full      (w_almost_full),
    .almost_empty     (w_almost_empty),
    .count            (w_count),

    .wr_fire          (w_wr_fire_dbg),
    .rd_fire          (w_rd_fire_dbg),
    .overflow_pulse   (w_overflow_dbg),
    .underflow_pulse  (w_underflow_dbg),

    .wr_ptr_dbg       (w_wr_ptr_dbg),
    .rd_ptr_dbg       (w_rd_ptr_dbg),
    .head_dbg         (),
    .tail_dbg         (w_tail_raw_dbg)
  );

  // ============================================================
  // AR FIFO
  // ============================================================
  sync_fifo #(
    .DEPTH      (AR_DEPTH),
    .WIDTH      ($bits(axi_frontend_pkg::ar_item_t)),
    .AFULL_TH   ((AR_DEPTH > 1) ? (AR_DEPTH - 1) : 1),
    .AEMPTY_TH  (1)
  ) u_ar_fifo (
    .clk              (clk),
    .rstn             (rstn),

    .write_en         (ar_push),
    .data_in          (ar_wdata_raw),

    .read_en          (ar_pop),
    .data_out         (ar_head_raw),

    .full             (ar_full),
    .empty            (ar_empty),
    .almost_full      (ar_almost_full),
    .almost_empty     (ar_almost_empty),
    .count            (ar_count),

    .wr_fire          (ar_wr_fire_dbg),
    .rd_fire          (ar_rd_fire_dbg),
    .overflow_pulse   (ar_overflow_dbg),
    .underflow_pulse  (ar_underflow_dbg),

    .wr_ptr_dbg       (ar_wr_ptr_dbg),
    .rd_ptr_dbg       (ar_rd_ptr_dbg),
    .head_dbg         (),
    .tail_dbg         (ar_tail_raw_dbg)
  );

  // ============================================================
  // R FIFO
  // ============================================================
  sync_fifo #(
    .DEPTH      (R_DEPTH),
    .WIDTH      ($bits(axi_frontend_pkg::r_item_t)),
    .AFULL_TH   ((R_DEPTH > 1) ? (R_DEPTH - 1) : 1),
    .AEMPTY_TH  (1)
  ) u_r_fifo (
    .clk              (clk),
    .rstn             (rstn),

    .write_en         (r_push),
    .data_in          (r_wdata_raw),

    .read_en          (r_pop),
    .data_out         (r_head_raw_local),

    .full             (r_full),
    .empty            (r_empty),
    .almost_full      (r_almost_full),
    .almost_empty     (r_almost_empty),
    .count            (r_count),

    .wr_fire          (r_wr_fire_dbg),
    .rd_fire          (r_rd_fire_dbg),
    .overflow_pulse   (r_overflow_dbg),
    .underflow_pulse  (r_underflow_dbg),

    .wr_ptr_dbg       (r_wr_ptr_dbg),
    .rd_ptr_dbg       (r_rd_ptr_dbg),
    .head_dbg         (),
    .tail_dbg         (r_tail_raw_dbg)
  );

endmodule
