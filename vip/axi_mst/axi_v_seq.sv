`ifndef AXI_V_SEQ__SV
`define AXI_V_SEQ__SV

class axi_virtual_sequence extends uvm_sequence;

	`uvm_objecti_utils(axi_virtual_sequence)
	`uvm_declare_p_sequencer(axi_virtual_sequencer)

	axi_write_seq  w_seq;
	axi_read_seq   r_seq;

	virtual task body();
		`uvm_info(get_name(), "Starting avseq", UVM_MEDIUM)

		w_seq = axi_w
