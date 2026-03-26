`ifndef AXI2AHB_MACROS_SVH
`define AXI2AHB_MACROS_SVH

	`ifndef ADDR_WIDTH
	`define ADDR_WIDTH  32
	`endif

	`ifndef DATA_WIDTH
	`define DATA_WIDTH  64
	`endif

	`ifndef STRB_WIDTH
	`define STRB_WIDTH  (`DATA_WIDTH/8)
	`endif

	`ifndef MAX_BURST_LENTH
	`define MAX_BURST_LENTH  16
	`endif

	`ifndef LEN_WIDTH
	`define LEN_WIDTH  $clog2(`MAX_BURST_LENTH)
  `endif

	`ifndef SETUP_TIME
	`define SETUP_TIME  1step
	`endif

	`ifndef HOLD_TIME
	`define HOLD_TIME   0
	`endif

	`ifndef MAX_DELAY
	`define MAX_DELAY   8
	`endif

`endif
