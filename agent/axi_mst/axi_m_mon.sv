`ifndef AXI_MASTER_MONITOR_SV
`define AXI_MASTER_MONITOR_SV

class axi_master_monitor extends uvm_monitor;

	uvm_analysis_port #(axi_transaction) out_monitor_port;

	virtual axi_intf avif;
	axi_master_config cfg;

	protected axi_data_t  wdata_q[$], rdata_q[$];
	protected axi_resp_e  rresp_q[$];
	protected axi_wstrb_t wstrb_q[$];

	`uvm_component_utils(axi_master_monitor)

	function new(string name = "axi_master_monitor", uvm_component parent);
			super.new(name, parent);
	endfunction 

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		out_monitor_port = new("out_monitor_port", this);
	endfunction

	virtual function void connect_phase(uvm_phase phase);
	 // super.connect_phase();
		if(cfg == null)
			`uvm_fatal("NULL_CFG", "cfg is null")
		this.avif = cfg.avif;
	endfunction

	virtual task run_phase(uvm_phase phase);
		init_component();
		fork
			monitor_write();
			monitor_read();
			wait_reset();
		join_none
	endtask

	extern protected virtual task init_component();
	extern protected virtual task monitor_write();
	extern protected virtual task monitor_read();
	extern protected virtual task assembling_and_send(axi_transaction tr);
	extern protected virtual task wait_reset();

endclass 

task axi_master_monitor::init_component();
	wdata_q.delete();
	rdata_q.delete();
	rresp_q.delete();
	wstrb_q.delete();
endtask

task axi_master_monitor::monitor_write();
	axi_transaction tr;
	int unsigned beat_num;
	int unsigned burst_len;

	forever begin
		//AW
		@(avif.mon_cb iff (avif.mon_cb.awvalid && avif.mon_cb.awready));
		tr = axi_transaction::type_id::create("tr", this);
		tr.xact_type = WRITE;
		tr.addr      = avif.mon_cb.awaddr;
		tr.len       = avif.mon_cb.awlen + 1;
		tr.burst     = axi_burst_type_e'(avif.mon_cb.awburst);
		tr.size      = axi_size_e'(avif.mon_cb.awsize);
		burst_len    = tr.len;
		beat_num     = 0;

		//W
		while(beat_num < burst_len) begin
			@(avif.mon_cb iff (avif.mon_cb.wvalid && avif.mon_cb.wready));
			wdata_q.push_back(avif.mon_cb.wdata);
			wstrb_q.push_back(avif.mon_cb.wstrb);
			if(avif.mon_cb.wlast !== (beat_num == burst_len - 1)) begin
				`uvm_error("AXI_WLAST", $sformatf("WLAST error: beat=%0d, expected=%0b, got=%0b", beat_num, (beat_num == burst_len - 1), avif.mon_cb.wlast))
			end
			beat_num++;
		end

		//B
    @(avif.mon_cb iff (avif.mon_cb.bvalid && avif.mon_cb.bready));
		tr.bresp = axi_resp_e'(avif.mon_cb.bresp);
		assembling_and_send(tr);
	end
endtask

task axi_master_monitor::monitor_read();
	axi_transaction tr;
	int unsigned beat_num;
	int unsigned burst_len;

	forever begin

		//AR
		@(avif.mon_cb iff (avif.mon_cb.arvalid && avif.mon_cb.arready));
		tr = axi_transaction::type_id::create("tr", this);
		tr.xact_type = READ;
		tr.addr      = avif.mon_cb.araddr;
		tr.len       = avif.mon_cb.arlen + 1;
		tr.burst     = axi_burst_type_e'(avif.mon_cb.arburst);
		tr.size      = axi_size_e'(avif.mon_cb.arsize);
		burst_len    = tr.len;
		beat_num     = 0;
		//R
		while(beat_num < burst_len) begin
			@(avif.mon_cb iff (avif.mon_cb.rvalid&& avif.mon_cb.rready));
			rdata_q.push_back(avif.mon_cb.rdata);
			rresp_q.push_back(axi_resp_e'(avif.mon_cb.rresp));
			if(avif.mon_cb.rlast !== (beat_num == burst_len - 1)) begin
				`uvm_error("AXI_RLAST", $sformatf("RLAST error: beat=%0d, expected=%0b, got=%0b", beat_num, (beat_num == burst_len - 1), avif.mon_cb.rlast))
			end
			beat_num++;
		end
		assembling_and_send(tr);
	end

endtask

task axi_master_monitor::assembling_and_send(axi_transaction tr);
	axi_transaction send_tr = axi_transaction::type_id::create("monitor_tr");
	send_tr.copy(tr);
	send_tr.data = new[tr.len];
	if(tr.xact_type == READ) begin
		send_tr.rresp = new[tr.len];
		for(int i = 0; i < tr.len; i++) begin
			send_tr.data[i] = rdata_q.pop_front();
			send_tr.rresp[i] = rresp_q.pop_front();
		end
	end else begin
		send_tr.wstrb = new[tr.len];
		for(int i = 0; i < tr.len; i++) begin
			send_tr.data[i] = wdata_q.pop_front();
			send_tr.wstrb[i] = wstrb_q.pop_front();
		end
	end

	if(send_tr.data.size() != (send_tr.len)) begin
		`uvm_error(
			"AXI_MON",
		 	$sformatf(
			"Write data beats mismatch: len=%0d data.size=%0d",
		 	tr.len, tr.data.size()))
	end
	`uvm_info(
		"AXI_MON",
	 	$sformatf(
		"%s transaction complete: addr=0x%0h len=%0d size=%0d burst=%s",
	 	tr.xact_type.name(), tr.addr, tr.len, tr.size, tr.burst),
	 	UVM_LOW)
	out_monitor_port.write(send_tr);
endtask

task axi_master_monitor::wait_reset();
	forever begin
		@(negedge avif.mon_mp.rstn);
		`uvm_warning("wait_reset", "Reset signal is asserted, transaction may be dropped")
		init_component();
		@(posedge avif.mon_mp.rstn);
	end
endtask

`endif
