module axi_bresp_gen (
  input  logic       clk,
  input  logic       rstn,

  // controller-side response source
  input  logic       set_valid,
  output logic       set_ready,
  input  logic [1:0] set_resp,

  // frontend-local reject response source
  input  logic       fe_set_valid,
  output logic       fe_set_ready,
  input  logic [1:0] fe_set_resp,

  // AXI B channel
  output logic       bvalid,
  input  logic       bready,
  output logic [1:0] bresp,

  // debug
  output logic       pending_dbg,
  output logic       set_fire_dbg,
  output logic       b_fire_dbg
);

  logic       pending_valid, pending_valid_n;
  logic [1:0] pending_resp,  pending_resp_n;
  logic       src_set_fire;
  logic       b_fire;

  assign fe_set_ready = (pending_valid == 1'b0);
  assign set_ready    = (pending_valid == 1'b0) && (fe_set_valid == 1'b0);
  assign src_set_fire = (fe_set_valid && fe_set_ready)
                     || (set_valid && set_ready);
  assign b_fire       = bvalid && bready;

  always_comb begin
    bvalid = pending_valid;
    bresp  = pending_resp;
  end

  always_comb begin
    pending_valid_n = pending_valid;
    pending_resp_n  = pending_resp;

    if (fe_set_valid && fe_set_ready) begin
      pending_valid_n = 1'b1;
      pending_resp_n  = fe_set_resp;
    end
    else if (set_valid && set_ready) begin
      pending_valid_n = 1'b1;
      pending_resp_n  = set_resp;
    end

    if (b_fire) begin
      pending_valid_n = 1'b0;
    end
  end

  always_ff @(posedge clk or negedge rstn) begin
    if (rstn == 1'b0) begin
      pending_valid <= 1'b0;
      pending_resp  <= 2'b00;
    end
    else begin
      pending_valid <= pending_valid_n;
      pending_resp  <= pending_resp_n;
    end
  end

  assign pending_dbg  = pending_valid;
  assign set_fire_dbg = src_set_fire;
  assign b_fire_dbg   = b_fire;

endmodule
