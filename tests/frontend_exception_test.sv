`ifndef AXI2AHB_FRONTEND_EXCEPTION_TEST_SV
`define AXI2AHB_FRONTEND_EXCEPTION_TEST_SV

class frontend_exception_test extends base_test;

  `uvm_component_utils(frontend_exception_test)

  frontend_exception_virt_seq vseq;

  function new(string name = "frontend_exception_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    avif.sva_en = 1'b0;
    vseq = frontend_exception_virt_seq::type_id::create("vseq");
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    super.run_phase(phase);
    if (!vseq.randomize())
      `uvm_fatal("RND", "Randomization failed!")
    vseq.start(env.vseqr);
    `uvm_info("TEST", "frontend_exception Virtual Test Finished!", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
