`ifndef AXI_MASTER_AGENT_SV
`define AXI_MASTER_AGENT_SV

class axi_master_agent extends uvm_agent;

	  axi_master_config       cfg;
	  axi_master_sequencer    seqr;
	  axi_master_driver       drv;
	  axi_master_monitor      mon;

	  uvm_analysis_port #(axi_transaction)   out_monitor_port;
	  uvm_analysis_port #(axi_transaction)   out_driver_port;
		
    `uvm_component_utils(axi_master_agent)

    function new(string name = "axi_master_agent", uvm_component parent);
       super.new(name, parent);
    endfunction 

		virtual function void build_phase(uvm_phase phase);
			super.build_phase(phase);
			if(cfg == null) begin
				`uvm_fatal("build_phase", "Get a null axi agent configuration!")
			end
  		mon = axi_master_monitor::type_id::create("mon", this);
  		mon.cfg = cfg;

  		if(cfg.is_active == UVM_ACTIVE) begin
				drv = axi_master_driver::type_id::create("drv", this);
				seqr = axi_master_sequencer::type_id::create("seqr", this);
				drv.cfg = cfg;
				seqr.cfg = cfg;
			end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);
			out_monitor_port = mon.out_monitor_port;
			if(cfg.is_active == UVM_ACTIVE) begin
				drv.seq_item_port.connect(seqr.seq_item_export);
				out_driver_port = drv.out_driver_port;
			end
    endfunction
endclass 

`endif
