`ifndef AXI2AHB_BACKEND_EXCEPTION_TEST_SV
`define AXI2AHB_BACKEND_EXCEPTION_TEST_SV

class backend_exception_test extends base_test;

  `uvm_component_utils(backend_exception_test)

  backend_exception_virt_seq vseq;

  function new(string name = "backend_exception_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    avif.sva_en = 1'b0;
    vseq = backend_exception_virt_seq::type_id::create("vseq");
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    super.run_phase(phase);
    if (!vseq.randomize())
      `uvm_fatal("RND", "Randomization failed!")
    vseq.start(env.vseqr);
    `uvm_info("TEST", "backend_exception Virtual Test Finished!", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
