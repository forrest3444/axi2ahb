`ifndef AXI_MASTER_SEQUENCER_SV
`define AXI_MASTER_SEQUENCER_SV

class axi_master_sequencer extends uvm_sequencer #(axi_transaction);

	`uvm_component_utils(axi_master_sequencer)

	axi_master_config  cfg;

	function new(string name = "axi_master_sequencer", uvm_component parent);
		super.new(name, parent);
	endfunction

endclass

`endif
