`ifndef AXI2AHB_BD_WRITE_FD_READ_TEST_SV
`define AXI2AHB_BD_WRITE_FD_READ_TEST_SV

class bd_write_fd_read_test extends base_test;

	`uvm_component_utils(bd_write_fd_read_test)

	bd_write_fd_read_virt_seq  vseq;

	function new(string name = "bd_write_fd_read_test", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		vseq = bd_write_fd_read_virt_seq::type_id::create("vseq");
	endfunction

	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		super.run_phase(phase);

		if(!vseq.randomize())
			`uvm_fatal("RND", "Randomization failed!")

		vseq.start(env.vseqr);
		`uvm_info("TEST", "bd write fd read Virtual Test Finished!", UVM_LOW)
		phase.drop_objection(this);
	endtask

endclass

`endif
