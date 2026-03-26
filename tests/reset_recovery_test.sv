`ifndef AXI2AHB_RESET_RECOVERY_TEST_SV
`define AXI2AHB_RESET_RECOVERY_TEST_SV

class reset_recovery_test extends base_test;

  `uvm_component_utils(reset_recovery_test)

  reset_recovery_virt_seq vseq;

  function new(string name = "reset_recovery_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    vseq = reset_recovery_virt_seq::type_id::create("vseq");
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    super.run_phase(phase);
    vseq.start(env.vseqr);
    `uvm_info("TEST", "reset_recovery Virtual Test Finished!", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
