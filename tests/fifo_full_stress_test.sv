`ifndef AXI2AHB_FIFO_FULL_STRESS_TEST_SV
`define AXI2AHB_FIFO_FULL_STRESS_TEST_SV

class fifo_full_stress_test extends base_test;

  `uvm_component_utils(fifo_full_stress_test)

  fifo_full_stress_virt_seq vseq;

  function new(string name = "fifo_full_stress_test", uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    cfg.scoreboard_enable = 0;
    vseq = fifo_full_stress_virt_seq::type_id::create("vseq");
  endfunction

  task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    super.run_phase(phase);
    vseq.start(env.vseqr);
    `uvm_info("TEST", "fifo_full_stress Virtual Test Finished!", UVM_LOW)
    phase.drop_objection(this);
  endtask

endclass

`endif
