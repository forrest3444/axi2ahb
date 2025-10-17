`ifndef AXI_M_MONITOR__SV
`define AXI_M_MONITOR__SV

class axi_m_monitor extends uvm_monitor;

    `uvm_component_utils(axi_m_monitor)

    // Components
    uvm_analysis_port #(axi_tr #(DATA_WIDTH, ADDR_WIDTH)) ap;
    virtual axi_intf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)).mmon avif;
    // variables
    axi_tr #(DATA_WIDTH, ADDR_WIDTH) w_tr, r_tr;
    bit w_done, r_done;
    int b_size;
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
				ap = new("ap", this);
        w_done = 1;
        r_done = 1;
    endfunction: new 

		task run_phase(uvm_phase phase);
			forever begin
				run_mon(phase);
				@(avif.mon_cb);
			end
		endtask: run_phase

    extern task run_mon(uvm_phase phase);
    extern task write_monitor();
    extern task read_monitor();
    
endclass: axi_m_monitor 

task axi_m_monitor::run_mon(uvm_phase phase);
    fork
        if(w_done) begin
            phase.raise_objection(this);
            w_done = 0;
            write_monitor();
            w_done = 1;
            phase.drop_objection(this);
        end
        if(r_done) begin
            phase.raise_objection(this);
            r_done = 0;
            read_monitor();
            r_done = 1;
            phase.drop_objection(this);
        end
        
    join_none
endtask: run_mon

task axi_m_monitor::write_monitor();
    if(avif.mon_cb.awvalid && avif.mon_cb.awready) begin
        w_tr         = axi_tr #(DATA_WIDTH, ADDR_WIDTH)::type_id::create("w_tr");
        w_tr.addr    = avif.mon_cb.awaddr;
        w_tr.b_size  = avif.mon_cb.awsize;
        w_tr.b_len   = avif.mon_cb.awlen;
        w_tr.b_type  = B_TYPE'(avif.mon_cb.awburst);
        w_tr.data    = new [w_tr.b_len+1];
        for (int i=0; i<w_tr.b_len+1; i++) begin
            @(avif.mon_cb);
            wait(avif.mon_cb.WVALID && avif.mon_cb.WREADY);
            w_tr.data[i] = new [DATA_WIDTH/8];
            for (int j=0; j<DATA_WIDTH/8; j++) begin
                w_tr.data[i][j] = avif.mon_cb.wdata[8*j+:8];
            end
        end
        wait(avif.mon_cb.bvalid);
        w_tr.b_resp = avif.mon_cb.bresp;
        ap.write(w_tr);
        `uvm_info("mmon", $sformatf("Wtr %s", w_tr.convert2string()), UVM_HIGH)
    end
endtask: write_monitor

task axi_m_monitor::read_monitor();
    if(avif.mon_cb.arvalid && avif.mon_cb.arready) begin
        r_tr         = axi_tr #(DATA_WIDTH, ADDR_WIDTH)::type_id::create("r_tr");
        r_tr.addr    = avif.mon_cb.araddr;
        r_tr.b_size  = avif.mon_cb.arsize;
        r_tr.b_len   = avif.mon_cb.arlen;
        r_tr.b_type  = B_TYPE'(avif.mon_cb.arburst);
        r_tr.data    = new [r_tr.b_len+1];
        r_tr.r_resp  = new [r_tr.b_len+1];
        for (int i=0; i<r_tr.b_len+1; i++) begin
            @(avif.mon_cb);
            wait(avif.mon_cb.rvalid && avif.mon_cb.rready);
            r_tr.data[i] = new [DATA_WIDTH/8];
            for (int j=0; j<DATA_WIDTH/8; j++) begin
                r_tr.data[i][j] = avif.mon_cb.rdata[8*j+:8];
            end
            r_tr.r_resp[i] = avif.mon_cb.rresp;
        end
        ap.write(r_tr);
        `uvm_info("mmon", $sformatf("Rtr %s", r_tr.convert2string()), UVM_HIGH)
    end
endtask: read_monitor

`endif
