`ifndef AHB_S_DRV__SV
`define AHB_S_DRV__SV

class ahb_sdriver extends uvm_driver #(ahb_tr);
	`uvm_component_utils(ahb_sdriver)

	virtual ahb_intf.sdrv   vif;
	ahb_sagent_config       sagt_cfg;
	
	function new(string name = "ahb_sdriver", uvm_component parent);
		super.new(name, parent);
	endfunction

/*==============================================================================
|                     function phase   
==============================================================================*/

	function void build_phase(uvm_phase phase);
		if(!uvm_config_db #(ahb_sagent_config)::get(this, "", "ahb_sagent", uvm_component parent);
			`uvm_fatal(get_full_name(), "Cannot get VIF from configuration database!")
	endfunction

	function void connect_phase(uvm_phase phase);
		vif = sagt_cfg.vif;
	endfunction

/*==============================================================================
|                     run phase   
==============================================================================*/

	function task run_phase(uvm_phase phase);
		forever begin
			seq_item_port.get_next_item(req);
			fork 
				begin: drv
					drive();
					disable rst;
				end
				begin: rst;
					reset_();
					disable drv;
				end
			join
			seq_item_port.item_done(req);
		end
	endtask
		
	extern task drive();
	extern task reset_();

endclass: ahb_sdriver

task ahb_sdriver::drive();
begin: driver
	if(req.response == ERROR) begin
		vif.sdrv_cb.hresp <= 1;
		vif.sdrv_cb.hready <= 0;
		@(vif.sdrv_cb);
		vif.sdrv_cb.hready <= 1;
		@(vif.sdrv_cb);
	end
	else begin

