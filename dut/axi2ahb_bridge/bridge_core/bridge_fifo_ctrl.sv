module bridge_fifo_ctrl #(
  parameter int unsigned ADDR_WIDTH     = 32,
  parameter int unsigned STRB_WIDTH     = 4,
  parameter int unsigned LEN_WIDTH      = 4,
  parameter int unsigned W_COUNT_WIDTH  = 8,
  parameter int unsigned R_COUNT_WIDTH  = 8,
  parameter int unsigned R_FIFO_DEPTH   = 64
)(
  input  logic                             accept_enable,

  input  logic                             aw_empty,
  input  axi_frontend_pkg::aw_item_t       aw_head,

  input  logic                             ar_empty,
  input  axi_frontend_pkg::ar_item_t       ar_head,

  input  logic                             w_empty,
  input  logic [W_COUNT_WIDTH-1:0]         w_count,

  input  logic                             r_full,
  input  logic [R_COUNT_WIDTH-1:0]         r_count,

  output logic                             wr_present,
  output logic                             rd_present,

  output logic                             wr_issue_ok,
  output logic                             rd_issue_ok,

  output logic                             wr_candidate,
  output logic                             rd_candidate,

  output logic [LEN_WIDTH:0]               wr_beats,
  output logic [LEN_WIDTH:0]               rd_beats,
  output logic [LEN_WIDTH:0]               wr_need_beats,
  output logic [LEN_WIDTH:0]               rd_need_slots,
  output logic [R_COUNT_WIDTH-1:0]         r_free_slots,
  output logic                             wr_payload_ready,
  output logic                             rd_resp_space_ready,
  output logic                             wr_illegal_dbg,
  output logic                             rd_illegal_dbg,
  output logic [2:0]                       wr_block_reason,
  output logic [2:0]                       rd_block_reason
);

  localparam logic [2:0] WR_BLK_NONE        = 3'd0;
  localparam logic [2:0] WR_BLK_NO_AW       = 3'd1;
  localparam logic [2:0] WR_BLK_WAIT_WDATA  = 3'd2;
  localparam logic [2:0] WR_BLK_ACCEPT_OFF  = 3'd3;

  localparam logic [2:0] RD_BLK_NONE        = 3'd0;
  localparam logic [2:0] RD_BLK_NO_AR       = 3'd1;
  localparam logic [2:0] RD_BLK_WAIT_RSPACE = 3'd2;
  localparam logic [2:0] RD_BLK_ACCEPT_OFF  = 3'd3;

  localparam logic [1:0] BURST_FIXED = 2'b00;
  localparam logic [1:0] BURST_INCR  = 2'b01;
  localparam logic [1:0] BURST_WRAP  = 2'b10;
  localparam int unsigned MAX_SIZE   = (STRB_WIDTH <= 1) ? 0 : $clog2(STRB_WIDTH);

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

  always_comb begin
    wr_present = !aw_empty;
    rd_present = !ar_empty;
  end

  always_comb begin
    wr_beats = '0;
    rd_beats = '0;

    if (wr_present) begin
      wr_beats = {1'b0, aw_head.len} + {{LEN_WIDTH{1'b0}}, 1'b1};
    end

    if (rd_present) begin
      rd_beats = {1'b0, ar_head.len} + {{LEN_WIDTH{1'b0}}, 1'b1};
    end
  end

  always_comb begin
    wr_illegal_dbg = 1'b0;
    rd_illegal_dbg = 1'b0;

    if (wr_present) begin
      wr_illegal_dbg = req_illegal(aw_head.addr, aw_head.size, aw_head.len, aw_head.burst) || (1'b0 & aw_head.illegal);
    end

    if (rd_present) begin
      rd_illegal_dbg = req_illegal(ar_head.addr, ar_head.size, ar_head.len, ar_head.burst) || (1'b0 & ar_head.illegal);
    end
  end

  always_comb begin
    wr_need_beats = '0;
    rd_need_slots = '0;

    if (wr_present) begin
      wr_need_beats = wr_beats;
    end

    if (rd_present) begin
      if (rd_illegal_dbg) begin
        rd_need_slots = {{LEN_WIDTH{1'b0}}, 1'b1};
      end
      else begin
        rd_need_slots = rd_beats;
      end
    end
  end

  always_comb begin
    r_free_slots = R_COUNT_WIDTH'(R_FIFO_DEPTH) - r_count;
  end

  always_comb begin
    wr_payload_ready    = 1'b0;
    rd_resp_space_ready = 1'b0;

    if (wr_present) begin
      wr_payload_ready = !w_empty && (w_count >= W_COUNT_WIDTH'(wr_need_beats));
    end

    if (rd_present) begin
      rd_resp_space_ready = !r_full && (r_free_slots >= R_COUNT_WIDTH'(rd_need_slots));
    end
  end

  always_comb begin
    wr_issue_ok = 1'b0;
    rd_issue_ok = 1'b0;

    if (accept_enable) begin
      wr_issue_ok = wr_present && wr_payload_ready;
      rd_issue_ok = rd_present && rd_resp_space_ready;
    end
  end

  always_comb begin
    wr_candidate = wr_issue_ok;
    rd_candidate = rd_issue_ok;
  end

  always_comb begin
    wr_block_reason = WR_BLK_NONE;

    if (!wr_present) begin
      wr_block_reason = WR_BLK_NO_AW;
    end
    else if (!wr_payload_ready) begin
      wr_block_reason = WR_BLK_WAIT_WDATA;
    end
    else if (!accept_enable) begin
      wr_block_reason = WR_BLK_ACCEPT_OFF;
    end
  end

  always_comb begin
    rd_block_reason = RD_BLK_NONE;

    if (!rd_present) begin
      rd_block_reason = RD_BLK_NO_AR;
    end
    else if (!rd_resp_space_ready) begin
      rd_block_reason = RD_BLK_WAIT_RSPACE;
    end
    else if (!accept_enable) begin
      rd_block_reason = RD_BLK_ACCEPT_OFF;
    end
  end

endmodule
