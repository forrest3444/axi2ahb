import axi_frontend_pkg::*;

module axi2ahb_bridge_top #(
  parameter int unsigned ADDR_WIDTH = 32,
  parameter int unsigned DATA_WIDTH = 32,
  parameter int unsigned STRB_WIDTH = DATA_WIDTH/8,

  parameter int unsigned AW_DEPTH = 8,
  parameter int unsigned W_DEPTH  = 128,
  parameter int unsigned AR_DEPTH = 8,
  parameter int unsigned R_DEPTH  = 128,

  parameter int LEN_WIDTH      = 4,
  parameter int W_COUNT_WIDTH  = $clog2(W_DEPTH+1),
  parameter int R_COUNT_WIDTH  = $clog2(R_DEPTH+1)
)(
  input  logic clk,
  input  logic rstn,

  // ============================================================
  // AXI slave-side pins
  // ============================================================
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

  // ============================================================
  // AHB-Lite master-side pins
  // ============================================================
  output logic [ADDR_WIDTH-1:0]  haddr,
  output logic [1:0]             htrans,
  output logic                   hwrite,
  output logic [2:0]             hsize,
  output logic [2:0]             hburst,
  output logic [DATA_WIDTH-1:0]  hwdata,
  output logic [STRB_WIDTH-1:0]  hstrb,

  input  logic [DATA_WIDTH-1:0]  hrdata,
  input  logic                   hready,
  input  logic                   hresp
);

  // ============================================================
  // internal interconnect: AXI frontend <-> FIFOs
  // ============================================================
  logic     aw_push;
  aw_item_t aw_wdata;
  logic     aw_pop;
  aw_item_t aw_head;
  logic     aw_full;
  logic     aw_empty;
  logic     aw_almost_full;
  logic     aw_almost_empty;
  logic [$clog2(AW_DEPTH+1)-1:0] aw_count;

  logic    w_push;
  w_item_t w_wdata;
  logic    w_pop;
  w_item_t w_head;
  logic    w_full;
  logic    w_empty;
  logic    w_almost_full;
  logic    w_almost_empty;
  logic [$clog2(W_DEPTH+1)-1:0] w_count;

  logic     ar_push;
  ar_item_t ar_wdata;
  logic     ar_pop;
  ar_item_t ar_head;
  logic     ar_full;
  logic     ar_empty;
  logic     ar_almost_full;
  logic     ar_almost_empty;
  logic [$clog2(AR_DEPTH+1)-1:0] ar_count;

  logic    r_push;
  r_item_t r_wdata;
  logic    r_pop;
  r_item_t r_head;
  logic    r_full;
  logic    r_empty;
  logic    r_almost_full;
  logic    r_almost_empty;
  logic [$clog2(R_DEPTH+1)-1:0] r_count;

  // ============================================================
  // internal interconnect: bridge_core <-> axi_frontend
  // ============================================================
  logic       b_set_valid;
  logic       b_set_ready;
  logic [1:0] b_set_resp;

  // ============================================================
  // internal interconnect: bridge_core <-> ahb_backend
  // ============================================================
  logic                  beat_req_valid;
  logic                  beat_req_ready;
  logic                  beat_req_write;
  logic                  beat_req_first;
  logic [ADDR_WIDTH-1:0] beat_req_addr;
  logic [2:0]            beat_req_size;
  logic [DATA_WIDTH-1:0] beat_req_wdata;
  logic [STRB_WIDTH-1:0] beat_req_wstrb;

  logic                  beat_rsp_valid;
  logic                  beat_rsp_error;
  logic                  beat_rsp_rdata_valid;
  logic [DATA_WIDTH-1:0] beat_rsp_rdata;

  // ============================================================
  // retained debug wires
  // ============================================================
  logic [1:0] frontend_wr_state_dbg;
  logic [4:0] frontend_wr_beats_expected_dbg;
  logic [4:0] frontend_wr_beats_rcvd_dbg;
  logic       frontend_wr_req_illegal_dbg;
  logic       frontend_r_fire_dbg;
  logic       frontend_b_pending_dbg;
  logic       frontend_b_set_fire_dbg;
  logic       frontend_b_fire_dbg;

  logic       aw_wr_fire_dbg;
  logic       aw_rd_fire_dbg;
  logic       aw_overflow_dbg;
  logic       aw_underflow_dbg;
  logic [$clog2(AW_DEPTH)-1:0] aw_wr_ptr_dbg;
  logic [$clog2(AW_DEPTH)-1:0] aw_rd_ptr_dbg;
  logic [$bits(aw_item_t)-1:0] aw_head_raw_dbg;
  logic [$bits(aw_item_t)-1:0] aw_tail_raw_dbg;

  logic       w_wr_fire_dbg;
  logic       w_rd_fire_dbg;
  logic       w_overflow_dbg;
  logic       w_underflow_dbg;
  logic [$clog2(W_DEPTH)-1:0] w_wr_ptr_dbg;
  logic [$clog2(W_DEPTH)-1:0] w_rd_ptr_dbg;
  logic [$bits(w_item_t)-1:0] w_head_raw_dbg;
  logic [$bits(w_item_t)-1:0] w_tail_raw_dbg;

  logic       ar_wr_fire_dbg;
  logic       ar_rd_fire_dbg;
  logic       ar_overflow_dbg;
  logic       ar_underflow_dbg;
  logic [$clog2(AR_DEPTH)-1:0] ar_wr_ptr_dbg;
  logic [$clog2(AR_DEPTH)-1:0] ar_rd_ptr_dbg;
  logic [$bits(ar_item_t)-1:0] ar_head_raw_dbg;
  logic [$bits(ar_item_t)-1:0] ar_tail_raw_dbg;

  logic       r_wr_fire_dbg;
  logic       r_rd_fire_dbg;
  logic       r_overflow_dbg;
  logic       r_underflow_dbg;
  logic [$clog2(R_DEPTH)-1:0] r_wr_ptr_dbg;
  logic [$clog2(R_DEPTH)-1:0] r_rd_ptr_dbg;
  logic [$bits(r_item_t)-1:0] r_head_raw_dbg;
  logic [$bits(r_item_t)-1:0] r_tail_raw_dbg;

  logic       core_accept_enable_dbg;
  logic       core_ctrl_busy_dbg;
  logic       core_grant_valid_dbg;
  logic       core_grant_wr_dbg;
  logic       core_grant_rd_dbg;
  logic       core_grant_accept_dbg;
  logic       core_wr_present_dbg;
  logic       core_rd_present_dbg;
  logic       core_wr_issue_ok_dbg;
  logic       core_rd_issue_ok_dbg;
  logic       core_wr_candidate_dbg;
  logic       core_rd_candidate_dbg;
  logic [LEN_WIDTH:0] core_wr_beats_dbg;
  logic [LEN_WIDTH:0] core_rd_beats_dbg;
  logic [LEN_WIDTH:0] core_wr_need_beats_dbg;
  logic [LEN_WIDTH:0] core_rd_need_slots_dbg;
  logic [R_COUNT_WIDTH-1:0] core_r_free_slots_dbg;
  logic       core_wr_payload_ready_dbg;
  logic       core_rd_resp_space_ready_dbg;
  logic       core_wr_illegal_fifo_dbg;
  logic       core_rd_illegal_fifo_dbg;
  logic [2:0] core_wr_block_reason_dbg;
  logic [2:0] core_rd_block_reason_dbg;
  logic       core_last_grant_dbg;
  logic [1:0] core_arb_state_dbg;
  logic       core_tie_break_dbg;
  logic [2:0] core_ctrl_state_dbg;
  logic       core_active_dir_dbg;
  logic [4:0] core_beat_idx_dbg;
  logic [4:0] core_beat_total_dbg;
  logic [ADDR_WIDTH-1:0] core_cur_addr_dbg;
  logic       core_active_illegal_dbg;
  logic       core_error_seen_dbg;
  logic       core_beat_launch_fire_dbg;
  logic       core_beat_inflight_dbg;
  logic       core_beat_complete_dbg;
  logic       core_contract_violation_dbg;
  logic [3:0] core_violation_code_dbg;

  logic       backend_busy_dbg;
  logic       backend_inflight_dbg;
  logic       backend_accepted_dbg;
  logic       backend_completed_dbg;
  logic [ADDR_WIDTH-1:0] backend_cur_addr_dbg;
  logic       backend_cur_write_dbg;
  logic [2:0] backend_cur_size_dbg;
  logic [DATA_WIDTH-1:0] backend_cur_wdata_dbg;
  logic [STRB_WIDTH-1:0] backend_cur_wstrb_dbg;

  axi_frontend #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .STRB_WIDTH (STRB_WIDTH)
  ) u_axi_frontend (
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

    .bvalid                (bvalid),
    .bready                (bready),
    .bresp                 (bresp),

    .arvalid               (arvalid),
    .arready               (arready),
    .araddr                (araddr),
    .arlen                 (arlen),
    .arsize                (arsize),
    .arburst               (arburst),

    .rvalid                (rvalid),
    .rready                (rready),
    .rdata                 (rdata),
    .rresp                 (rresp),
    .rlast                 (rlast),

    .aw_fifo_full          (aw_full),
    .aw_push               (aw_push),
    .aw_wdata              (aw_wdata),
    .w_fifo_full           (w_full),
    .w_push                (w_push),
    .w_wdata               (w_wdata),
    .ar_fifo_full          (ar_full),
    .ar_push               (ar_push),
    .ar_wdata              (ar_wdata),
    .r_fifo_empty          (r_empty),
    .r_head                (r_head),
    .r_pop                 (r_pop),
    .b_set_valid           (b_set_valid),
    .b_set_ready           (b_set_ready),
    .b_set_resp            (b_set_resp),
    .wr_state_dbg          (frontend_wr_state_dbg),
    .wr_beats_expected_dbg (frontend_wr_beats_expected_dbg),
    .wr_beats_rcvd_dbg     (frontend_wr_beats_rcvd_dbg),
    .wr_req_illegal_dbg    (frontend_wr_req_illegal_dbg),
    .r_fire_dbg            (frontend_r_fire_dbg),
    .b_pending_dbg         (frontend_b_pending_dbg),
    .b_set_fire_dbg        (frontend_b_set_fire_dbg),
    .b_fire_dbg            (frontend_b_fire_dbg)
  );

  fifo_wrapper #(
    .AW_DEPTH (AW_DEPTH),
    .W_DEPTH  (W_DEPTH),
    .AR_DEPTH (AR_DEPTH),
    .R_DEPTH  (R_DEPTH)
  ) u_fifo_wrapper (
    .clk                   (clk),
    .rstn                  (rstn),
    .aw_push               (aw_push),
    .aw_wdata              (aw_wdata),
    .aw_pop                (aw_pop),
    .aw_head               (aw_head),
    .aw_full               (aw_full),
    .aw_empty              (aw_empty),
    .aw_almost_full        (aw_almost_full),
    .aw_almost_empty       (aw_almost_empty),
    .aw_count              (aw_count),
    .w_push                (w_push),
    .w_wdata               (w_wdata),
    .w_pop                 (w_pop),
    .w_head                (w_head),
    .w_full                (w_full),
    .w_empty               (w_empty),
    .w_almost_full         (w_almost_full),
    .w_almost_empty        (w_almost_empty),
    .w_count               (w_count),
    .ar_push               (ar_push),
    .ar_wdata              (ar_wdata),
    .ar_pop                (ar_pop),
    .ar_head               (ar_head),
    .ar_full               (ar_full),
    .ar_empty              (ar_empty),
    .ar_almost_full        (ar_almost_full),
    .ar_almost_empty       (ar_almost_empty),
    .ar_count              (ar_count),
    .r_push                (r_push),
    .r_wdata               (r_wdata),
    .r_pop                 (r_pop),
    .r_head                (r_head),
    .r_full                (r_full),
    .r_empty               (r_empty),
    .r_almost_full         (r_almost_full),
    .r_almost_empty        (r_almost_empty),
    .r_count               (r_count),
    .aw_wr_fire_dbg        (aw_wr_fire_dbg),
    .aw_rd_fire_dbg        (aw_rd_fire_dbg),
    .aw_overflow_dbg       (aw_overflow_dbg),
    .aw_underflow_dbg      (aw_underflow_dbg),
    .aw_wr_ptr_dbg         (aw_wr_ptr_dbg),
    .aw_rd_ptr_dbg         (aw_rd_ptr_dbg),
    .aw_head_raw_dbg       (aw_head_raw_dbg),
    .aw_tail_raw_dbg       (aw_tail_raw_dbg),
    .w_wr_fire_dbg         (w_wr_fire_dbg),
    .w_rd_fire_dbg         (w_rd_fire_dbg),
    .w_overflow_dbg        (w_overflow_dbg),
    .w_underflow_dbg       (w_underflow_dbg),
    .w_wr_ptr_dbg          (w_wr_ptr_dbg),
    .w_rd_ptr_dbg          (w_rd_ptr_dbg),
    .w_head_raw_dbg        (w_head_raw_dbg),
    .w_tail_raw_dbg        (w_tail_raw_dbg),
    .ar_wr_fire_dbg        (ar_wr_fire_dbg),
    .ar_rd_fire_dbg        (ar_rd_fire_dbg),
    .ar_overflow_dbg       (ar_overflow_dbg),
    .ar_underflow_dbg      (ar_underflow_dbg),
    .ar_wr_ptr_dbg         (ar_wr_ptr_dbg),
    .ar_rd_ptr_dbg         (ar_rd_ptr_dbg),
    .ar_head_raw_dbg       (ar_head_raw_dbg),
    .ar_tail_raw_dbg       (ar_tail_raw_dbg),
    .r_wr_fire_dbg         (r_wr_fire_dbg),
    .r_rd_fire_dbg         (r_rd_fire_dbg),
    .r_overflow_dbg        (r_overflow_dbg),
    .r_underflow_dbg       (r_underflow_dbg),
    .r_wr_ptr_dbg          (r_wr_ptr_dbg),
    .r_rd_ptr_dbg          (r_rd_ptr_dbg),
    .r_head_raw_dbg        (r_head_raw_dbg),
    .r_tail_raw_dbg        (r_tail_raw_dbg)
  );

  bridge_core #(
    .ADDR_WIDTH    (ADDR_WIDTH),
    .DATA_WIDTH    (DATA_WIDTH),
    .STRB_WIDTH    (STRB_WIDTH),
    .LEN_WIDTH     (LEN_WIDTH),
    .W_COUNT_WIDTH (W_COUNT_WIDTH),
    .R_COUNT_WIDTH (R_COUNT_WIDTH),
    .R_FIFO_DEPTH  (R_DEPTH),
    .DEBUG_EN      (1'b1)
  ) u_bridge_core (
    .clk                    (clk),
    .rstn                   (rstn),
    .aw_head                (aw_head),
    .ar_head                (ar_head),
    .w_head                 (w_head),
    .aw_empty               (aw_empty),
    .ar_empty               (ar_empty),
    .w_empty                (w_empty),
    .r_full                 (r_full),
    .w_count                (w_count),
    .r_count                (r_count),
    .aw_pop                 (aw_pop),
    .ar_pop                 (ar_pop),
    .w_pop                  (w_pop),
    .r_push                 (r_push),
    .r_wdata                (r_wdata),
    .b_set_valid            (b_set_valid),
    .b_set_ready            (b_set_ready),
    .b_set_resp             (b_set_resp),
    .beat_req_valid         (beat_req_valid),
    .beat_req_ready         (beat_req_ready),
    .beat_req_write         (beat_req_write),
    .beat_req_first         (beat_req_first),
    .beat_req_addr          (beat_req_addr),
    .beat_req_size          (beat_req_size),
    .beat_req_wdata         (beat_req_wdata),
    .beat_req_wstrb         (beat_req_wstrb),
    .beat_rsp_valid         (beat_rsp_valid),
    .beat_rsp_error         (beat_rsp_error),
    .beat_rsp_rdata_valid   (beat_rsp_rdata_valid),
    .beat_rsp_rdata         (beat_rsp_rdata),
    .accept_enable_dbg      (core_accept_enable_dbg),
    .ctrl_busy_dbg          (core_ctrl_busy_dbg),
    .grant_valid_dbg        (core_grant_valid_dbg),
    .grant_wr_dbg           (core_grant_wr_dbg),
    .grant_rd_dbg           (core_grant_rd_dbg),
    .grant_accept_dbg       (core_grant_accept_dbg),
    .wr_present_dbg         (core_wr_present_dbg),
    .rd_present_dbg         (core_rd_present_dbg),
    .wr_issue_ok_dbg        (core_wr_issue_ok_dbg),
    .rd_issue_ok_dbg        (core_rd_issue_ok_dbg),
    .wr_candidate_dbg       (core_wr_candidate_dbg),
    .rd_candidate_dbg       (core_rd_candidate_dbg),
    .wr_beats_dbg           (core_wr_beats_dbg),
    .rd_beats_dbg           (core_rd_beats_dbg),
    .wr_need_beats_dbg      (core_wr_need_beats_dbg),
    .rd_need_slots_dbg      (core_rd_need_slots_dbg),
    .r_free_slots_dbg       (core_r_free_slots_dbg),
    .wr_payload_ready_dbg   (core_wr_payload_ready_dbg),
    .rd_resp_space_ready_dbg(core_rd_resp_space_ready_dbg),
    .wr_illegal_fifo_dbg    (core_wr_illegal_fifo_dbg),
    .rd_illegal_fifo_dbg    (core_rd_illegal_fifo_dbg),
    .wr_block_reason_dbg    (core_wr_block_reason_dbg),
    .rd_block_reason_dbg    (core_rd_block_reason_dbg),
    .last_grant_dbg         (core_last_grant_dbg),
    .arb_state_dbg          (core_arb_state_dbg),
    .tie_break_dbg          (core_tie_break_dbg),
    .ctrl_state_dbg         (core_ctrl_state_dbg),
    .active_dir_dbg         (core_active_dir_dbg),
    .beat_idx_dbg           (core_beat_idx_dbg),
    .beat_total_dbg         (core_beat_total_dbg),
    .cur_addr_dbg           (core_cur_addr_dbg),
    .active_illegal_dbg     (core_active_illegal_dbg),
    .error_seen_dbg         (core_error_seen_dbg),
    .beat_launch_fire_dbg   (core_beat_launch_fire_dbg),
    .beat_inflight_dbg      (core_beat_inflight_dbg),
    .beat_complete_dbg      (core_beat_complete_dbg),
    .contract_violation_dbg (core_contract_violation_dbg),
    .violation_code_dbg     (core_violation_code_dbg)
  );

  ahb_backend #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .STRB_WIDTH (STRB_WIDTH)
  ) u_ahb_backend (
    .clk                   (clk),
    .rstn                  (rstn),
    .beat_req_valid        (beat_req_valid),
    .beat_req_ready        (beat_req_ready),
    .beat_req_write        (beat_req_write),
    .beat_req_first        (beat_req_first),
    .beat_req_addr         (beat_req_addr),
    .beat_req_size         (beat_req_size),
    .beat_req_wdata        (beat_req_wdata),
    .beat_req_wstrb        (beat_req_wstrb),
    .beat_rsp_valid        (beat_rsp_valid),
    .beat_rsp_error        (beat_rsp_error),
    .beat_rsp_rdata_valid  (beat_rsp_rdata_valid),
    .beat_rsp_rdata        (beat_rsp_rdata),
    .beat_busy_dbg         (backend_busy_dbg),
    .haddr                 (haddr),
    .htrans                (htrans),
    .hwrite                (hwrite),
    .hsize                 (hsize),
    .hburst                (hburst),
    .hwdata                (hwdata),
    .hstrb                 (hstrb),
    .hrdata                (hrdata),
    .hready                (hready),
    .hresp                 (hresp),
    .inflight_dbg          (backend_inflight_dbg),
    .accepted_dbg          (backend_accepted_dbg),
    .completed_dbg         (backend_completed_dbg),
    .cur_addr_dbg          (backend_cur_addr_dbg),
    .cur_write_dbg         (backend_cur_write_dbg),
    .cur_size_dbg          (backend_cur_size_dbg),
    .cur_wdata_dbg         (backend_cur_wdata_dbg),
    .cur_wstrb_dbg         (backend_cur_wstrb_dbg)
  );

endmodule
