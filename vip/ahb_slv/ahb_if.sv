`ifndef AHB_IF__SV
`define AHB_IF__SV

interface ahb_intf #(
	parameter DATA_WIDTH = 32,
	parameter ADDR_WIDTH = 16,
	parameter STRB_WIDTH = DATA_WIDTH/8
)(
	input logic hclk,
	input logic hrstn
);

  // Slave -> Master
  logic                  hready;   // 1: ready, 0: wait
  logic                  hresp;    // 0: OKAY, 1: SLVERR
  logic [DATA_WIDTH-1:0] hrdata;   // Read data bus

  // Master -> Slave
  logic [DATA_WIDTH-1:0]    hwdata;  // Write data bus
  logic [ADDR_WIDTH-1:0]    haddr;   // Address bus
  logic                     hwrite;  // 1: write, 0: read
  logic [2:0]               hsize;   // Transfer size (byte8/halfword16/word32)
  logic [2:0]               hburst;  // Burst type
  logic [1:0]               htrans;  // Transfer type (IDLE00/BUSY01/NONSEQ10/SEQ11)
  logic [STRB_WIDTH-1:0]    hwstrb;  // Byte enables
	
	clocking s_drv_cb @(posedge hclk);
		input  hwdata, haddr, hwrite, hsize, hburst, htrans, hwstrb;
		output hready, hresp, hrdata;
	endclocking

	clocking mon_cb @(posedge hclk);
		input hwdata, haddr, hwrite, hsize, hburst, htrans, hwstrb;
		input hready, hresp, hrdata;
	endclocking

	modport mmon(clocking mon_cb,   input hrstn);
	modport sdrv(clocking s_drv_cb, input hrstn);

  endinterface 

`endif
