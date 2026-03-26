`ifndef AXI2AHB_ENV_SV
`define AXI2AHB_ENV_SV

class axi2ahb_env extends uvm_env;

	`uvm_component_utils(axi2ahb_env)

	axi2ahb_config             cfg;

	axi_master_agent			     mst_agt;
	ahb_slave_agent				     slv_agt;
	axi2ahb_virtual_sequencer  vseqr;
	axi2ahb_coverage           cov;
	axi2ahb_scoreboard         scb;

	function new(string name = "axi2ahb_env", uvm_component parent);
		super.new(name, parent);
	endfunction

	extern function void build_phase(uvm_phase phase);
	extern function void connect_phase(uvm_phase phase);
endclass

function void axi2ahb_env::build_phase(uvm_phase phase);
  super.build_phase(phase);

	if(cfg == null)
		`uvm_fatal(get_full_name(), "Get a null config")

	vseqr = axi2ahb_virtual_sequencer::type_id::create("vseqr", this);
	if(cfg.coverage_enable)
		cov = axi2ahb_coverage::type_id::create("cov", this);
	if(cfg.scoreboard_enable)
		scb = axi2ahb_scoreboard::type_id::create("scb", this);

	if(cfg.mst_cfg.valid == 1) begin
		mst_agt = axi_master_agent::type_id::create("mst_agt", this);
		mst_agt.cfg = cfg.mst_cfg;
	end else begin
		`uvm_fatal("build_phase", "Master agent configuration is invalid");
	end
	if(cfg.slv_cfg.valid == 1) begin
		slv_agt     = ahb_slave_agent::type_id::create("slv_agt", this);
		slv_agt.cfg = cfg.slv_cfg;
	end else begin
		`uvm_fatal("build_phase", "Slave agent configuration is invalid");
	end

  vseqr.cfg = cfg;
	if(cov != null)
		cov.cfg = cfg;
	if(scb != null)
		scb.cfg = cfg;
endfunction

function void axi2ahb_env::connect_phase(uvm_phase phase);
	super.connect_phase(phase);
	cfg.mst_cfg.events = cfg.events;
	cfg.slv_cfg.events = cfg.events;
	vseqr.axi_seqr = mst_agt.seqr;
	if(cov != null) begin
		mst_agt.out_monitor_port.connect(cov.mst_imp);
		slv_agt.out_monitor_port.connect(cov.slv_imp);
	end
	if(scb != null) begin
		mst_agt.out_monitor_port.connect(scb.mst_imp);
		slv_agt.out_monitor_port.connect(scb.slv_imp);
	end

endfunction

`endif
