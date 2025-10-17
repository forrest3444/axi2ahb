`ifndef AXIL_DRIVER__SV
`define AXIL_DRIVER__SV

class axil_driver extends uvm_driver#(axil_transaction);
	`uvm_component_utils(axil_driver)

	virtual axil_if vif;

	function new(string name = "axil_driver", uvm_component parent = null);
		super.new(name, parent);
	endfunction

/*==============================================================================
|                             build phase                                                  
==============================================================================*/

	virtual function void build_phase(uvm_phase phase);
		super.build_phase(phase);
		if(!uvm_config_db#(virtual axil_if)::get(this, "", "vif",vif))
			`uvm_fatal("axil_driver", "virtual interface must be set for axil_if!!!")
	endfunction

/*==============================================================================
|                             run phase                                                  
==============================================================================*/

	virtual task run_phase(uvm_phase phase);
		fork
			do_reset();
			do_drive();
		join
	endtask

/*==============================================================================
|                        extern defination                                                       
==============================================================================*/

	extern virtual task do_reset();
  extern virtual task do_drive();
	extern virtual task drive_transfer(axil_transaction tr);
	extern virtual task drive_address_phase(axil_transaction tr);
	extern virtual task drive_data_phase(axil_transaction tr);
	extern virtual task drive_write_address_channel(axil_transaction tr);
	extern virtual task drive_write_data_channel(axil_transaction tr);
	extern virtual task drive_read_address_channel(axil_transaction tr);
	extern virtual task drive_read_data_channel(input bit [31:0] data, output bit err);

endclass

/*==============================================================================
|                             reset signals                                                  
==============================================================================*/

task axil_driver::do_reset();
    vif.master_cb.awaddr  <= '0;
    vif.master_cb.awvalid <= '0;
    vif.master_cb.wdata   <= '0;
    vif.master_cb.wstrb   <= '0;
    vif.master_cb.wvalid  <= '0;
    vif.master_cb.bready  <= '0;
    vif.master_cb.araddr  <= '0;
    vif.master_cb.arvalid <= '0;
    vif.master_cb.rready  <= '0;
		forever begin
			@(negedge vif.rst_n);
	    vif.master_cb.awaddr  <= '0;
			vif.master_cb.awvalid <= '0;
			vif.master_cb.wdata   <= '0;
			vif.master_cb.wstrb   <= '0;
			vif.master_cb.wvalid  <= '0;
			vif.master_cb.bready  <= '0;
			vif.master_cb.araddr  <= '0;
			vif.master_cb.arvalid <= '0;
			vif.master_cb.rready  <= '0;
		end
endtask

/*==============================================================================
|                             drive signals                                                  
==============================================================================*/

task axil_driver::do_drive();
	forever begin
		axil_transaction  tr;
		@(posedge vif.clk);
		if (vif.rst_n == 1'b0) begin
			@(posedge vif.rst_n);
			@(posedge vif.clk);
		end
		seq_item_port.get_next_item(tr);
		drive_transfer(tr);
	  `uvm_info(get_type_name(), $sformatf("Driving transaction: %s", tr.sprint()), UVM_MEDIUM);
		seq_item_port.item_done(tr);
	end
endtask

/*==============================================================================
|                             drive transfer                                                  
==============================================================================*/

task axil_driver::drive_transfer(axil_transaction tr);
	drive_address_phase(tr);
	drive_data_phase(tr);
endtask

/*==============================================================================
|                             drive address phase                                                  
==============================================================================*/

task axil_driver::drive_address_phase(axil_transaction tr);
	`uvm_info("axil_driver", "drive_address_phase", UVM_MEDIUM);
	case (tr.op)
		WRITE : drive_write_address_channel(tr);
		READ  : drive_read_address_channel(tr);
	endcase
endtask

/*==============================================================================
|                             drive data phase                                                  
==============================================================================*/

task axil_driver::drive_data_phase(axil_transaction tr);
	bit [31:0] data;
	bit err;

	data = tr.data;
	`uvm_info("axil_driver", "drive_data_phase", UVM_MEDIUM);
	case (tr.op)
		WRITE : drive_write_data_channel(tr);
		READ  : drive_read_data_channel(data, err);
	endcase
endtask

/*==============================================================================
|                             write address channel                                                  
==============================================================================*/

task axil_driver::drive_write_address_channel(axil_transaction tr);
	int to_ctr;

	vif.master_cb.awaddr <= tr.addr;
	vif.master_cb.awvalid <= 1'b1;
	for(to_ctr = 0;to_ctr <= 31; to_ctr++) begin
		@(posedge vif.clk);
		if(vif.master_cb.awready) break;
	end
	if(to_ctr == 31) begin
		`uvm_error("axil_driver", "awvalid timeout");
	end
	@(posedge vif.clk);
	vif.master_cb.awaddr <= 32'h0;
	vif.master_cb.awvalid <= 1'b0;
endtask

/*==============================================================================
|                        write data channel & write response                                                  
==============================================================================*/

task axil_driver::drive_write_data_channel(axil_transaction tr);
	int to_ctr;

	vif.master_cb.wdata <= tr.data;
	vif.master_cb.wstrb <= tr.wstrb;
	vif.master_cb.wvalid <= 1'b1;
	for(to_ctr = 0; to_ctr <= 31; to_ctr++) begin
		@(posedge vif.clk);
		if(vif.master_cb.wready) break;
	end
	if(to_ctr == 31) begin
		`uvm_error("axil_driver", "wready timeout");
	end
	@(posedge vif.clk);
	vif.master_cb.wdata <= '0;
	vif.master_cb.wstrb <= '0;
	vif.master_cb.wvalid <= '0;

	for(to_ctr = 0; to_ctr <= 31; to_ctr++) begin
		@(posedge vif.clk);
		if(vif.master_cb.bvalid) break;
	end
	if(to_ctr == 31) begin
		`uvm_error("axil_driver", "bvalid timeout");
	end
	else begin
		if(vif.master_cb.bvalid && vif.bresp != OKAY) begin
			`uvm_error("axil_driver", "received error write response");
		end
		vif.master_cb.bready <= vif.master_cb.bvalid;
		@(posedge vif.clk);
	end
endtask
			
/*==============================================================================
|                        drive_read_address_channel
==============================================================================*/

task axil_driver::drive_read_address_channel(axil_transaction tr);
	int to_ctr;

	vif.master_cb.araddr <= tr.addr;
	vif.master_cb.arvalid <= 1'b1;
	for(to_ctr = 0; to_ctr <= 31; to_ctr++) begin
		@(posedge vif.clk);
		if(vif.master_cb.arready) break;
	end
	if(to_ctr == 31) begin
		`uvm_error("axil_driver", "arready timeout");
	end
	@(posedge vif.clk);
	vif.master_cb.araddr <= '0;
	vif.master_cb.arvalid <= '0;
endtask

/*==============================================================================
|                       drive_read_data_channel & read response 
==============================================================================*/

task axil_driver::drive_read_data_channel(input bit [31:0] data, output bit err);
	int to_ctr;

	for(to_ctr = 0; to_ctr <= 31; to_ctr++) begin
		@(posedge vif.clk);
		if(vif.master_cb.rvalid) break;
	end
	data = vif.master_cb.rdata;
	if(to_ctr == 31) begin
		`uvm_error("axil_driver", "rvalid timeout");
	end
	else begin 
		if(vif.rvalid == 1'b1 && vif.master_cb.rresp != OKAY)
			`uvm_error("axil_driver","Received error read response");
		vif.rready <= vif.master_cb.rvalid;
		@(posedge vif.clk);
	end
endtask

`endif

