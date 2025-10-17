`ifndef AXI_M_DRIVER__SV
`define AXI_M_DRIVER__SV

class axi_m_driver extends uvm_driver #(axi_tr #(DATA_WIDTH, ADDR_WIDTH)) ;

    `uvm_component_utils(axi_m_driver)
    
    // Components
    virtual axi_intf #(.DATA_WIDTH(DATA_WIDTH), .ADDR_WIDTH(ADDR_WIDTH)).mdrv avif;
    //uvm_seq_item_pull_port #(REQ, RSP) seq_item_port2;

    // Variables
    //REQ w_trans, r_trans;
    bit w_done, r_done;
    bit [DATA_WIDTH-1:0] temp [];
    logic awvalid;

		function new(string name, uvm_component parent);
        super.new(name, parent);
        w_done = 1;
        r_done = 1;
        seq_item_port2 = new("seq_item_port2", this);
    endfunction 

		virtual task run_phase(uvm_phase phase);
				`uvm_info("DEBUG", "started master driver", UVM_HIGH)
				// temp 
				@(avif.m_drv_cb);
				avif.m_drv_cb.bready <= 1;
				avif.m_drv_cb.rready <= 1;
				forever begin
						drive();
						#1;
				end
		endtask: run_phase

    // Methods
    extern task drive();
    extern task send_write_address();
    extern task send_read_address();
    extern task send_write_data();
    // extern task send_read_data();

endclass 

task axi_m_driver::drive();
    if(!avif.rstn) begin
        avif.m_drv_cb.awvalid <= 0;
        avif.m_drv_cb.wvalid  <= 0;
        avif.m_drv_cb.arvalid <= 0;
        return;
    end
    fork
        begin
            `uvm_info("DEBUG", $sformatf("w_addr(), w_done = %0d", w_done), UVM_DEBUG)
            if(w_done) begin
                w_done = 0;
                seq_item_port.get_next_item(w_trans);
                `uvm_info(get_name(), "Write Packet received in master driver", UVM_LOW)
                w_trans.print();
                fork
                    send_write_address();
                    send_write_data();
                join
                seq_item_port.item_done();
                w_done = 1;
            end
        end
        begin
            `uvm_info("DEBUG", $sformatf("r_addr(), r_done = %0d", r_done), UVM_DEBUG)
            if(r_done) begin
                r_done = 0;
                seq_item_port2.get_next_item(r_trans);
                `uvm_info(get_name(), "Read Packet received in master driver", UVM_LOW)
                r_trans.print();
                send_read_address();
                seq_item_port2.item_done();
                r_done = 1;
            end
        end
    join_none
endtask: drive

task axi_m_driver::send_write_address();
    `uvm_info("DEBUG", "Inside send_write_address()", UVM_HIGH)
    
    // Drive all the data
    @(avif.m_drv_cb);
    avif.m_drv_cb.awaddr <= w_trans.addr;
    avif.m_drv_cb.awlen  <= w_trans.b_len;
    avif.m_drv_cb.awsize <= w_trans.b_size;
    avif.m_drv_cb.awburst<= w_trans.b_type;
    `uvm_info("DEBUG", "Data Driven", UVM_HIGH)

    // Wait 1 cycle and drive AWVALID
    @(avif.m_drv_cb);
    awvalid              = 1;
    avif.m_drv_cb.awvalid <= awvalid;
    `uvm_info("DEBUG", "Asserted AWVALID", UVM_HIGH)

    // Wait for AWREADY and deassert AWVALID
    @(avif.m_drv_cb);
    wait(avif.m_drv_cb.awready);
    awvalid              = 0;
    avif.m_drv_cb.awvalid <= awvalid;
    `uvm_info("DEBUG", "Deasserted AWVALID", UVM_HIGH)

    // Wait for write data channel to complete transaction
    wait(avif.m_drv_cb.bvalid);
endtask: send_write_address

task axi_m_driver::send_write_data();
    int len = w_trans.b_len + 1;//burst len
    temp = new[len];
    `uvm_info("DEBUG", "Inside send_write_data()", UVM_HIGH)
    foreach ( w_trans.data[i,j] ) begin
        temp[i][8*j+:8] = w_trans.data[i][j];
    end
    wait(awvalid && avif.m_drv_cb.awready);
    `uvm_info("DEBUG", "packed data", UVM_HIGH)
    for (int i=0; i<len; i++) begin
        `uvm_info("DEBUG", $sformatf("Inside loop: iter %0d", i), UVM_HIGH)
        @(avif.m_drv_cb);
        avif.m_drv_cb.wdata  <= temp[i];
        avif.m_drv_cb.wlast  <= (i == len-1) ? 1:0;

        // assert wvalid
        @(avif.m_drv_cb);
        avif.m_drv_cb.wvalid <= 1;

        // wait for wready and deassert wvalid
        #1;
        wait(avif.m_drv_cb.wready);
        avif.m_drv_cb.wvalid <= 0;
        avif.m_drv_cb.wlast  <= 0;
    end
    wait(avif.m_drv_cb.bvalid);
endtask: send_write_data

task axi_m_driver::send_read_address();
    // Send the read address and control signals
    @(avif.m_drv_cb);
    avif.m_drv_cb.araddr <= r_trans.addr;
    avif.m_drv_cb.arlen  <= r_trans.b_len;
    avif.m_drv_cb.arsize <= r_trans.b_size;
    avif.m_drv_cb.arburst<= r_trans.b_type;

    // assert arvalid after one clock cycle
    @(avif.m_drv_cb);
    avif.m_drv_cb.arvalid<= 1;

    // wait for awready and deassert awvalid
    @(avif.m_drv_cb);
    wait(avif.m_drv_cb.arready);
    avif.m_drv_cb.arvalid<= 0;

    // wait for rlast signal before sending next address
    wait(avif.m_drv_cb.rlast && avif.m_drv_cb.rvalid);
endtask: send_read_address

`endif
