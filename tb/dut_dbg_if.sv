interface dut_dbg_if(input logic clk, input logic rstn);
  logic [31:0] aw_count;
  logic [31:0] w_count;
  logic [31:0] ar_count;
  logic [31:0] r_count;

  logic aw_wr_fire_dbg;
  logic w_wr_fire_dbg;
  logic ar_wr_fire_dbg;
  logic r_wr_fire_dbg;
  logic core_beat_launch_fire_dbg;
  logic core_grant_accept_dbg;
  logic frontend_wr_req_illegal_dbg;
  logic frontend_b_fire_dbg;
  logic frontend_r_fire_dbg;
endinterface
