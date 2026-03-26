`include "axi2ahb_macros.svh"
`include "axi_if.sv"
`include "ahb_if.sv"

module top_tb;

	import uvm_pkg::*;
  `include "uvm_macros.svh"
	import axi2ahb_pkg::*;

	parameter int unsigned AW_DEPTH = 8;
	parameter int unsigned  W_DEPTH = 128;
	parameter int unsigned AR_DEPTH = 8;
	parameter int unsigned  R_DEPTH = 128;

	parameter int unsigned W_COUNT_WIDTH = $clog2(W_DEPTH + 1);
	parameter int unsigned R_COUNT_WIDTH = $clog2(R_DEPTH + 1);

	logic clk; 
	logic rstn;
	
	initial clk = 1;
	always #5ns clk = ~clk;

	initial begin
		rstn = 1'b0;
		repeat(10) @(posedge clk);
		rstn = 1'b1;
	end

	axi_intf         aif(clk, rstn);
	ahb_intf         hif(clk, rstn);

	dut_dbg_if       dif(clk, rstn);

  axi2ahb_bridge_top #(
		.ADDR_WIDTH(`ADDR_WIDTH),
		.DATA_WIDTH(`DATA_WIDTH),
		.STRB_WIDTH(`STRB_WIDTH),

		.AW_DEPTH(AW_DEPTH),
		.W_DEPTH(W_DEPTH),
		.AR_DEPTH(AR_DEPTH),
		.R_DEPTH(R_DEPTH),

		.LEN_WIDTH(`LEN_WIDTH),
		.W_COUNT_WIDTH(W_COUNT_WIDTH),
		.R_COUNT_WIDTH(R_COUNT_WIDTH)
	) dut (
    .clk     (clk),
    .rstn    (rstn),

		//AXI SIDE
		//AW
    .awvalid (aif.awvalid),
    .awready (aif.awready),
    .awaddr  (aif.awaddr),
    .awlen   (aif.awlen),
    .awsize  (aif.awsize),
    .awburst (aif.awburst),

		//W
    .wvalid  (aif.wvalid),
    .wready  (aif.wready),
    .wdata   (aif.wdata),
    .wstrb   (aif.wstrb),
    .wlast   (aif.wlast),

		//B
    .bvalid  (aif.bvalid),
    .bready  (aif.bready),
    .bresp   (aif.bresp),

		//AR
    .arvalid (aif.arvalid),
    .arready (aif.arready),
    .araddr  (aif.araddr),
    .arlen   (aif.arlen),
    .arsize  (aif.arsize),
    .arburst (aif.arburst),

		//R
    .rvalid  (aif.rvalid),
    .rready  (aif.rready),
    .rdata   (aif.rdata),
    .rresp   (aif.rresp),
    .rlast   (aif.rlast),

		//AHB SIDE
		//master
    .haddr   (hif.haddr),
    .htrans  (hif.htrans),
    .hwrite  (hif.hwrite),
    .hsize   (hif.hsize),
    .hburst  (hif.hburst),
    .hwdata  (hif.hwdata),
    .hstrb   (hif.hstrb),

		//slave
    .hrdata  (hif.hrdata),
    .hready  (hif.hready),
    .hresp   (hif.hresp)
	);

	assign dif.aw_count                  = dut.aw_count;
	assign dif.w_count                   = dut.w_count;
	assign dif.ar_count                  = dut.ar_count;
	assign dif.r_count                   = dut.r_count;
	assign dif.aw_wr_fire_dbg            = dut.aw_wr_fire_dbg;
	assign dif.w_wr_fire_dbg             = dut.w_wr_fire_dbg;
	assign dif.ar_wr_fire_dbg            = dut.ar_wr_fire_dbg;
	assign dif.r_wr_fire_dbg             = dut.r_wr_fire_dbg;
	assign dif.core_beat_launch_fire_dbg = dut.core_beat_launch_fire_dbg;
	assign dif.core_grant_accept_dbg     = dut.core_grant_accept_dbg;
	assign dif.frontend_wr_req_illegal_dbg = dut.frontend_wr_req_illegal_dbg;
	assign dif.frontend_b_fire_dbg       = dut.frontend_b_fire_dbg;
	assign dif.frontend_r_fire_dbg       = dut.frontend_r_fire_dbg;

	initial begin
		uvm_config_db #(virtual axi_intf)::set(null, "uvm_test_top", "avif", aif);
		uvm_config_db #(virtual ahb_intf)::set(null, "uvm_test_top", "hvif", hif);
				uvm_config_db #(virtual dut_dbg_if)::set(null, "uvm_test_top", "dvif", dif);
		run_test();
	end

	string fsdb_file;
	initial begin
		if($test$plusargs("FSDB")) begin
			if(!$value$plusargs("FSDB_FILE=%s", fsdb_file))
				fsdb_file = "wave.fsdb";
			$display("Dump FSDB to %s", fsdb_file);

			$fsdbDumpfile(fsdb_file);
		  $fsdbDumpvars(0, top_tb, "+all");
		end
	end

endmodule
