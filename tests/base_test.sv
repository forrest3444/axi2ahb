`ifndef AXI2AHB_BASE_TEST_SV
`define AXI2AHB_BASE_TEST_SV

class base_test extends uvm_test;

	`uvm_component_utils(base_test)

	virtual axi_intf           avif;
	virtual ahb_intf           hvif;
	virtual dut_dbg_if       dvif;

	axi2ahb_env                env;
	axi2ahb_config             cfg;
	uvm_event_pool             events;

	function new(string name = "base_test", uvm_component parent);
		super.new(name, parent);
	endfunction

	function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		events = new("events");
		cfg = axi2ahb_config::type_id::create("cfg");
		cfg.events = events;
		if(!(uvm_config_db #(virtual axi_intf)::get(this, "", "avif", avif))) begin
			`uvm_fatal("GETCFG", "Cannot get avif")
		end else if(avif == null) begin
			`uvm_fatal("GETCFG", "Get a null avif")
		end
		cfg.avif = this.avif;
		if(!(uvm_config_db #(virtual ahb_intf)::get(this, "", "hvif", hvif))) begin
			`uvm_fatal("GETCFG", "Cannot get hvif")
		end else if(hvif == null) begin
			`uvm_fatal("GETCFG", "Get a null hvif")
		end
		cfg.hvif = this.hvif;
		if(!(uvm_config_db #(virtual dut_dbg_if)::get(this, "", "dvif", dvif))) begin
			`uvm_fatal("GETCFG", "Cannot get dvif")
		end else if(dvif == null) begin
			`uvm_fatal("GETCFG", "Get a null dvif")
		end
		cfg.dvif = this.dvif;
		cfg.do_sub_config();
		env = axi2ahb_env::type_id::create("env", this);
		env.cfg = this.cfg;
		if(cfg.mst_cfg.avif == null || cfg.slv_cfg.hvif == null)
			`uvm_fatal("BUILD_PHASE", "Get a null vif")
	endfunction

	function void end_of_elaboration_phase(uvm_phase phase);
		uvm_root uvm_top;
		super.end_of_elaboration_phase(phase);
		uvm_top = uvm_root::get();
		uvm_top.set_timeout(cfg.timeout * 1ns);
	endfunction

	task run_phase(uvm_phase phase);
		super.run_phase(phase);
		phase.phase_done.set_drain_time(this, 1us);
		phase.raise_objection(this);
		phase.drop_objection(this);
	endtask

	function void report_phase(uvm_phase phase);
		uvm_report_server server;
		string reports = "\n";
		super.final_phase(phase);
		server = uvm_report_server::get_server();
		cfg.test_error_count = server.get_severity_count(UVM_ERROR);

		if(cfg.test_error_count == 0) begin
			cfg.test_is_passed = 1;
			`uvm_info("TEST_REPORT", "The AXI_to_AHB bridge testbench is reporting a passing status (no detected errors).", UVM_NONE)
		end
		else begin
			`uvm_info("TEST_REPORT", $sformatf("The AXI_to_AHB bridge testbench is reporting a failure status with %0d detected errors.", cfg.test_error_count), UVM_NONE)
		end
		if(cfg.test_error_count > 0) begin
			reports = {reports, ("------------------------------------------------------------------\n")};
			reports = {reports, ($sformatf(">>>>>>>   FAILED - TEST SUITE Finished With Errors - Detected %0d unexpected errors.\n", cfg.test_error_count))};
			reports = {reports, ("------------------------------------------------------------------\n")};
		end
		else begin
			reports = {reports, ("------------------------------------------------------------------\n")};
			reports = {reports, (">>>>>>>   PASSED - TEST SUITE Finished Without Errors.\n")};
			reports = {reports, ("------------------------------------------------------------------\n")};
		end
		`uvm_info("TEST_REPORT", reports, UVM_NONE)

	endfunction

endclass

`endif
		
