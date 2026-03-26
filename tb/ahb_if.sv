`ifndef AHB_INTF_SV
`define AHB_INTF_SV

interface ahb_intf(
	input logic clk,
	input logic rstn
);

	//control signal
	logic [`ADDR_WIDTH-1:0]  haddr;
	logic [1:0]              htrans;//00-idle;01-busy;10-nonseq;11-seq
	logic [2:0]              hburst;
	logic [2:0]              hsize;
	logic                    hwrite;//1-write;0-read
	logic [1:0]              hresp; 
	logic                    hready;//1-ready;0-wait
	logic [7:0]              hstrb;

	//data signal 
	logic [`DATA_WIDTH-1:0]  hwdata;
	logic [`DATA_WIDTH-1:0]  hrdata;

	//=============CLOCKING CLOCKS=================
	clocking drv_cb @(posedge clk);
		default input #`SETUP_TIME output #`HOLD_TIME;

		input  haddr, htrans, hburst, hsize, hwrite, hwdata, hstrb;
		output hrdata, hready, hresp;

	endclocking

	clocking mon_cb @(posedge clk);
		default input #`SETUP_TIME output #`HOLD_TIME;

		input  haddr, htrans, hburst, hsize, hwrite, hwdata, hstrb;
		input  hrdata, hready, hresp;

	endclocking

	//=============MODPORTS==============
	modport mon_mp(clocking mon_cb, input clk, rstn);
	modport drv_mp(clocking drv_cb, input clk, rstn);

endinterface

`endif
