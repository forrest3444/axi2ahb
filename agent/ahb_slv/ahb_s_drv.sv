`ifndef GUARD_AHB_SLAVE_DRIVER_SV
`define GUARD_AHB_SLAVE_DRIVER_SV

class ahb_slave_driver extends uvm_driver #(ahb_transaction);

  `uvm_component_utils(ahb_slave_driver)

  uvm_analysis_port    #(ahb_transaction) out_driver_port;

  virtual ahb_intf     hvif;
	ahb_slave_config     cfg;
  memory               mem;

  local int unsigned drive_count;

	uvm_event_pool events;

	function new(string name = "ahb_slave_driver", uvm_component parent);
		super.new(name, parent);
	endfunction

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		out_driver_port = new("out_driver_port", this);
		this.hvif = cfg.hvif;
		this.events = cfg.events;
		mem = new(.meminit(cfg.meminit),
		        	.min_addr(cfg.mem_min_addr),
					 	.max_addr(cfg.mem_max_addr),
						.meminit_value(cfg.meminit_value)
					);
		cfg.mem = this.mem;
	endfunction

	virtual task run_phase(uvm_phase phase);
		super.run_phase(phase);
		init_component();
		if(hvif.drv_mp.rstn === 1'b0) begin
			@(posedge hvif.drv_mp.rstn);
		end
		fork
			get_and_drive();
			wait_reset();
		join
	endtask

	extern protected virtual function void init_mem();
  extern protected virtual task init_component();
  extern protected virtual task reset_signal();
  extern protected virtual task get_and_drive();
  extern protected virtual task drive_bus();
  extern protected virtual task wait_reset();
endclass


task ahb_slave_driver::init_component();
	init_mem();
  reset_signal();
  drive_count = 0;
endtask

function void ahb_slave_driver::init_mem();
	mem.clean();
	`uvm_info("INIT_MEM", "Memory cleared during initialization/reset.", UVM_MEDIUM)
endfunction

task ahb_slave_driver::reset_signal();
  hvif.drv_cb.hresp <= 2'b0;
  hvif.drv_cb.hready <= 1'b1;
  hvif.drv_cb.hrdata <= '0;
	`uvm_info("RESET_SIGNAL", "Bus signals reset to default values.", UVM_MEDIUM)
endtask

task ahb_slave_driver::get_and_drive();
  forever begin
		drive_bus();
  end
endtask

task ahb_slave_driver::drive_bus();

  ahb_data_t        rdata;
	ahb_transaction   req;

	hvif.drv_cb.hrdata <= 'h0;
	//control phase
	//prepare slave_transaction to SINGLE transfer.
  while(hvif.drv_cb.htrans !== NONSEQ &&
       	hvif.drv_cb.htrans !== SEQ) begin
				@(hvif.drv_cb);
  end

	req = ahb_transaction::type_id::create("req", this);
	void'(req.randomize());
  drive_count++;

	//sample control phase signals
  req.start_addr = hvif.drv_cb.haddr;
  req.addr       = new[1];
  req.addr[0]    = hvif.drv_cb.haddr;
  req.write      = xact_type_e'(hvif.drv_cb.hwrite);
  req.size       = ahb_size_e'(hvif.drv_cb.hsize);
  req.burst      = SINGLE;
  req.burst_type = AHB_INCR;
	//req.wait_delay = 0;

	//response decision
	req.resp    = new[1];
	req.resp[0] = OKAY;
  if (!(mem.is_in_bounds(req.addr[0])))
	 	req.resp[0] = ERROR;
	//assert hready and hresp.
	begin
		//wait ahb slave agent to be ready.
		hvif.drv_cb.hresp <= OKAY;
		while(cfg.force_hready_low) begin
			hvif.drv_cb.hready <= 1'b0;
			@(hvif.drv_cb);
		end
		if(req.wait_delay != 0) begin
			hvif.drv_cb.hready <= 0;
			repeat(req.wait_delay) @(hvif.drv_cb);
		end
		if(req.resp[0] == ERROR) begin
			hvif.drv_cb.hresp <= ERROR;
			hvif.drv_cb.hready <= 0;
			@(hvif.drv_cb);
		end 
	  hvif.drv_cb.hready <= 1'b1;
		
	end

	//data phase
  req.data = new[1];
	//write
  if(req.write == WRITE) begin
    ahb_addr_t mem_addr = req.addr[0] & ~ahb_addr_t'(`STRB_WIDTH - 1);
		bit [`STRB_WIDTH-1:0] hwstrb;
		//enter data phase.
		@(hvif.drv_cb);
    req.data[0] = hvif.drv_cb.hwdata;
		hwstrb = hvif.drv_cb.hstrb;
		if(req.resp[0] != ERROR) begin 
			mem.write(mem_addr, req.data[0], hwstrb);
			`uvm_info("WRITE_DATA", $sformatf(
				"Write: addr=0x%0h data=0x%0h strb=0x%0h burst=%s",
				mem_addr, mem.read(mem_addr), hwstrb, req.burst.name()
			), UVM_MEDIUM);
		end
  end else begin
	//read
    ahb_addr_t mem_addr = req.addr[0] & ~ahb_addr_t'(`STRB_WIDTH - 1);
		rdata = this.mem.read(mem_addr);

    if(req.resp[0] != ERROR) begin
      hvif.drv_cb.hrdata <= rdata;
      req.data[0] = rdata;
    end else begin
      hvif.drv_cb.hrdata <= 'h0;
      req.data[0] = 'h0;
    end
		@(hvif.drv_cb);
	end
    out_driver_port.write(req);
endtask

task ahb_slave_driver::wait_reset();
  forever begin
    @(negedge hvif.drv_mp.rstn);
    `uvm_warning("WAIT_RESET", "Reset asserted.")
    init_component();
    @(posedge hvif.drv_mp.rstn);
		`uvm_info("WAIT_RESET", "Reset deasserted", UVM_MEDIUM)
  end
endtask

`endif
