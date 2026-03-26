`ifndef AHB_SLAVE_AGENT_SV
`define AHB_SLAVE_AGENT_SV

class ahb_slave_agent extends uvm_agent;

	ahb_slave_config       cfg;
	ahb_slave_driver       drv;
	ahb_slave_monitor      mon;

	uvm_analysis_port #(ahb_transaction)   out_monitor_port;
	uvm_analysis_port #(ahb_transaction)   out_driver_port;

	`uvm_component_utils(ahb_slave_agent)

	function new(string name = "ahb_slave_agent", uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(cfg == null) 
			`uvm_fatal("build_phase", "Get a null ahb agent configuration!")
		mon = ahb_slave_monitor::type_id::create("mon", this);
		mon.cfg = cfg;

		if(cfg.is_active == UVM_ACTIVE) begin
			drv = ahb_slave_driver::type_id::create("drv", this);
			drv.cfg = cfg;
		end
	endfunction

	virtual function void connect_phase(uvm_phase phase);
		out_monitor_port = mon.out_monitor_port;

		if(cfg.is_active == UVM_ACTIVE) begin
			out_driver_port = drv.out_driver_port;
		end
	endfunction

endclass

`endif


