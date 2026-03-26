`ifndef AXI_MASTER_CONFIG_SV
`define AXI_MASTER_CONFIG_SV

class axi_master_config extends uvm_object;

	virtual axi_intf      avif;
	uvm_event_pool        events;
	bit valid = 1;
	bit force_bready_low = 0;
	bit force_rready_low = 0;
	
	uvm_active_passive_enum is_active = UVM_ACTIVE;

	`uvm_object_utils(axi_master_config)

	function new(string name = "axi_master_config");
		super.new(name);
	endfunction

endclass

`endif
