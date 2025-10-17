parameter DATA_WIDTH = 32;
parameter ADDR_WIDTH = 16;
parameter STRB_WIDTH = DATA_WIDTH/8;

`include "axi2ahb_pkg.svh"
`include "axi_interface.sv"
`include "ahb_interface.sv"

module top;
	bit clk, rstn;
	
	always #5 clk = ~clk;

	initial begin
		rstn = 0;
		#100ns;
		rstn = 1;
	end

/*==============================================================================
|                     interface instantiation   
==============================================================================*/

	axi_intf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) aif(clk, rstn);
	ahb_intf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)) hif(clk, rstn);

	env_config env_cfg;

/*==============================================================================
|                     DUT instantiation   
==============================================================================*/

	AXI_to_AHB_Bridge #(
		.DATA_WIDTH   (DATA_WIDTH),
		.ADDRESS_WIDTH(ADDR_WIDTH),
		.STOBE_WIDTH  (STRB_WIDTH)
	) axi2ahb_dut (
		.ACLK    (clk),
		.ARESET_n(rstn),
		//axi
		//axi write address
		.AWADDR  (aif.awaddr),
		.AWBURST (aif.awburst),
		.AWSIZE  (aif.awsize),
		.AWLEN   (aif.awlen),
		.AWVALID (aif.awvalid),
		.AWREADY (aif.awready),
		//axi write data
		.WDATA   (aif.wdata),
		.WSTRB	 (aif.wstrb),
		.WLAST   (aif.wlast),
		.WVALID  (aif.wvalid),
		.WREADY  (aif.wready),
		//axi write response
		.BRESP   (aif.bresp),
		.BVALID  (aif.bvalid),
		.BREADY  (aif.bready),
		//axi read address
		.ARADDR  (aif.araddr),
		.ARBURST (aif.arburst),
		.ARSIZE  (aif.arsize),
		.ARLEN   (aif.arlen),
		.ARVALID (aif.arvalid),
		.ARREADY (aif.arready),
		//axi read data
		.RDATA   (aif.rdata),
		.RLAST   (aif.rlast),
		.RRESP   (aif.rresp),
		.RVALID  (aif.rvalid),
		.RREADY  (aif.rready),
		//ahb
		//ahb address control
		.HADDR   (hif.haddr),
		.HTRANS  (hif.htrans),
		.HBURST  (hif.hburst),
		.HSIZE   (hif.hsize),
		//ahb read/write control 
		.HWRITE  (hif.hwrite),
		.HWSTRB  (hif.hwstrb),
		//ahb data transfer
		.HWDATA  (hif.hwdata),
		.HRDATA  (hif.hrdata),
		//ahb response 
		.HREADY  (hif.hready),
		.HRESP   (hif.hresp)
	);




	initial begin
		env_cfg = new();
		env_cfg.axi_if = axi_if;
		uvm_config_db#(env_config)::set(null, "uvm_test_top", "config", env_cfg);
		uvm_config_db#(env_config)::set(null, "uvm_test_top.env.master", "config", env_cfg);
		uvm_config_db#(env_config)::set(null, "uvm_test_top.env.slave", "config", env_cfg);
		run_test();
	end

endmodule
