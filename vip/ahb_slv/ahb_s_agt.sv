`ifndef AHB_S_AGT__SV
`define AHB_S_AGT__SV
 
class ahb_slave extends uvm_agent;

	`uvm_component_utils(ahb_slave)

	ahb_s_driver      sdrv;
	ahb_s_monitor     smon;

	uvm_analysis_port #(ahb_tr #(DATA_WIDTH, ADDR_WIDTH)  sagt_ap;

	env_config env_cfg;

	function new(string name = "ahb_sagent", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		env_cfg = new("env_cfg");
		assert (uvm_config_db #(env_config)::get(this, "", "config", env_cfg)) begin
			`uvm_info(get_full_name(), "vif has been found in ConfigDB.", UVM_LOW)
		end else
			`uvm_fatal(get_full_name(), "vif cannot be found in ConfigDB!")

		sdrv = ahb_s_driver::type_id::create("sdrv", this);
		smon = ahb_s_monitor::type_id::create("smon", this);

		sdrv.hvif = env_cfg.hintf;
		smon.hvif = env_cfg.hintf;

		ap = new("ap", this);
	endfunction: build_phase

	function void connect_phase(uvm_phase phase);
		super.connect_phase(phase);
		smon.ap.connect(sagt_ap);
	endfunction: connect_phase

