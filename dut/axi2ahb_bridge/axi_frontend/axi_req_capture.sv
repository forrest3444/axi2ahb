import axi_frontend_pkg::*;

module axi_req_capture #(
	parameter int ADDR_WIDTH = 32,
	parameter int DATA_WIDTH = 32,
	parameter int STRB_WIDTH = DATA_WIDTH/8
)(
	input clk,
	input rstn,

	//AW channel
	input  logic [ADDR_WIDTH-1:0] awaddr,
	input  logic [1:0] awburst,
	input  logic [2:0] awsize,
	input  logic [3:0] awlen,
	input  logic awvalid,
	output logic awready,

	//W channel
	input  logic [DATA_WIDTH-1:0] wdata,
  input  logic [STRB_WIDTH-1:0] wstrb,
	input  logic wlast,
	input  logic wvalid,
	output logic wready,

	//AR channel
	input  logic [ADDR_WIDTH-1:0] araddr,
	input  logic [1:0] arburst,
	input  logic [2:0] arsize,
	input  logic [3:0] arlen,
	input  logic arvalid,
	output logic arready,
	
	//AW FIFO interface
	input  logic aw_fifo_full,
  output logic aw_push,
	output aw_item_t aw_wdata,

	//W FIFO interface
	input  logic w_fifo_full,
  output logic w_push,
	output w_item_t w_wdata,

	//AR FIFO interface
	input  logic ar_fifo_full,
	output logic ar_push,
	output ar_item_t ar_wdata,

  // frontend-local error response requests
  output logic illegal_wr_resp_valid,
  input  logic illegal_wr_resp_ready,
  output logic [1:0] illegal_wr_resp,

  output logic illegal_rd_resp_valid,
  input  logic illegal_rd_resp_ready,
  output logic [1:0] illegal_rd_resp,
  output logic [DATA_WIDTH-1:0] illegal_rd_data,
  output logic [4:0] illegal_rd_beats,
	
	//DEBUG
	output logic [1:0] wr_state_dbg,
	output logic [4:0] wr_beats_expected_dbg,
	output logic [4:0] wr_beats_received_dbg,
	output logic       wr_req_illegal_dbg
);

  typedef enum logic [1:0] {
		WR_IDLE      = 2'd0,
		WR_WAIT_DATA = 2'd1,
		WR_RECV_DATA = 2'd2
	} wr_state_e;

  wr_state_e wr_state, wr_state_n;

  logic aw_hs, w_hs, ar_hs;
  logic illegal_wr_resp_fire;
  logic illegal_rd_resp_fire;
  logic illegal_rd_pending, illegal_rd_pending_n;
  logic illegal_wr_pending, illegal_wr_pending_n;
  logic illegal_write_complete;
  logic [4:0] illegal_rd_beats_n;

	assign aw_hs = awvalid && awready;
	assign w_hs  = wvalid  && wready;
	assign ar_hs = arvalid && arready;
  assign illegal_wr_resp_fire = illegal_wr_resp_valid && illegal_wr_resp_ready;
  assign illegal_rd_resp_fire = illegal_rd_resp_valid && illegal_rd_resp_ready;

	logic [4:0]            wr_beats_expected;
	logic [4:0]            wr_beats_received;
	logic                  wr_req_illegal;
  logic aw_illegal_comb;
  logic ar_illegal_comb;

  localparam logic [1:0] BURST_FIXED = 2'b00;
  localparam logic [1:0] BURST_INCR  = 2'b01;
  localparam logic [1:0] BURST_WRAP  = 2'b10;
  localparam logic [1:0] RESP_SLVERR = 2'b10;
  localparam int unsigned MAX_SIZE   = (STRB_WIDTH <= 1) ? 0 : $clog2(STRB_WIDTH);

  function automatic logic burst_supported(input logic [1:0] burst);
    burst_supported = (burst == BURST_FIXED)
                   || (burst == BURST_INCR)
                   || (burst == BURST_WRAP);
  endfunction

  function automatic logic size_supported(input logic [2:0] size);
    size_supported = (int'(size) <= MAX_SIZE);
  endfunction

  function automatic logic is_addr_aligned(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0]            size
  );
    logic [ADDR_WIDTH-1:0] mask;
    int unsigned bytes;
    begin
      if (!size_supported(size)) begin
        is_addr_aligned = 1'b0;
      end
      else begin
        bytes           = 1 << size;
        mask            = ADDR_WIDTH'(bytes - 1);
        is_addr_aligned = ((addr & mask) == '0);
      end
    end
  endfunction

  function automatic logic wrap_len_supported(input logic [3:0] len);
    wrap_len_supported = (len == 4'd1)
                      || (len == 4'd3)
                      || (len == 4'd7)
                      || (len == 4'd15);
  endfunction

  function automatic logic [ADDR_WIDTH-1:0] get_wrap_base_addr(
    input logic [ADDR_WIDTH-1:0] start_addr,
    input int unsigned           beat_num,
    input int unsigned           beat_bytes
  );
    int unsigned wrap_bytes;
    begin
      wrap_bytes = beat_num * beat_bytes;

      if (wrap_bytes == 0)
        get_wrap_base_addr = start_addr;
      else
        get_wrap_base_addr = (start_addr / wrap_bytes) * wrap_bytes;
    end
  endfunction

  function automatic logic crosses_1kb_boundary(
    input logic [ADDR_WIDTH-1:0] addr,
    input logic [2:0]            size,
    input logic [3:0]            len,
    input logic [1:0]            burst
  );
    logic [ADDR_WIDTH-1:0] curr_addr;
    logic [ADDR_WIDTH-1:0] next_addr;
    logic [ADDR_WIDTH-1:0] last_addr;
    logic [ADDR_WIDTH-1:0] wrap_base;
    logic [ADDR_WIDTH-1:0] start_page;
    int unsigned beat_num;
    int unsigned beat_bytes;
    int unsigned wrap_bytes;
    begin
      crosses_1kb_boundary = 1'b0;

      if (!size_supported(size))
        return 1'b0;

      beat_num   = int'(len) + 1;
      beat_bytes = 1 << size;
      wrap_bytes = beat_num * beat_bytes;
      curr_addr  = addr;
      start_page = {addr[ADDR_WIDTH-1:10], 10'b0};

      if (burst == BURST_WRAP)
        wrap_base = get_wrap_base_addr(addr, beat_num, beat_bytes);
      else
        wrap_base = '0;

      for (int unsigned i = 0; i < beat_num; i++) begin
        last_addr = curr_addr + ADDR_WIDTH'(beat_bytes - 1);

        if ((curr_addr[ADDR_WIDTH-1:10] != start_page[ADDR_WIDTH-1:10])
         || (last_addr[ADDR_WIDTH-1:10] != start_page[ADDR_WIDTH-1:10])) begin
          crosses_1kb_boundary = 1'b1;
          return crosses_1kb_boundary;
        end

        case (burst)
          BURST_FIXED: next_addr = curr_addr;
          BURST_WRAP: begin
            next_addr = curr_addr + ADDR_WIDTH'(beat_bytes);
            if (next_addr >= (wrap_base + ADDR_WIDTH'(wrap_bytes)))
              next_addr = wrap_base;
          end
          default: next_addr = curr_addr + ADDR_WIDTH'(beat_bytes);
        endcase

        curr_addr = next_addr;
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
                 || !is_addr_aligned(addr, size)
                 || ((burst == BURST_WRAP)
                     && (!wrap_len_supported(len)))
                 || crosses_1kb_boundary(addr, size, len, burst);
    end
  endfunction

  assign aw_illegal_comb = req_illegal(awaddr, awsize, awlen, awburst);
  assign ar_illegal_comb = req_illegal(araddr, arsize, arlen, arburst);
  assign illegal_write_complete = w_hs
                               && ((wr_beats_received + 5'd1) == wr_beats_expected)
                               && wr_req_illegal;

	always_comb begin
		awready = 1'b0;
		wready  = 1'b0;
		arready = 1'b0;

		if((wr_state == WR_IDLE) && !aw_fifo_full) begin
			awready = 1'b1;
		end

		if((wr_state == WR_WAIT_DATA) || (wr_state == WR_RECV_DATA)) begin
        if (wr_req_illegal)
			  wready = 1'b1;
        else if (!w_fifo_full)
			  wready = 1'b1;
		end

		if(!ar_fifo_full) begin
			arready = 1'b1;
		end
	end

	always_comb begin
		aw_push = 1'b0;
		w_push  = 1'b0;
		ar_push = 1'b0;

		aw_wdata = '0;
		w_wdata  = '0;
		ar_wdata = '0;

		if(aw_hs && !aw_illegal_comb) begin
			aw_push          = 1'b1;
			aw_wdata.addr    = awaddr;
			aw_wdata.len     = awlen;
			aw_wdata.size    = awsize;
			aw_wdata.burst   = awburst;
			aw_wdata.illegal = 1'b0;
		end

		if(w_hs && !wr_req_illegal) begin
			w_push          = 1'b1;
			w_wdata.data    = wdata;
			w_wdata.strb    = wstrb;
			w_wdata.last    = wlast;
			w_wdata.illegal = 1'b0;
		end

		if(ar_hs && !ar_illegal_comb) begin
			ar_push          = 1'b1;
			ar_wdata.addr    = araddr;
			ar_wdata.len     = arlen;
			ar_wdata.size    = arsize;
			ar_wdata.burst   = arburst;
			ar_wdata.illegal = 1'b0;
		end
	end

  always_comb begin
    wr_state_n = wr_state;

    unique case (wr_state)
      WR_IDLE: begin
        if (aw_hs) begin
          wr_state_n = WR_WAIT_DATA;
        end
      end

      WR_WAIT_DATA: begin
        if (w_hs) begin
          if (wr_beats_expected == 5'd1)
            wr_state_n = WR_IDLE;
          else
            wr_state_n = WR_RECV_DATA;
        end
      end

      WR_RECV_DATA: begin
        if (w_hs) begin
          if (wr_beats_received + 5'd1 == wr_beats_expected)
            wr_state_n = WR_IDLE;
          else
            wr_state_n = WR_RECV_DATA;
        end
      end

      default: begin
        wr_state_n = WR_IDLE;
      end
    endcase
  end

  always_comb begin
    illegal_rd_pending_n = illegal_rd_pending;
    illegal_wr_pending_n = illegal_wr_pending;
    illegal_rd_beats_n   = illegal_rd_beats;

    if (ar_hs && ar_illegal_comb) begin
      illegal_rd_pending_n = 1'b1;
      illegal_rd_beats_n   = {1'b0, arlen} + 5'd1;
    end
    else if (illegal_rd_resp_fire) begin
      illegal_rd_pending_n = 1'b0;
    end

    if (illegal_write_complete)
      illegal_wr_pending_n = 1'b1;
    else if (illegal_wr_resp_fire)
      illegal_wr_pending_n = 1'b0;
  end

	always_ff @(posedge clk or negedge rstn) begin
		if(!rstn) begin
			wr_state <= WR_IDLE;
			wr_beats_expected <= '0;
			wr_beats_received <= '0;
			wr_req_illegal <= 1'b0;
      illegal_rd_pending <= 1'b0;
      illegal_wr_pending <= 1'b0;
      illegal_rd_beats   <= '0;
		end else begin
			wr_state <= wr_state_n;
      illegal_rd_pending <= illegal_rd_pending_n;
      illegal_wr_pending <= illegal_wr_pending_n;
      illegal_rd_beats   <= illegal_rd_beats_n;

			if(aw_hs) begin
				wr_beats_expected <= {1'b0, awlen} + 5'd1;
				wr_beats_received <= 5'd0;
				wr_req_illegal <= aw_illegal_comb;
			end

			if(w_hs) begin
				wr_beats_received <= wr_beats_received + 5'd1;

				if((wr_beats_received + 5'd1) < wr_beats_expected) begin
					if(wlast) begin
						wr_req_illegal <= 1'b1;
					end
				end else if((wr_beats_received + 5'd1) == wr_beats_expected) begin
					if(!wlast) begin
						wr_req_illegal <= 1'b1;
					end
				end else begin
					wr_req_illegal <= 1'b1;
				end
        end
		end
	end

  assign illegal_wr_resp_valid = illegal_wr_pending;
  assign illegal_wr_resp       = RESP_SLVERR;
  assign illegal_rd_resp_valid = illegal_rd_pending;
  assign illegal_rd_resp       = RESP_SLVERR;
  assign illegal_rd_data       = '0;

	assign wr_state_dbg          = wr_state;
	assign wr_beats_expected_dbg = wr_beats_expected;
	assign wr_beats_received_dbg = wr_beats_received;
	assign wr_req_illegal_dbg    = wr_req_illegal;

endmodule
