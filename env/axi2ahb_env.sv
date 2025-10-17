`ifndef AXI2AHB_ENV__SV
`define AXI2AHB_ENV__SV

class axi2ahb_env extends uvm_env;
	`uvm_component_utils(axi_env)

	axi_master			master;
	ahb_slave				slave;
  axi_scoreboard	scb;

	env_config			env_cfg;

	function new(string name, uvm_component parent);
		super.new(name, parent);
	endfunction

	extern function void build_phase(uvm_phase phase);
	extern function void connect_phase(uvm_phase phase);
endclass

function void axi2ahb_env::build_phase(uvm_phase phase);

	master = axi_master::type_id::create("master", this);
	slave = ahb_slave::type_id::create("master", this);
	scb = axi_scoreboard::type_id::create("scb", this);
endfunction: build_phase

function void axi2ahb_env::connect_phase(uvm_phase phase);
	super.connect_phase(phase);

	master.ap.connect(scb.m_ap_imp);
	slave.ap.connect(scb.s_ap_imp);
endfunction: connect_phase

`endif
