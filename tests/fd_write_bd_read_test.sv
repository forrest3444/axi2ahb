`ifndef AXI2AHB_FD_WRITE_BD_READ_TEST_SV
`define AXI2AHB_FD_WRITE_BD_READ_TEST_SV

class fd_write_bd_read_test extends base_test;

	`uvm_component_utils(fd_write_bd_read_test)

	fd_write_bd_read_virt_seq  vseq;

	function new(string name = "fd_write_bd_read_test", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		vseq = fd_write_bd_read_virt_seq::type_id::create("vseq");
	endfunction

	task run_phase(uvm_phase phase);
		phase.raise_objection(this);
		super.run_phase(phase);

		if(!vseq.randomize())
			`uvm_fatal("RND", "Randomization failed!")

		vseq.start(env.vseqr);
		`uvm_info("TEST", "fd write bd read Virtual Test Finished!", UVM_LOW)
		phase.drop_objection(this);
	endtask

endclass

`endif
