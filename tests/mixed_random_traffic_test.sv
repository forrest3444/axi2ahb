`ifndef MIXED_RANDOM_TRAFFIC_TEST_SV
`define MIXED_RANDOM_TRAFFIC_TEST_SV

class mixed_random_traffic_test extends base_test;

  `uvm_component_utils(mixed_random_traffic_test)

  mixed_random_traffic_virt_seq vseq;

  function new(string name = "mixed_random_traffic_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    vseq = mixed_random_traffic_virt_seq::type_id::create("vseq");
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    super.run_phase(phase);
    if (!vseq.randomize())
      `uvm_fatal("RND", "Randomization failed!")
    vseq.start(env.vseqr);
    `uvm_info("TEST", "mixed_random_traffic Virtual Test Finished!", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
