`ifndef AXI_MASTER_DRIVER_SV
`define AXI_MASTER_DRIVER_SV

class axi_master_driver extends uvm_driver #(axi_transaction);

	`uvm_component_utils(axi_master_driver)

	uvm_analysis_port #(axi_transaction) out_driver_port;
	
	virtual axi_intf avif;
	axi_master_config cfg;
	axi_transaction tr;
	axi_transaction pending_write_q[$];
	axi_transaction pending_read_q[$];

	function new(string name = "axi_master_driver", uvm_component parent);
		super.new(name, parent);
	endfunction 

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		out_driver_port = new("out_driver_port", this);
		if(cfg == null) 
			`uvm_fatal("NULL_CFG", "Get a null axi master config")
		else if(cfg.avif == null)
			`uvm_fatal("NULL_VIF", "Get a null axi vif")
		else 
			this.avif = cfg.avif;
	endfunction

	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		init_component();
		fork
			get_and_drive();
			collect_b_responses();
			collect_r_responses();
			wait_reset();
		join
	endtask

	extern protected virtual task init_component();
	extern protected virtual task reset_signal();
	extern protected virtual task get_and_drive();
	extern protected virtual task cmd_phase(input axi_transaction tr);
	extern protected virtual task write_data_phase(input axi_transaction tr);
	extern protected virtual task collect_b_responses();
	extern protected virtual task collect_r_responses();
	extern protected virtual task wait_reset();
	extern protected virtual task send_response(input axi_transaction tr);
	extern protected virtual function int unsigned sample_cmd_valid_delay();
	extern protected virtual function int unsigned sample_w_valid_delay();
	extern protected virtual function bit sample_bready_value(input int unsigned low_streak);
	extern protected virtual function bit sample_rready_value(input int unsigned low_streak);
			
endclass 

task axi_master_driver::init_component();
	reset_signal();
	pending_write_q.delete();
	pending_read_q.delete();
endtask 

task axi_master_driver::reset_signal();
	//AW
  avif.drv_cb.awaddr  <= 'h0;
  avif.drv_cb.awburst <= 'h0;
  avif.drv_cb.awlen   <= 'h0;
  avif.drv_cb.awsize  <= 'h0;
  avif.drv_cb.awvalid <= 'h0;
	//W
  avif.drv_cb.wdata   <= 'h0;
  avif.drv_cb.wstrb   <= 'h0;
  avif.drv_cb.wlast   <= 'h0;
  avif.drv_cb.wvalid  <= 'h0;
	//B
  avif.drv_cb.bready  <= 'h0;
	//AR
  avif.drv_cb.araddr  <= 'h0;
  avif.drv_cb.arburst <= 'h0;
  avif.drv_cb.arlen   <= 'h0;
  avif.drv_cb.arsize  <= 'h0;
  avif.drv_cb.arvalid <= 'h0;
	//R
  avif.drv_cb.rready  <= 'h0;
endtask 

task axi_master_driver::get_and_drive();
	axi_transaction launched_tr;
	forever begin
		while(avif.drv_mp.rstn === 1'b0) begin
			@(posedge avif.drv_mp.rstn);
		end
		seq_item_port.get_next_item(tr);

		launched_tr = axi_transaction::type_id::create("launched_tr");
		launched_tr.set_id_info(tr);
		launched_tr.copy(tr);

		if(launched_tr.xact_type == WRITE) begin
			fork
				cmd_phase(launched_tr);
				write_data_phase(launched_tr);
			join
			pending_write_q.push_back(launched_tr);
		end
		else begin
			launched_tr.data  = new[launched_tr.len];
			launched_tr.rresp = new[launched_tr.len];
			cmd_phase(launched_tr);
			pending_read_q.push_back(launched_tr);
		end

		seq_item_port.item_done();
		out_driver_port.write(launched_tr);
	end
endtask 

task axi_master_driver::cmd_phase(input axi_transaction tr);
	int unsigned cmd_timeout_cycles;
	int unsigned valid_delay_cycles;
	int unsigned wait_cycles;
	bit handshake_done;
	axi_transaction cur_tr = axi_transaction::type_id::create("cur_tr");

	cur_tr.copy(tr);
	cmd_timeout_cycles = 32 + `MAX_DELAY;
	`uvm_info("cmd_phase", "Transaction start", UVM_MEDIUM)

	case(cur_tr.xact_type)
		WRITE: begin
			`uvm_info("cmd_phase", "Write transaction start", UVM_MEDIUM)
			@(avif.drv_cb);
			avif.drv_cb.awaddr  <= cur_tr.addr;
			avif.drv_cb.awburst <= cur_tr.burst;
			avif.drv_cb.awlen   <= cur_tr.len - 1;
			avif.drv_cb.awsize  <= cur_tr.size;
			avif.drv_cb.awvalid <= 1'b0;

			valid_delay_cycles = sample_cmd_valid_delay();
			repeat(valid_delay_cycles) @(avif.drv_cb);

			avif.drv_cb.awvalid <= 1'b1;
			handshake_done = 1'b0;
			for(wait_cycles = 0; wait_cycles < cmd_timeout_cycles; wait_cycles++) begin
				@(avif.drv_cb);
				if(avif.drv_cb.awready) begin
					handshake_done = 1'b1;
					break;
				end
			end

			if(!handshake_done) begin
				`uvm_fatal("AW_CH", $sformatf("AW handshake timeout after %0d cycles", cmd_timeout_cycles))
			end

			avif.drv_cb.awaddr  <= 'h0;
			avif.drv_cb.awburst <= 'h0;
			avif.drv_cb.awlen   <= 'h0;
			avif.drv_cb.awsize  <= 'h0;
			avif.drv_cb.awvalid <= 1'b0;
		end

		READ: begin
			`uvm_info("cmd_phase", "Read transaction start", UVM_MEDIUM)
			@(avif.drv_cb);
			avif.drv_cb.araddr  <= cur_tr.addr;
			avif.drv_cb.arburst <= cur_tr.burst;
			avif.drv_cb.arlen   <= cur_tr.len - 1;
			avif.drv_cb.arsize  <= cur_tr.size;
			avif.drv_cb.arvalid <= 1'b0;

			valid_delay_cycles = sample_cmd_valid_delay();
			repeat(valid_delay_cycles) @(avif.drv_cb);

			avif.drv_cb.arvalid <= 1'b1;
			handshake_done = 1'b0;
			for(wait_cycles = 0; wait_cycles < cmd_timeout_cycles; wait_cycles++) begin
				@(avif.drv_cb);
				if(avif.drv_cb.arready) begin
					handshake_done = 1'b1;
					break;
				end
			end

			if(!handshake_done) begin
				`uvm_fatal("AR_CH", $sformatf("AR handshake timeout after %0d cycles", cmd_timeout_cycles))
			end

			avif.drv_cb.araddr  <= 'h0;
			avif.drv_cb.arburst <= 'h0;
			avif.drv_cb.arlen   <= 'h0;
			avif.drv_cb.arsize  <= 'h0;
			avif.drv_cb.arvalid <= 1'b0;
		end
		default: begin
			`uvm_fatal("INVALID_XACT", $sformatf("Unknown xact_type: %s", cur_tr.xact_type.name()))
		end
	endcase

	`uvm_info("cmd_phase", "Transaction end", UVM_HIGH)
endtask

task axi_master_driver::write_data_phase(input axi_transaction tr);
	int unsigned beat_num;
	int unsigned burst_len;
	int unsigned wait_cycles;
	int unsigned valid_delay_cycles;
	bit handshake_done;
	axi_transaction cur_tr = axi_transaction::type_id::create("cur_tr");

	cur_tr.copy(tr);
	burst_len = cur_tr.len;

	beat_num = 0;
	avif.drv_cb.wvalid <= 1'b0;
	avif.drv_cb.wlast  <= 1'b0;

	while(beat_num < burst_len) begin
		valid_delay_cycles = sample_w_valid_delay();

		if((beat_num == 0) || (valid_delay_cycles > 0)) begin
			avif.drv_cb.wvalid <= 1'b0;
			avif.drv_cb.wdata  <= cur_tr.data[beat_num];
			avif.drv_cb.wstrb  <= cur_tr.wstrb[beat_num];
			avif.drv_cb.wlast  <= (beat_num == burst_len - 1);
			repeat(valid_delay_cycles) @(avif.drv_cb);
			avif.drv_cb.wvalid <= 1'b1;
		end
		else begin
			avif.drv_cb.wvalid <= 1'b1;
			avif.drv_cb.wdata  <= cur_tr.data[beat_num];
			avif.drv_cb.wstrb  <= cur_tr.wstrb[beat_num];
			avif.drv_cb.wlast  <= (beat_num == burst_len - 1);
		end

		handshake_done = 1'b0;
		for(wait_cycles = 0; wait_cycles < (32 + `MAX_DELAY); wait_cycles++) begin
			@(avif.drv_cb);
			if(avif.drv_cb.wready) begin
				handshake_done = 1'b1;
				break;
			end
		end

		if(!handshake_done) begin
			`uvm_fatal("W_CH", $sformatf("W channel handshake timeout after %0d cycles", 32 + `MAX_DELAY))
		end

		beat_num++;
	end

	avif.drv_cb.wvalid <= 1'b0;
	avif.drv_cb.wlast  <= 1'b0;
	avif.drv_cb.wdata  <= '0;
	avif.drv_cb.wstrb  <= '0;
