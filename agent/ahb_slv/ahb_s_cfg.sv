`ifndef AHB_S_AGT_CFG__SV
`define AHB_S_AGT_CFG__SV

class ahb_slave_config extends uvm_object;

	`uvm_object_utils(ahb_slave_config)

	bit valid = 1;

	virtual ahb_intf    hvif;
	uvm_event_pool      events;
        
  memory                mem;
	memory::meminit_enum  meminit = memory::MEMINIT_ZERO;
	bit [`ADDR_WIDTH-1:0] mem_min_addr  = 32'h0000_0000;
	bit [`ADDR_WIDTH-1:0] mem_max_addr  = 32'h0000_ffff;
	bit [`DATA_WIDTH-1:0] meminit_value = 32'h0000_0000;

	uvm_active_passive_enum is_active = UVM_ACTIVE;

	int wait_enable = 1;
	bit force_hready_low = 0;

	function new(string name = "ahb_slave_config");
		super.new(name);
	endfunction

endclass

`endif
