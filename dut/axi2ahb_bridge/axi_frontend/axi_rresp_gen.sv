import axi_frontend_pkg::*;

module axi_rresp_gen #(
  parameter int DATA_WIDTH = 32
)(
  input  logic                  clk,
  input  logic                  rstn,

  // r_fifo head/status (FWFT)
  input  logic                  r_fifo_empty,
  input  r_item_t               r_head,
  output logic                  r_pop,

  // frontend-local reject response source
  input  logic                  fe_set_valid,
  output logic                  fe_set_ready,
  input  logic [DATA_WIDTH-1:0] fe_set_data,
  input  logic [1:0]            fe_set_resp,
  input  logic [4:0]            fe_set_beats,

  // AXI R channel
  output logic                  rvalid,
  input  logic                  rready,
  output logic [DATA_WIDTH-1:0] rdata,
  output logic [1:0]            rresp,
  output logic                  rlast,

  // debug
  output logic                  r_fire_dbg
);

  logic                  fe_pending_valid, fe_pending_valid_n;
  logic [DATA_WIDTH-1:0] fe_pending_data,  fe_pending_data_n;
  logic [1:0]            fe_pending_resp,  fe_pending_resp_n;
  logic [4:0]            fe_pending_beats, fe_pending_beats_n;
  logic                  r_fire;

  assign fe_set_ready = (fe_pending_valid == 1'b0);
  assign r_fire       = rvalid && rready;

  always_comb begin
    rvalid = (fe_pending_valid == 1'b1) || (r_fifo_empty == 1'b0);
    rdata  = fe_pending_valid ? fe_pending_data : r_head.data;
    rresp  = fe_pending_valid ? fe_pending_resp : r_head.resp;
    rlast  = fe_pending_valid ? (fe_pending_beats == 5'd1) : r_head.last;
    r_pop  = r_fire && (fe_pending_valid == 1'b0);
  end

  always_comb begin
    fe_pending_valid_n = fe_pending_valid;
    fe_pending_data_n  = fe_pending_data;
    fe_pending_resp_n  = fe_pending_resp;
    fe_pending_beats_n = fe_pending_beats;

    if (fe_set_valid && fe_set_ready) begin
      fe_pending_valid_n = 1'b1;
      fe_pending_data_n  = fe_set_data;
      fe_pending_resp_n  = fe_set_resp;
      fe_pending_beats_n = fe_set_beats;
    end

    if (r_fire && (fe_pending_valid == 1'b1)) begin
      if (fe_pending_beats == 5'd1) begin
        fe_pending_valid_n = 1'b0;
        fe_pending_beats_n = '0;
      end
      else begin
        fe_pending_beats_n = fe_pending_beats - 5'd1;
      end
    end
  end

  always_ff @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      fe_pending_valid <= 1'b0;
      fe_pending_data  <= DATA_WIDTH'('0);
      fe_pending_resp  <= 2'b00;
      fe_pending_beats <= '0;
    end
    else begin
      fe_pending_valid <= fe_pending_valid_n;
      fe_pending_data  <= fe_pending_data_n;
      fe_pending_resp  <= fe_pending_resp_n;
      fe_pending_beats <= fe_pending_beats_n;
    end
  end

  assign r_fire_dbg = r_fire;

endmodule