endtask

task axi_master_driver::collect_b_responses();
	int unsigned burst_len;
	int unsigned rsp_timeout_cycles;
	int unsigned ready_low_streak;
	int unsigned active_wait_cycles;
	bit handshake_done;
	bit ready_value;
	axi_transaction rsp_tr;

	forever begin
		while((avif.drv_mp.rstn === 1'b0) || (pending_write_q.size() == 0)) begin
			@(avif.drv_cb);
		end

		rsp_tr = pending_write_q.pop_front();
		burst_len = rsp_tr.len;
		rsp_timeout_cycles = 32 + (burst_len * ((2 * `MAX_DELAY) + 4)) + `MAX_DELAY;
		if(rsp_timeout_cycles < 4096)
			rsp_timeout_cycles = 4096;
		ready_low_streak = 0;
		active_wait_cycles = 0;
		handshake_done = 1'b0;

		while(!handshake_done) begin
			if(cfg.force_bready_low)
				ready_value = 1'b0;
			else
				ready_value = sample_bready_value(ready_low_streak);

			avif.drv_cb.bready <= ready_value;
			@(avif.drv_cb);

			if(avif.drv_mp.rstn === 1'b0)
				break;

			if(avif.drv_cb.bvalid && ready_value) begin
				handshake_done = 1'b1;
				break;
			end

			if(cfg.force_bready_low)
				continue;

			if(ready_value)
				ready_low_streak = 0;
			else
				ready_low_streak++;

			active_wait_cycles++;
			if(active_wait_cycles >= rsp_timeout_cycles)
				`uvm_fatal("B_CH", $sformatf("B channel handshake timeout after %0d active cycles", rsp_timeout_cycles))
		end

		rsp_tr.bresp = axi_resp_e'(avif.drv_cb.bresp);
		avif.drv_cb.bready <= 1'b0;

		if(avif.drv_mp.rstn === 1'b1)
			send_response(rsp_tr);
	end
endtask

task axi_master_driver::collect_r_responses();
	int unsigned beat_num;
	int unsigned burst_len;
	int unsigned rsp_timeout_cycles;
	int unsigned ready_low_streak;
	int unsigned active_wait_cycles;
	bit handshake_done;
	bit ready_value;
	axi_transaction rsp_tr;

	forever begin
		while((avif.drv_mp.rstn === 1'b0) || (pending_read_q.size() == 0)) begin
			@(avif.drv_cb);
		end

		rsp_tr = pending_read_q.pop_front();
		burst_len = rsp_tr.len;
		rsp_timeout_cycles = 32 + (burst_len * ((2 * `MAX_DELAY) + 4)) + `MAX_DELAY;
		if(rsp_timeout_cycles < 4096)
			rsp_timeout_cycles = 4096;
		beat_num = 0;
		ready_low_streak = 0;

		while(beat_num < burst_len) begin
			active_wait_cycles = 0;
			handshake_done = 1'b0;

			while(!handshake_done) begin
				if(cfg.force_rready_low)
					ready_value = 1'b0;
				else
					ready_value = sample_rready_value(ready_low_streak);

				avif.drv_cb.rready <= ready_value;
				@(avif.drv_cb);

				if(avif.drv_mp.rstn === 1'b0)
					break;

				if(avif.drv_cb.rvalid && ready_value) begin
					handshake_done = 1'b1;
					break;
				end

				if(cfg.force_rready_low)
					continue;

				if(ready_value)
					ready_low_streak = 0;
				else
					ready_low_streak++;

				active_wait_cycles++;
				if(active_wait_cycles >= rsp_timeout_cycles)
					`uvm_fatal("R_CH", $sformatf("R channel handshake timeout after %0d active cycles", rsp_timeout_cycles))
			end

			if(avif.drv_mp.rstn === 1'b0)
				break;

			ready_low_streak       = 0;
			rsp_tr.data[beat_num]  = avif.drv_cb.rdata;
			rsp_tr.rresp[beat_num] = axi_resp_e'(avif.drv_cb.rresp);
			if(avif.drv_cb.rlast !== (beat_num == burst_len - 1)) begin
				`uvm_error(
					"AXI_rlast",
				 	$sformatf(
						"RLAST error: beat=%0d, expected=%0b, got=%0b",
				 	beat_num,
				 	(beat_num == burst_len - 1),
				 	avif.drv_cb.rlast
					)
				)
			end
			beat_num++;
		end

		avif.drv_cb.rready <= 1'b0;

		if((avif.drv_mp.rstn === 1'b1) && (beat_num == burst_len))
			send_response(rsp_tr);
	end
endtask

task axi_master_driver::send_response(input axi_transaction tr);
	axi_transaction rsp = axi_transaction::type_id::create("rsp");
	rsp.set_id_info(tr);
	rsp.copy(tr);
	seq_item_port.put_response(rsp);
endtask 

task axi_master_driver::wait_reset();
	forever begin
		@(negedge avif.drv_mp.rstn);
		`uvm_warning("wait_reset", "Reset signal is asserted, transaction may be dropped")
		init_component();
		@(posedge avif.drv_mp.rstn);
	end
endtask 

function int unsigned axi_master_driver::sample_cmd_valid_delay();
	int unsigned roll;
	roll = $urandom_range(99, 0);
	if(roll < 55) begin
		return 0;
	end
	if(roll < 80) begin
		return 1;
	end
	if(roll < 92) begin
		return 2;
	end
	if(roll < 97) begin
		return 3;
	end
	if(`MAX_DELAY <= 4) begin
		return `MAX_DELAY;
	end
	return $urandom_range(`MAX_DELAY, 4);
endfunction

function int unsigned axi_master_driver::sample_w_valid_delay();
	int unsigned roll;
	roll = $urandom_range(99, 0);
	if(roll < 65) begin
		return 0;
	end
	if(roll < 88) begin
		return 1;
	end
	if(roll < 96) begin
		return 2;
	end
	if(roll < 99) begin
		return 3;
	end
	if(`MAX_DELAY <= 4) begin
		return `MAX_DELAY;
	end
	return $urandom_range(4, (`MAX_DELAY < 5) ? `MAX_DELAY : 5);
endfunction

function bit axi_master_driver::sample_bready_value(input int unsigned low_streak);
	int unsigned roll;
	if(low_streak >= `MAX_DELAY) begin
		return 1'b1;
	end
	roll = $urandom_range(99, 0);
	if(low_streak == 0) begin
		return (roll < 85);
	end
	return (roll < 65);
endfunction

function bit axi_master_driver::sample_rready_value(input int unsigned low_streak);
	int unsigned roll;
	if(low_streak >= `MAX_DELAY) begin
		return 1'b1;
	end
	roll = $urandom_range(99, 0);
	if(low_streak == 0) begin
		return (roll < 80);
	end
	return (roll < 60);
endfunction

`endif
