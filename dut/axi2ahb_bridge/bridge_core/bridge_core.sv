module bridge_core #(
  parameter int ADDR_WIDTH     = 32,
  parameter int DATA_WIDTH     = 32,
  parameter int STRB_WIDTH     = DATA_WIDTH/8,

  parameter int LEN_WIDTH      = 4,
  parameter int W_COUNT_WIDTH  = 8,
  parameter int R_COUNT_WIDTH  = 8,
  parameter int R_FIFO_DEPTH   = 64,

  parameter bit DEBUG_EN       = 1'b0
)(
  input  logic clk,
  input  logic rstn,

  // ==========================================================================
  // FIFO wrapper interface
  // external fifo_wrapper provides head items / status,
  // and consumes pop/push control from this core
  // ==========================================================================

  // request fifo heads
  input  axi_frontend_pkg::aw_item_t       aw_head,
  input  axi_frontend_pkg::ar_item_t       ar_head,
  input  axi_frontend_pkg::w_item_t        w_head,

  // fifo status
  input  logic                     aw_empty,
  input  logic                     ar_empty,
  input  logic                     w_empty,
  input  logic                     r_full,
  input  logic [W_COUNT_WIDTH-1:0] w_count,
  input  logic [R_COUNT_WIDTH-1:0] r_count,

  // fifo pop / push
  output logic                     aw_pop,
  output logic                     ar_pop,
  output logic                     w_pop,
  output logic                     r_push,
  output axi_frontend_pkg::r_item_t        r_wdata,

  // ==========================================================================
  // write response event output
  // consumed by response/event path outside controller
  // ==========================================================================
  output logic                     b_set_valid,
  input  logic                     b_set_ready,
  output logic [1:0]               b_set_resp,

  // ==========================================================================
  // ahb beat executor interface
  // ==========================================================================
  output logic                     beat_req_valid,
  input  logic                     beat_req_ready,
  output logic                     beat_req_write,
  output logic                     beat_req_first,
  output logic [ADDR_WIDTH-1:0]    beat_req_addr,
  output logic [2:0]               beat_req_size,
  output logic [DATA_WIDTH-1:0]    beat_req_wdata,
  output logic [STRB_WIDTH-1:0]    beat_req_wstrb,

  input  logic                     beat_rsp_valid,
  input  logic                     beat_rsp_error,
  input  logic                     beat_rsp_rdata_valid,
  input  logic [DATA_WIDTH-1:0]    beat_rsp_rdata,

  // ==========================================================================
  // top-level debug outputs
  // ==========================================================================

  // global scheduling / arbitration
  output logic                     accept_enable_dbg,
  output logic                     ctrl_busy_dbg,
  output logic                     grant_valid_dbg,
  output logic                     grant_wr_dbg,
  output logic                     grant_rd_dbg,
  output logic                     grant_accept_dbg,

  // fifo_ctrl debug
  output logic                     wr_present_dbg,
  output logic                     rd_present_dbg,
  output logic                     wr_issue_ok_dbg,
  output logic                     rd_issue_ok_dbg,
  output logic                     wr_candidate_dbg,
  output logic                     rd_candidate_dbg,
  output logic [LEN_WIDTH:0]       wr_beats_dbg,
  output logic [LEN_WIDTH:0]       rd_beats_dbg,
  output logic [LEN_WIDTH:0]       wr_need_beats_dbg,
  output logic [LEN_WIDTH:0]       rd_need_slots_dbg,
  output logic [R_COUNT_WIDTH-1:0] r_free_slots_dbg,
  output logic                     wr_payload_ready_dbg,
  output logic                     rd_resp_space_ready_dbg,
  output logic                     wr_illegal_fifo_dbg,
  output logic                     rd_illegal_fifo_dbg,
  output logic [2:0]               wr_block_reason_dbg,
  output logic [2:0]               rd_block_reason_dbg,

  // arbiter debug
  output logic                     last_grant_dbg,
  output logic [1:0]               arb_state_dbg,
  output logic                     tie_break_dbg,

  // controller debug
  output logic [2:0]               ctrl_state_dbg,
  output logic                     active_dir_dbg,
  output logic [4:0]               beat_idx_dbg,
  output logic [4:0]               beat_total_dbg,
  output logic [ADDR_WIDTH-1:0]    cur_addr_dbg,
  output logic                     active_illegal_dbg,
  output logic                     error_seen_dbg,
  output logic                     beat_launch_fire_dbg,
  output logic                     beat_inflight_dbg,
  output logic                     beat_complete_dbg,
  output logic                     contract_violation_dbg,
  output logic [3:0]               violation_code_dbg
);

  // ==========================================================================
  // internal wires
  // ==========================================================================

  // unified admission gate
  logic accept_enable;

  // fifo_ctrl -> arbiter
  logic wr_present;
  logic rd_present;
  logic wr_issue_ok;
  logic rd_issue_ok;
  logic wr_candidate;
  logic rd_candidate;

  logic [LEN_WIDTH:0]       wr_beats;
  logic [LEN_WIDTH:0]       rd_beats;
  logic [LEN_WIDTH:0]       wr_need_beats;
  logic [LEN_WIDTH:0]       rd_need_slots;
  logic [R_COUNT_WIDTH-1:0] r_free_slots;
  logic                     wr_payload_ready;
  logic                     rd_resp_space_ready;
  logic                     wr_illegal_fifo;
  logic                     rd_illegal_fifo;
  logic [2:0]               wr_block_reason;
  logic [2:0]               rd_block_reason;

  // arbiter -> controller
  logic grant_valid;
  logic grant_wr;
  logic grant_rd;
  logic grant_accept;

  // controller status
  logic ctrl_busy;

  // controller debug
  logic [2:0]            state_dbg_int;
  logic                  active_dir_dbg_int;
  logic [4:0]            beat_idx_dbg_int;
  logic [4:0]            beat_total_dbg_int;
  logic [ADDR_WIDTH-1:0] cur_addr_dbg_int;
  logic                  active_illegal_dbg_int;
  logic                  error_seen_dbg_int;
  logic                  beat_launch_fire_dbg_int;
  logic                  beat_inflight_dbg_int;
  logic                  beat_complete_dbg_int;
  logic                  contract_violation_dbg_int;
  logic [3:0]            violation_code_dbg_int;

  // arbiter debug
  logic last_grant_dbg_int;
  logic [1:0] arb_state_dbg_int;
  logic tie_break_dbg_int;

  // ==========================================================================
  // unified top-level admission gating
  // current v0.8 policy: controller must be idle to accept new transaction
  // ==========================================================================
  assign accept_enable = !ctrl_busy;

  // ==========================================================================
  // fifo control / transaction qualification
  // ==========================================================================
  bridge_fifo_ctrl #(
    .ADDR_WIDTH    (ADDR_WIDTH),
    .STRB_WIDTH    (STRB_WIDTH),
    .LEN_WIDTH     (LEN_WIDTH),
    .W_COUNT_WIDTH (W_COUNT_WIDTH),
    .R_COUNT_WIDTH (R_COUNT_WIDTH),
    .R_FIFO_DEPTH  (R_FIFO_DEPTH)
  ) u_bridge_fifo_ctrl (
    .accept_enable       (accept_enable),

    .aw_empty            (aw_empty),
    .aw_head             (aw_head),

    .ar_empty            (ar_empty),
    .ar_head             (ar_head),

    .w_empty             (w_empty),
    .w_count             (w_count),

    .r_full              (r_full),
    .r_count             (r_count),

    .wr_present          (wr_present),
    .rd_present          (rd_present),

    .wr_issue_ok         (wr_issue_ok),
    .rd_issue_ok         (rd_issue_ok),

    .wr_candidate        (wr_candidate),
    .rd_candidate        (rd_candidate),

    .wr_beats            (wr_beats),
    .rd_beats            (rd_beats),

    .wr_need_beats       (wr_need_beats),
    .rd_need_slots       (rd_need_slots),

    .r_free_slots        (r_free_slots),

    .wr_payload_ready    (wr_payload_ready),
    .rd_resp_space_ready (rd_resp_space_ready),

    .wr_illegal_dbg      (wr_illegal_fifo),
    .rd_illegal_dbg      (rd_illegal_fifo),

    .wr_block_reason     (wr_block_reason),
    .rd_block_reason     (rd_block_reason)
  );

  // ==========================================================================
  // arbitration
  // ==========================================================================
  bridge_arbiter #(
    .DEBUG_EN(DEBUG_EN)
  ) u_bridge_arbiter (
    .clk            (clk),
    .rstn           (rstn),

    .accept_enable  (accept_enable),

    .wr_candidate   (wr_candidate),
    .rd_candidate   (rd_candidate),

    .grant_accept   (grant_accept),

    .grant_valid    (grant_valid),
    .grant_wr       (grant_wr),
    .grant_rd       (grant_rd),

    .last_grant_dbg (last_grant_dbg_int),
    .arb_state_dbg  (arb_state_dbg_int),
    .tie_break_dbg  (tie_break_dbg_int)
  );

  // ==========================================================================
  // controller
  // ==========================================================================
  bridge_controller #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH),
    .STRB_WIDTH (STRB_WIDTH),
    .DEBUG_EN   (DEBUG_EN)
  ) u_bridge_controller (
    .clk                    (clk),
    .rstn                   (rstn),

    .grant_valid            (grant_valid),
    .grant_wr               (grant_wr),
    .grant_rd               (grant_rd),
    .grant_accept           (grant_accept),
    .ctrl_busy              (ctrl_busy),

    .aw_head                (aw_head),
    .ar_head                (ar_head),
    .w_head                 (w_head),

    .aw_empty               (aw_empty),
    .ar_empty               (ar_empty),
    .w_empty                (w_empty),
    .r_full                 (r_full),

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

    .state_dbg              (state_dbg_int),
    .active_dir_dbg         (active_dir_dbg_int),
    .beat_idx_dbg           (beat_idx_dbg_int),
    .beat_total_dbg         (beat_total_dbg_int),
    .cur_addr_dbg           (cur_addr_dbg_int),
    .active_illegal_dbg     (active_illegal_dbg_int),
    .error_seen_dbg         (error_seen_dbg_int),
    .beat_launch_fire_dbg   (beat_launch_fire_dbg_int),
    .beat_inflight_dbg      (beat_inflight_dbg_int),
    .beat_complete_dbg      (beat_complete_dbg_int),
    .contract_violation_dbg (contract_violation_dbg_int),
    .violation_code_dbg     (violation_code_dbg_int)
  );

  // ==========================================================================
  // top-level debug hookup
  // keep outputs stable; zero them when DEBUG_EN=0 for arbiter/controller,
  // fifo_ctrl debug remains directly observable in current version
  // ==========================================================================

  // always-useful global visibility
  assign accept_enable_dbg       = accept_enable;
  assign ctrl_busy_dbg           = ctrl_busy;
  assign grant_valid_dbg         = grant_valid;
  assign grant_wr_dbg            = grant_wr;
  assign grant_rd_dbg            = grant_rd;
  assign grant_accept_dbg        = grant_accept;

  // fifo_ctrl visibility
  assign wr_present_dbg          = wr_present;
  assign rd_present_dbg          = rd_present;
  assign wr_issue_ok_dbg         = wr_issue_ok;
  assign rd_issue_ok_dbg         = rd_issue_ok;
  assign wr_candidate_dbg        = wr_candidate;
  assign rd_candidate_dbg        = rd_candidate;
  assign wr_beats_dbg            = wr_beats;
  assign rd_beats_dbg            = rd_beats;
  assign wr_need_beats_dbg       = wr_need_beats;
  assign rd_need_slots_dbg       = rd_need_slots;
  assign r_free_slots_dbg        = r_free_slots;
  assign wr_payload_ready_dbg    = wr_payload_ready;
  assign rd_resp_space_ready_dbg = rd_resp_space_ready;
  assign wr_illegal_fifo_dbg     = wr_illegal_fifo;
  assign rd_illegal_fifo_dbg     = rd_illegal_fifo;
  assign wr_block_reason_dbg     = wr_block_reason;
  assign rd_block_reason_dbg     = rd_block_reason;

  // arbiter visibility
  assign last_grant_dbg          = last_grant_dbg_int;
  assign arb_state_dbg           = arb_state_dbg_int;
  assign tie_break_dbg           = tie_break_dbg_int;

  // controller visibility
  assign ctrl_state_dbg          = state_dbg_int;
  assign active_dir_dbg          = active_dir_dbg_int;
  assign beat_idx_dbg            = beat_idx_dbg_int;
  assign beat_total_dbg          = beat_total_dbg_int;
  assign cur_addr_dbg            = cur_addr_dbg_int;
  assign active_illegal_dbg      = active_illegal_dbg_int;
  assign error_seen_dbg          = error_seen_dbg_int;
  assign beat_launch_fire_dbg    = beat_launch_fire_dbg_int;
  assign beat_inflight_dbg       = beat_inflight_dbg_int;
  assign beat_complete_dbg       = beat_complete_dbg_int;
  assign contract_violation_dbg  = contract_violation_dbg_int;
  assign violation_code_dbg      = violation_code_dbg_int;

endmodule
