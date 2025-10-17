`ifndef AXI_M_AGENT__SV
`define AXI_M_AGENT__SV

class axi_master extends uvm_agent;

    `uvm_component_utils(axi_master)
    
    // Components
    uvm_sequencer #(axi_tr #(DATA_WIDTH, ADDR_WIDTH)) w_seqr;
    uvm_sequencer #(axi_tr #(DATA_WIDTH, ADDR_WIDTH)) r_seqr;

    axi_m_driver  drv;
    axi_m_monitor mon;

    uvm_analysis_port #(axi_tr #(DATA_WIDTH, ADDR_WIDTH)) ap;

    // Variables
    env_config   env_cfg;

    function new(string name, uvm_component parent);
       super.new(name, parent);
			 ap = new("ap", this);
    endfunction //new()

    //  Function: build_phase
		function void build_phase(uvm_phase phase);

			assert (uvm_config_db #(env_config)::get(this, "", "config", env_cfg)) begin
					`uvm_info(get_name(), "vif has been found in ConfigDB.", UVM_LOW)
			end else `uvm_fatal(get_name(), "vif cannot be found in ConfigDB!")
			
			drv = axi_m_driver::type_id::create("drv", this);
			mon = axi_m_monitor::type_id::create("mon", this);

			w_seqr = uvm_sequencer #(axi_tr #(DATA_WIDTH, ADDR_WIDTH))::type_id::create("w_seqr", this);
			r_seqr = uvm_sequencer #(axi_tr #(DATA_WIDTH, ADDR_WIDTH))::type_id::create("r_seqr", this);
			
			drv.avif = env_cfg.intf.mdrv;
			mon.avif = env_cfg.intf.mmon;

    endfunction: build_phase

   
    //  Function: connect_phase
    function void connect_phase(uvm_phase phase);
			super.connect_phase(phase);

			drv.seq_item_port.connect(w_seqr.seq_item_export);
			drv.seq_item_port2.connect(r_seqr.seq_item_export);
			mon.ap.connect(ap);
    endfunction: connect_phase

   
endclass: axi_master 

`endif
