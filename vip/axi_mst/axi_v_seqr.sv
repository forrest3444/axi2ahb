`ifndef AXI_V_SEQR__SV
`define AXI_V_SEQR__SV

class axi_virtual_sequencer extends uvm_sequencer;

	`uvm_component_utils(axi_virtual_sequencer)

	uvm_sequencer #(axi_tr #(DATA_WIDTH, ADDR_WIDTH))  w_seqr;
	uvm_sequencer #(axi_tr #(DATA_WIDTH, ADDR_WIDTH))  r_seqr;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

endclass
