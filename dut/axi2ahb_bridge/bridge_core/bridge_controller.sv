module bridge_controller #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int STRB_WIDTH = DATA_WIDTH/8,
  parameter bit DEBUG_EN   = 1'b0
)(
  input  logic                             clk,
  input  logic                             rstn,

  input  logic                             grant_valid,
  input  logic                             grant_wr,
  input  logic                             grant_rd,
  output logic                             grant_accept,
  output logic                             ctrl_busy,

  input  axi_frontend_pkg::aw_item_t       aw_head,
  input  axi_frontend_pkg::ar_item_t       ar_head,
  input  axi_frontend_pkg::w_item_t        w_head,

  input  logic                             aw_empty,
  input  logic                             ar_empty,
  input  logic                             w_empty,
  input  logic                             r_full,

  output logic                             aw_pop,
  output logic                             ar_pop,
  output logic                             w_pop,
  output logic                             r_push,
  output axi_frontend_pkg::r_item_t        r_wdata,

  output logic                             b_set_valid,
  input  logic                             b_set_ready,
  output logic [1:0]                       b_set_resp,

  output logic                             beat_req_valid,
  input  logic                             beat_req_ready,
  output logic                             beat_req_write,
  output logic                             beat_req_first,
  output logic [ADDR_WIDTH-1:0]            beat_req_addr,
  output logic [2:0]                       beat_req_size,
  output logic [DATA_WIDTH-1:0]            beat_req_wdata,
  output logic [STRB_WIDTH-1:0]            beat_req_wstrb,

  input  logic                             beat_rsp_valid,
  input  logic                             beat_rsp_error,
  input  logic                             beat_rsp_rdata_valid,
  input  logic [DATA_WIDTH-1:0]            beat_rsp_rdata,

  output logic [2:0]                       state_dbg,
  output logic                             active_dir_dbg,
  output logic [4:0]                       beat_idx_dbg,
  output logic [4:0]                       beat_total_dbg,
  output logic [ADDR_WIDTH-1:0]            cur_addr_dbg,
  output logic                             active_illegal_dbg,
  output logic                             error_seen_dbg,
  output logic                             beat_launch_fire_dbg,
  output logic                             beat_inflight_dbg,
  output logic                             beat_complete_dbg,
  output logic                             contract_violation_dbg,
  output logic [3:0]                       violation_code_dbg
);

  localparam logic [1:0] RESP_OKAY   = 2'b00;
  localparam logic [1:0] RESP_SLVERR = 2'b10;

  localparam logic [1:0] BURST_FIXED = 2'b00;
  localparam logic [1:0] BURST_INCR  = 2'b01;
  localparam logic [1:0] BURST_WRAP  = 2'b10;
  localparam int unsigned MAX_SIZE   = (STRB_WIDTH <= 1) ? 0 : $clog2(STRB_WIDTH);

  typedef enum logic [2:0] {
    ST_IDLE       = 3'd0,
    ST_LOAD       = 3'd1,
    ST_EXEC       = 3'd2,
    ST_WRITE_RESP = 3'd3
  } state_e;

  typedef enum logic {
    DIR_RD = 1'b0,
    DIR_WR = 1'b1
  } dir_e;

  localparam logic [3:0] VIO_NONE             = 4'd0;
  localparam logic [3:0] VIO_LOAD_AW_EMPTY    = 4'd1;
  localparam logic [3:0] VIO_LOAD_AR_EMPTY    = 4'd2;
  localparam logic [3:0] VIO_EXEC_W_EMPTY     = 4'd3;
  localparam logic [3:0] VIO_EXEC_R_FULL      = 4'd4;
  localparam logic [3:0] VIO_EXEC_RDATA_INV   = 4'd5;
  localparam logic [3:0] VIO_SPURIOUS_RSP     = 4'd6;
  localparam logic [3:0] VIO_ILLEGAL_RD_EXEC  = 4'd7;

  state_e state, state_n;

  dir_e                  active_dir, active_dir_n;
  logic [ADDR_WIDTH-1:0] cur_addr, cur_addr_n;
  logic [ADDR_WIDTH-1:0] addr_step, addr_step_n;
  logic [ADDR_WIDTH-1:0] wrap_mask, wrap_mask_n;
  logic [1:0]            active_burst, active_burst_n;
  logic [2:0]            active_size, active_size_n;
  logic [4:0]            beat_total, beat_total_n;
  logic [4:0]            beat_issue_idx, beat_issue_idx_n;
  logic [4:0]            beat_complete_idx, beat_complete_idx_n;
  logic                  active_illegal, active_illegal_n;
  logic                  error_seen, error_seen_n;
  logic                  beat_inflight, beat_inflight_n;
  logic [1:0]            final_bresp, final_bresp_n;
  logic                  load_is_write, load_is_write_n;

  logic                  contract_violation, contract_violation_n;
  logic [3:0]            violation_code, violation_code_n;

  logic                  exec_issue_need_more_beats;
  logic                  exec_complete_last_beat;
  logic                  beat_launch_fire;
  logic                  beat_complete_fire;
  logic                  aw_req_illegal;
  logic                  ar_req_illegal;
  logic                  write_drain_illegal;
  logic [ADDR_WIDTH-1:0] next_exec_addr;

  function automatic logic burst_supported(input logic [1:0] burst);
    burst_supported = (burst == BURST_FIXED)
                   || (burst == BURST_INCR)
                   || (burst == BURST_WRAP);
  endfunction

  function automatic logic size_supported(input logic [2:0] size);
    size_supported = (int'(size) <= MAX_SIZE);
  endfunction

  function automatic int unsigned beat_bytes(input logic [2:0] size);
    if (!size_supported(size))
      beat_bytes = 0;
    else
      beat_bytes = 1 << size;
  endfunction

  function automatic logic is_aligned(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0]            size
  );
    logic [ADDR_WIDTH-1:0] mask;
    int unsigned bytes;
    begin
      bytes = beat_bytes(size);
      if (bytes == 0) begin
        is_aligned = 1'b0;
      end
      else begin
        mask       = ADDR_WIDTH'(bytes - 1);
        is_aligned = ((addr & mask) == '0);
      end
    end
  endfunction

  function automatic logic wrap_len_supported(input logic [3:0] len);
    wrap_len_supported = (len == 4'd1)
                      || (len == 4'd3)
                      || (len == 4'd7)
                      || (len == 4'd15);
  endfunction

  function automatic logic wrap_start_aligned(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0]            size,
    input logic [3:0]            len
  );
    logic [ADDR_WIDTH-1:0] mask;
    int unsigned total_bytes;
    begin
      total_bytes = beat_bytes(size) * (int'(len) + 1);
      if (total_bytes == 0) begin
        wrap_start_aligned = 1'b0;
      end
      else begin
        mask               = ADDR_WIDTH'(total_bytes - 1);
        wrap_start_aligned = ((addr & mask) == '0);
      end
    end
  endfunction

  function automatic logic req_illegal(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0]            size,
    input logic [3:0]            len,
    input logic [1:0]            burst
  );
    begin
      req_illegal = !burst_supported(burst)
                 || !size_supported(size)
                 || !is_aligned(addr, size)
                 || ((burst == BURST_WRAP)
                     && (!wrap_len_supported(len)));
    end
  endfunction

  function automatic logic [ADDR_WIDTH-1:0] calc_wrap_mask(
    input logic [2:0] size,
    input logic [3:0] len
  );
    int unsigned total_bytes;
    begin
      total_bytes = beat_bytes(size) * (int'(len) + 1);
      if (total_bytes == 0)
        calc_wrap_mask = '0;
      else
        calc_wrap_mask = ADDR_WIDTH'(total_bytes - 1);
    end
  endfunction

  function automatic logic [ADDR_WIDTH-1:0] calc_next_addr(
    input logic [ADDR_WIDTH-1:0] cur_addr_i,
    input logic [ADDR_WIDTH-1:0] addr_step_i,
    input logic [1:0]            burst_i,
    input logic [ADDR_WIDTH-1:0] wrap_mask_i
  );
    logic [ADDR_WIDTH-1:0] linear_next;
    begin
      linear_next = cur_addr_i + addr_step_i;

      unique case (burst_i)
        BURST_FIXED: calc_next_addr = cur_addr_i;
        BURST_WRAP:  calc_next_addr = (cur_addr_i & ~wrap_mask_i) | (linear_next & wrap_mask_i);
        default:     calc_next_addr = linear_next;
      endcase
    end
  endfunction

  assign beat_launch_fire           = beat_req_valid && beat_req_ready;
  assign beat_complete_fire         = beat_rsp_valid;
  assign exec_issue_need_more_beats = (beat_issue_idx < beat_total);
  assign exec_complete_last_beat    = (beat_complete_idx + 5'd1 == beat_total);

  assign aw_req_illegal = req_illegal(aw_head.addr, aw_head.size, aw_head.len, aw_head.burst)
                       || (1'b0 & aw_head.illegal);
  assign ar_req_illegal = req_illegal(ar_head.addr, ar_head.size, ar_head.len, ar_head.burst)
                       || (1'b0 & ar_head.illegal);
  assign write_drain_illegal = (active_dir == DIR_WR) && (active_illegal || (!w_empty && w_head.illegal));
  assign next_exec_addr      = calc_next_addr(cur_addr, addr_step, active_burst, wrap_mask);

  always_comb begin
    grant_accept   = 1'b0 | (1'b0 & grant_rd);
    ctrl_busy      = (state != ST_IDLE);

    aw_pop         = 1'b0;
    ar_pop         = 1'b0;
    w_pop          = 1'b0;
    r_push         = 1'b0;
    r_wdata        = '0;

    b_set_valid    = 1'b0;
    b_set_resp     = final_bresp;

    beat_req_valid = 1'b0 | (1'b0 & w_head.last);
    beat_req_write = (active_dir == DIR_WR);
    beat_req_first = (beat_issue_idx == 5'd0);
    beat_req_addr  = cur_addr;
    beat_req_size  = active_size;
    beat_req_wdata = w_head.data;
    beat_req_wstrb = w_head.strb;

    state_n              = state;
    active_dir_n         = active_dir;
    cur_addr_n           = cur_addr;
    addr_step_n          = addr_step;
    wrap_mask_n          = wrap_mask;
    active_burst_n       = active_burst;
    active_size_n        = active_size;
    beat_total_n         = beat_total;
    beat_issue_idx_n     = beat_issue_idx;
    beat_complete_idx_n  = beat_complete_idx;
    active_illegal_n     = active_illegal;
    error_seen_n         = error_seen;
    beat_inflight_n      = beat_inflight;
    final_bresp_n        = final_bresp;
    load_is_write_n      = load_is_write;

    contract_violation_n = contract_violation;
    violation_code_n     = violation_code;

    unique case (state)
      ST_IDLE: begin
        if (grant_valid) begin
          grant_accept    = 1'b1;
          load_is_write_n = grant_wr;
          state_n         = ST_LOAD;
        end
      end

      ST_LOAD: begin
        if (load_is_write) begin
          if (aw_empty) begin
            contract_violation_n = 1'b1;
            violation_code_n     = VIO_LOAD_AW_EMPTY;
            state_n              = ST_IDLE;
          end
          else begin
            aw_pop               = 1'b1;
            active_dir_n         = DIR_WR;
            cur_addr_n           = aw_head.addr;
            addr_step_n          = ADDR_WIDTH'(beat_bytes(aw_head.size));
            wrap_mask_n          = calc_wrap_mask(aw_head.size, aw_head.len);
            active_burst_n       = aw_head.burst;
            active_size_n        = aw_head.size;
            beat_total_n         = {1'b0, aw_head.len} + 5'd1;
            beat_issue_idx_n     = 5'd0;
            beat_complete_idx_n  = 5'd0;
            active_illegal_n     = aw_req_illegal;
            error_seen_n         = aw_req_illegal;
            beat_inflight_n      = 1'b0;
            final_bresp_n        = aw_req_illegal ? RESP_SLVERR : RESP_OKAY;
            state_n              = ST_EXEC;
          end
        end
        else begin
          if (ar_empty) begin
            contract_violation_n = 1'b1;
            violation_code_n     = VIO_LOAD_AR_EMPTY;
            state_n              = ST_IDLE;
          end
          else if (ar_req_illegal) begin
            if (r_full) begin
              contract_violation_n = 1'b1;
              violation_code_n     = VIO_EXEC_R_FULL;
              state_n              = ST_IDLE;
            end
            else begin
              ar_pop          = 1'b1;
              r_push          = 1'b1;
              r_wdata.data    = '0;
              r_wdata.resp    = RESP_SLVERR;
              r_wdata.last    = 1'b1;
              r_wdata.illegal = 1'b1;
              state_n         = ST_IDLE;
            end
          end
          else begin
            ar_pop               = 1'b1;
            active_dir_n         = DIR_RD;
            cur_addr_n           = ar_head.addr;
            addr_step_n          = ADDR_WIDTH'(beat_bytes(ar_head.size));
            wrap_mask_n          = calc_wrap_mask(ar_head.size, ar_head.len);
            active_burst_n       = ar_head.burst;
            active_size_n        = ar_head.size;
            beat_total_n         = {1'b0, ar_head.len} + 5'd1;
            beat_issue_idx_n     = 5'd0;
            beat_complete_idx_n  = 5'd0;
            active_illegal_n     = 1'b0;
            error_seen_n         = 1'b0;
            beat_inflight_n      = 1'b0;
            final_bresp_n        = RESP_OKAY;
            state_n              = ST_EXEC;
          end
        end
      end

      ST_EXEC: begin
        if (active_illegal && (active_dir == DIR_RD)) begin
          contract_violation_n = 1'b1;
          violation_code_n     = VIO_ILLEGAL_RD_EXEC;
          state_n              = ST_IDLE;
        end
        else begin
          if (beat_complete_fire) begin
            if (!beat_inflight) begin
              contract_violation_n = 1'b1;
              violation_code_n     = VIO_SPURIOUS_RSP;
              state_n              = ST_IDLE;
            end
            else begin
              beat_inflight_n = 1'b0;

              if (active_dir == DIR_WR) begin
                if (beat_rsp_error) begin
                  error_seen_n  = 1'b1;
                  final_bresp_n = RESP_SLVERR;
                end

                if (exec_complete_last_beat) begin
                  state_n = ST_WRITE_RESP;
                end
                else begin
                  beat_complete_idx_n = beat_complete_idx + 5'd1;
                end
              end
              else begin
                if (r_full) begin
                  contract_violation_n = 1'b1;
                  violation_code_n     = VIO_EXEC_R_FULL;
                  state_n              = ST_IDLE;
                end
                else if (!beat_rsp_rdata_valid) begin
                  contract_violation_n = 1'b1;
                  violation_code_n     = VIO_EXEC_RDATA_INV;
                  state_n              = ST_IDLE;
                end
                else begin
                  r_push          = 1'b1;
                  r_wdata.data    = beat_rsp_error ? '0 : beat_rsp_rdata;
                  r_wdata.resp    = beat_rsp_error ? RESP_SLVERR : RESP_OKAY;
                  r_wdata.last    = exec_complete_last_beat;
                  r_wdata.illegal = 1'b0;

                  if (beat_rsp_error) begin
                    error_seen_n = 1'b1;
                  end

                  if (exec_complete_last_beat) begin
                    state_n = ST_IDLE;
                  end
                  else begin
                    beat_complete_idx_n = beat_complete_idx + 5'd1;
                  end
                end
              end
            end
          end

          if (state_n == ST_EXEC) begin
            if (write_drain_illegal) begin
              if (w_empty) begin
                contract_violation_n = 1'b1;
                violation_code_n     = VIO_EXEC_W_EMPTY;
                state_n              = ST_IDLE;
              end
              else begin
                w_pop             = 1'b1;
                active_illegal_n  = 1'b1;
                error_seen_n      = 1'b1;
                final_bresp_n     = RESP_SLVERR;

                if (exec_complete_last_beat) begin
                  state_n = ST_WRITE_RESP;
                end
                else begin
                  beat_issue_idx_n    = beat_issue_idx + 5'd1;
                  beat_complete_idx_n = beat_complete_idx + 5'd1;
                  cur_addr_n          = next_exec_addr;
                end
              end
            end
            else if (exec_issue_need_more_beats) begin
              if ((active_dir == DIR_WR) && w_empty) begin
                contract_violation_n = 1'b1;
                violation_code_n     = VIO_EXEC_W_EMPTY;
                state_n              = ST_IDLE;
              end
              else begin
                beat_req_valid = 1'b1;
                beat_req_write = (active_dir == DIR_WR);
                beat_req_first = (beat_issue_idx == 5'd0);
                beat_req_addr  = cur_addr;
                beat_req_size  = active_size;
                beat_req_wdata = w_head.data;
                beat_req_wstrb = w_head.strb;

                if (beat_launch_fire) begin
                  beat_inflight_n  = 1'b1;
                  beat_issue_idx_n = beat_issue_idx + 5'd1;
                  cur_addr_n       = next_exec_addr;

                  if (active_dir == DIR_WR) begin
                    w_pop = 1'b1;
                  end
                end
              end
            end
          end
        end
      end

      ST_WRITE_RESP: begin
        b_set_valid = 1'b1;
        b_set_resp  = final_bresp;

        if (b_set_ready) begin
          state_n = ST_IDLE;
        end
      end

      default: begin
        state_n = ST_IDLE;
      end
    endcase
  end

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      state              <= ST_IDLE;
      active_dir         <= DIR_RD;
      cur_addr           <= '0;
      addr_step          <= '0;
      wrap_mask          <= '0;
      active_burst       <= BURST_INCR;
      active_size        <= '0;
      beat_total         <= '0;
      beat_issue_idx     <= '0;
      beat_complete_idx  <= '0;
      active_illegal     <= 1'b0;
      error_seen         <= 1'b0;
      beat_inflight      <= 1'b0;
      final_bresp        <= RESP_OKAY;
      load_is_write      <= 1'b0;
      contract_violation <= 1'b0;
      violation_code     <= VIO_NONE;
    end
    else begin
      state              <= state_n;
      active_dir         <= active_dir_n;
      cur_addr           <= cur_addr_n;
      addr_step          <= addr_step_n;
      wrap_mask          <= wrap_mask_n;
      active_burst       <= active_burst_n;
      active_size        <= active_size_n;
      beat_total         <= beat_total_n;
      beat_issue_idx     <= beat_issue_idx_n;
      beat_complete_idx  <= beat_complete_idx_n;
      active_illegal     <= active_illegal_n;
      error_seen         <= error_seen_n;
      beat_inflight      <= beat_inflight_n;
      final_bresp        <= final_bresp_n;
      load_is_write      <= load_is_write_n;
      contract_violation <= contract_violation_n;
      violation_code     <= violation_code_n;
    end
  end

  generate
    if (DEBUG_EN) begin : g_debug_on
      always_comb begin
        state_dbg              = state;
        active_dir_dbg         = active_dir;
        beat_idx_dbg           = beat_complete_idx;
        beat_total_dbg         = beat_total;
        cur_addr_dbg           = cur_addr;
        active_illegal_dbg     = active_illegal;
        error_seen_dbg         = error_seen;
        beat_inflight_dbg      = beat_inflight;
        beat_launch_fire_dbg   = beat_launch_fire;
        beat_complete_dbg      = beat_complete_fire;
        contract_violation_dbg = contract_violation;
        violation_code_dbg     = violation_code;
      end
    end
    else begin : g_debug_off
      always_comb begin
        state_dbg              = '0;
        active_dir_dbg         = 1'b0;
        beat_idx_dbg           = '0;
        beat_total_dbg         = '0;
        cur_addr_dbg           = '0;
        active_illegal_dbg     = 1'b0;
        error_seen_dbg         = 1'b0;
        beat_inflight_dbg      = 1'b0;
        beat_launch_fire_dbg   = 1'b0;
        beat_complete_dbg      = 1'b0;
        contract_violation_dbg = 1'b0;
        violation_code_dbg     = '0;
      end
    end
  endgenerate

endmodule
