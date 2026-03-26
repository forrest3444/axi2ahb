`ifndef AXI2AHB_CONFIG_SV
`define AXI2AHB_CONFIG_SV

class axi2ahb_config extends uvm_object;

	`uvm_object_utils(axi2ahb_config)

	uvm_event_pool events;
	memory   mem;

	virtual axi_intf  avif;
	virtual ahb_intf  hvif;
	virtual dut_dbg_if dvif;

	axi_master_config  mst_cfg;
	ahb_slave_config   slv_cfg;

	int unsigned seq_check_count;
	int unsigned seq_check_error;
	int unsigned seq_desired_check_count;

	int unsigned scb_check_count;
	int unsigned scb_check_error;
	int unsigned scb_desired_check_count;

	int unsigned timeout = 1_000_000;
	int unsigned test_error_count;
	bit test_is_passed;

	bit scoreboard_enable = 1;
	bit coverage_enable   = 1;

  function new(string name = "axi2ahb_agent_config");
		super.new(name);
		mst_cfg = new();
		slv_cfg = new();
	endfunction

	virtual function void add_seq_check_count(int unsigned val = 1);
		seq_check_count += val;
	endfunction

	virtual function void add_seq_check_error(int unsigned val = 1);
		seq_check_error += val;
		add_seq_check_count(val);
	endfunction

	virtual function void do_axi_config();
		mst_cfg.avif   = this.avif;
		mst_cfg.events = this.events;
	endfunction

	virtual function void do_ahb_config();
		slv_cfg.hvif   = this.hvif;
		slv_cfg.events = this.events;
	endfunction
	 
	virtual function void do_sub_config();
		do_axi_config();
		do_ahb_config();
	endfunction

endclass

`endif
