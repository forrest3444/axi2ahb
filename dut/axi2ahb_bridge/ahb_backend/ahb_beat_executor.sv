module ahb_beat_executor #(
  parameter int ADDR_WIDTH = 32,
  parameter int DATA_WIDTH = 32,
  parameter int STRB_WIDTH = DATA_WIDTH / 8
)(
  input  logic                     clk,
  input  logic                     rstn,

  // ============================================================
  // request interface from controller
  // one request = one AHB beat
  // ============================================================
  input  logic                     req_valid,
  output logic                     req_ready,
  input  logic                     req_write,
  input  logic                     req_first,
  input  logic [ADDR_WIDTH-1:0]    req_addr,
  input  logic [2:0]               req_size,
  input  logic [DATA_WIDTH-1:0]    req_wdata,
  input  logic [STRB_WIDTH-1:0]    req_wstrb,

  // ============================================================
  // response interface back to controller
  // pulse style: one-cycle valid when current beat completes
  // ============================================================
  output logic                     rsp_valid,
  output logic                     rsp_error,
  output logic                     rsp_rdata_valid,
  output logic [DATA_WIDTH-1:0]    rsp_rdata,

  output logic                     busy,

  // ============================================================
  // AHB-Lite master side
  // ============================================================
  output logic [ADDR_WIDTH-1:0]    haddr,
  output logic [1:0]               htrans,
  output logic                     hwrite,
  output logic [2:0]               hsize,
  output logic [2:0]               hburst,
  output logic [DATA_WIDTH-1:0]    hwdata,
  output logic [STRB_WIDTH-1:0]    hstrb,

  input  logic [DATA_WIDTH-1:0]    hrdata,
  input  logic                     hready,
  input  logic                     hresp,

  // ============================================================
  // debug
  // ============================================================
  output logic                     inflight_dbg,
  output logic                     accepted_dbg,
  output logic                     completed_dbg,
  output logic [ADDR_WIDTH-1:0]    cur_addr_dbg,
  output logic                     cur_write_dbg,
  output logic [2:0]               cur_size_dbg,
  output logic [DATA_WIDTH-1:0]    cur_wdata_dbg,
  output logic [STRB_WIDTH-1:0]    cur_wstrb_dbg
);

  localparam logic [1:0] HTRANS_IDLE   = 2'b00;
  localparam logic [1:0] HTRANS_NONSEQ = 2'b10;
  localparam logic [1:0] HTRANS_SEQ    = 2'b11;

  localparam logic [2:0] HBURST_SINGLE = 3'b000;
  localparam int unsigned OFFSET_W = (STRB_WIDTH <= 1) ? 1 : $clog2(STRB_WIDTH);

  logic                  addr_valid, addr_valid_n;
  logic                  addr_write, addr_write_n;
  logic                  addr_first, addr_first_n;
  logic [ADDR_WIDTH-1:0] addr_reg,   addr_reg_n;
  logic [2:0]            size_reg,   size_reg_n;
  logic [DATA_WIDTH-1:0] wdata_reg,  wdata_reg_n;
  logic [STRB_WIDTH-1:0] wstrb_reg,  wstrb_reg_n;

  logic                  data_valid, data_valid_n;
  logic                  data_write, data_write_n;
  logic [ADDR_WIDTH-1:0] data_addr,  data_addr_n;
  logic [2:0]            data_size,  data_size_n;
  logic [DATA_WIDTH-1:0] data_wdata, data_wdata_n;
  logic [STRB_WIDTH-1:0] data_wstrb, data_wstrb_n;

  logic                  accept_req;
  logic                  complete_beat;
  logic                  bus_valid;
  logic                  bus_write;
  logic                  bus_first;
  logic [ADDR_WIDTH-1:0] bus_addr;
  logic [2:0]            bus_size;
  logic [DATA_WIDTH-1:0] bus_wdata;
  logic [STRB_WIDTH-1:0] bus_wstrb;

  initial begin
    if (DATA_WIDTH <= 0) begin
      $error("ahb_beat_executor: DATA_WIDTH must be > 0, got %0d", DATA_WIDTH);
    end
    if ((DATA_WIDTH % 8) != 0) begin
      $error("ahb_beat_executor: DATA_WIDTH (%0d) must be byte-aligned", DATA_WIDTH);
    end
    if (STRB_WIDTH != (DATA_WIDTH / 8)) begin
      $error("ahb_beat_executor: STRB_WIDTH (%0d) must equal DATA_WIDTH/8 (%0d)", STRB_WIDTH, (DATA_WIDTH / 8));
    end
    if (STRB_WIDTH == 0) begin
      $error("ahb_beat_executor: STRB_WIDTH must be > 0");
    end
    if ((STRB_WIDTH & (STRB_WIDTH - 1)) != 0) begin
      $error("ahb_beat_executor: STRB_WIDTH (%0d) must be a power of 2 for AHB byte-lane mapping", STRB_WIDTH);
    end
  end

  function automatic logic [STRB_WIDTH-1:0] gen_hstrb(
    input logic [OFFSET_W-1:0]     addr_lsb,
    input logic [2:0]              size,
    input logic [STRB_WIDTH-1:0]   wstrb
  );
    logic [STRB_WIDTH-1:0] narrow_mask;
    int unsigned active_bytes;
    int unsigned lane_shift;
    begin
      narrow_mask  = '0;
      active_bytes = 1;
      active_bytes = active_bytes << size;
      lane_shift   = int'(addr_lsb);

      if (active_bytes >= STRB_WIDTH) begin
        narrow_mask = '1;
      end
      else begin
        for (int i = 0; i < STRB_WIDTH; i++) begin
          if ((i >= lane_shift) && (i < (lane_shift + active_bytes))) begin
            narrow_mask[i] = 1'b1;
          end
        end
      end

      gen_hstrb = narrow_mask & wstrb;
    end
  endfunction

  assign req_ready     = hready;
  assign accept_req    = req_valid && req_ready;
  assign complete_beat = data_valid && hready;
  assign bus_valid     = addr_valid || req_valid;
  assign busy          = bus_valid || data_valid;

  always_comb begin
    if (addr_valid) begin
      bus_write = addr_write;
      bus_first = addr_first;
      bus_addr  = addr_reg;
      bus_size  = size_reg;
      bus_wdata = wdata_reg;
      bus_wstrb = wstrb_reg;
    end
    else begin
      bus_write = req_write;
      bus_first = req_first;
      bus_addr  = req_addr;
      bus_size  = req_size;
      bus_wdata = req_wdata;
      bus_wstrb = req_wstrb;
    end
  end

  always_comb begin
    addr_valid_n = addr_valid;
    addr_write_n = addr_write;
    addr_first_n = addr_first;
    addr_reg_n   = addr_reg;
    size_reg_n   = size_reg;
    wdata_reg_n  = wdata_reg;
    wstrb_reg_n  = wstrb_reg;

    data_valid_n = data_valid;
    data_write_n = data_write;
    data_addr_n  = data_addr;
    data_size_n  = data_size;
    data_wdata_n = data_wdata;
    data_wstrb_n = data_wstrb;

    if (hready) begin
      data_valid_n = bus_valid;
      data_write_n = bus_write;
      data_addr_n  = bus_addr;
      data_size_n  = bus_size;
      data_wdata_n = bus_wdata;
      data_wstrb_n = bus_wstrb;

      if (addr_valid) begin
        addr_valid_n = accept_req;
        if (accept_req) begin
          addr_write_n = req_write;
          addr_first_n = req_first;
          addr_reg_n   = req_addr;
          size_reg_n   = req_size;
          wdata_reg_n  = req_wdata;
          wstrb_reg_n  = req_wstrb;
        end
      end
      else begin
        addr_valid_n = 1'b0;
      end
    end
  end

  always_comb begin
    haddr  = bus_addr;
    hwrite = bus_write;
    hsize  = bus_size;
    hburst = HBURST_SINGLE;
    hwdata = data_wdata;
    hstrb  = '0;

    if (data_valid && data_write) begin
      hstrb = gen_hstrb(data_addr[OFFSET_W-1:0], data_size, data_wstrb);
    end

    if (bus_valid) begin
      htrans = bus_first ? HTRANS_NONSEQ : HTRANS_SEQ;
    end
    else begin
      htrans = HTRANS_IDLE;
    end
  end

  always_comb begin
    rsp_valid       = 1'b0;
    rsp_error       = 1'b0;
    rsp_rdata_valid = 1'b0;
    rsp_rdata       = hrdata;

    if (complete_beat) begin
      rsp_valid = 1'b1;
      rsp_error = hresp;

      if (!data_write) begin
        rsp_rdata_valid = 1'b1;
        rsp_rdata       = hrdata;
      end
    end
  end

  always_ff @(posedge clk or negedge rstn) begin
    if (!rstn) begin
      addr_valid <= 1'b0;
      addr_write <= 1'b0;
      addr_first <= 1'b1;
      addr_reg   <= '0;
      size_reg   <= '0;
      wdata_reg  <= '0;
      wstrb_reg  <= '0;
      data_valid <= 1'b0;
      data_write <= 1'b0;
      data_addr  <= '0;
      data_size  <= '0;
      data_wdata <= '0;
      data_wstrb <= '0;
    end
    else begin
      addr_valid <= addr_valid_n;
      addr_write <= addr_write_n;
      addr_first <= addr_first_n;
      addr_reg   <= addr_reg_n;
      size_reg   <= size_reg_n;
      wdata_reg  <= wdata_reg_n;
      wstrb_reg  <= wstrb_reg_n;
      data_valid <= data_valid_n;
      data_write <= data_write_n;
      data_addr  <= data_addr_n;
      data_size  <= data_size_n;
      data_wdata <= data_wdata_n;
      data_wstrb <= data_wstrb_n;
    end
  end

  assign inflight_dbg  = busy;
  assign accepted_dbg  = accept_req;
  assign completed_dbg = complete_beat;

  assign cur_addr_dbg  = bus_addr;
  assign cur_write_dbg = bus_write;
  assign cur_size_dbg  = bus_size;
  assign cur_wdata_dbg = bus_wdata;
  assign cur_wstrb_dbg = bus_wstrb;

endmodule
