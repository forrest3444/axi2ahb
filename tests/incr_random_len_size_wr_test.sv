`ifndef AXI2AHB_INCR_RANDOM_LEN_SIZE_WR_TEST_SV
`define AXI2AHB_INCR_RANDOM_LEN_SIZE_WR_TEST_SV

class incr_random_len_size_wr_test extends base_test;

  `uvm_component_utils(incr_random_len_size_wr_test)

  incr_random_len_size_wr_virt_seq vseq;

  function new(string name = "incr_random_len_size_wr_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    vseq = incr_random_len_size_wr_virt_seq::type_id::create("vseq");
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    super.run_phase(phase);

    if (!vseq.randomize())
      `uvm_fatal("RND", "Randomization failed!")

    vseq.start(env.vseqr);
    `uvm_info("TEST", "Incr random length/size write-read Virtual Test Finished!", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
