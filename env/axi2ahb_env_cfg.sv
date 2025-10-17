`ifndef AXI2AHB_ENV_CFG__SV
`define AXI2AHB_ENV_CFG__SV

import uvm_pkg::*;

class env_config extends uvm_object;

	`uvm_object_utils(env_config)

	virtual axi_intf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH))  avif;
	virtual ahb_intf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH))  hvif;

	uvm_active_passive_enum  active = UVM_ACTIVE;

	function new(string name = "env_config");
		super.new(name);
	endfunction

endclass: test_config

class test_config extends uvm_object;

	 `uvm_object_utils(test_config)

	 int no_write_cases = 20;
	 int no_read _cases = 20;

	 //-1: produce both aligned and unaligned address
	 // 0: produce unaligned address
	 // 1: produce alligned address
	 byte isAligned = -1;

	 //-1: produce all the burst type randomly
	 // 0: produce fixed only
	 // 1: produce incr only
	 // 2: produce wrap only
	 byte burst_type = -1;

	 function new(string name = "test_config");
		 super.new(name);
	 endfunction

 endclass: test_config
