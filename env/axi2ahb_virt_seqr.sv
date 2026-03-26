`ifndef AXI2AHB_VIRT_SEQR_SV
`define AXI2AHB_VIRT_SEQR_SV

class axi2ahb_virtual_sequencer extends uvm_sequencer;

	`uvm_component_utils(axi2ahb_virtual_sequencer)

	axi2ahb_config         cfg;
	axi_master_sequencer   axi_seqr;

	function new(string name = "axi2ahb_virtual_sequencer", uvm_component parent);
		super.new(name, parent);
	endfunction

endclass

`endif
	
