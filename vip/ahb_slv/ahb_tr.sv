`ifndef AHB_TR__SV
`define AHB_TR__SV

class ahb_tr #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 16) extends uvm_sequence_item;

	//control signal
	bit                    reset;
	bit [1:0]              htrans;
	bit [2:0]              hburst;
	bit [2:0]              hsize;
	bit                    hwrite;

	//address and data
	bit [7:0]              hwdata[][];
	bit [7:0]              hrdata[][];
	bit [ADDR_WIDTH-1:0]   haddr;

	//response
	bit [1:0]              hresp;
