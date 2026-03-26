`ifndef AXI_INTF_SV
`define AXI_INTF_SV

interface axi_intf (
	input logic clk,
 	input logic rstn
);
    // Write Address
    logic [`ADDR_WIDTH-1:0] awaddr;
    logic [`LEN_WIDTH-1:0] awlen;
    logic [2:0] awsize;
    logic [1:0] awburst;
    logic awvalid, awready;

    // write data
    logic [`DATA_WIDTH-1:0] wdata;
    logic [`STRB_WIDTH-1:0] wstrb;
    logic wlast, wvalid, wready;

    // write response
    logic [1:0] bresp;
    logic bvalid, bready;

    // read address
    logic [`ADDR_WIDTH-1:0] araddr;
    logic [`LEN_WIDTH-1:0] arlen;
    logic [2:0] arsize;
    logic [1:0] arburst;
    logic arvalid, arready;

    logic sva_en = 1'b1;
    // read data
    logic [`DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;
    logic rlast, rvalid, rready;

    clocking drv_cb @(posedge clk);
			default input #`SETUP_TIME output #`HOLD_TIME;
        output awaddr, awlen, awsize, awburst,awvalid, wvalid, wdata, wstrb, wlast, 
                bready, araddr, arlen, arsize, arburst, arvalid, rready;
        input  awready, wready, bresp, bvalid, arready, rdata, rresp, rlast, rvalid;
    endclocking

    clocking mon_cb @(posedge clk);
			default input #`SETUP_TIME output #`HOLD_TIME;
        input awaddr, awlen, awsize, awburst,awvalid, wdata, wstrb, wlast, wvalid, 
                bready, araddr, arlen, arsize, arburst, arvalid, rready;
        input awready, wready, bresp, bvalid, arready, rdata, rresp, rlast, rvalid;
    endclocking

    modport drv_mp(clocking drv_cb, input clk, rstn);
    modport mon_mp(clocking mon_cb, input clk, rstn);

		//-------------AW-----------------
    property aw_payload_stable;
        @(posedge clk) disable iff(!rstn || !sva_en)
			 	awvalid && !awready |=> (  
              $stable(awaddr)
            &&$stable(awlen)
            &&$stable(awsize) 
            &&$stable(awburst));
    endproperty

		property awvalid_hold;
			@(posedge clk) disable iff(!rstn || !sva_en)
			awvalid && !awready |=> awvalid;
		endproperty

		property awburst_legal;
			@(posedge clk) disable iff(!rstn || !sva_en)
			awvalid |-> awburst inside {2'b00, 2'b01, 2'b10};
		endproperty

		property aw_no_x;
			@(posedge clk) disable iff(!rstn || !sva_en)
			awvalid |-> (!$isunknown(awaddr)
		          	&& !$isunknown(awburst)
							 	&& !$isunknown(awlen)
							 	&& !$isunknown(awsize));
		endproperty

		property aw_wrap_rules;
			@(posedge clk) disable iff(!rstn || !sva_en)
			(awvalid && awburst == 2'b10) |->
				(awlen inside {4'h1, 4'h3, 4'h7, 4'hf}) &&
				((awaddr % (1 << awsize)) == 0);
		endproperty

		//------------W------------
    property w_payload_stable;
        @(posedge clk) disable iff(!rstn || !sva_en)
			 	wvalid && !wready |=> (
						   $stable(wdata)
            && $stable(wstrb)
            && $stable(wlast));
    endproperty

		property wvalid_hold;
			@(posedge clk) disable iff(!rstn || !sva_en)
			wvalid && !wready |=> wvalid;
		endproperty

		property w_no_x;
			@(posedge clk) disable iff(!rstn || !sva_en)
			wvalid |-> (
			     	 !$isunknown(wdata) 
				  && !$isunknown(wstrb)
				 	&& !$isunknown(wlast));
		endproperty

		//--------------B-------------
    property b_payload_stable;
        @(posedge clk) disable iff(!rstn || !sva_en)
			 	bvalid && !bready |=> (
            $stable(bresp));
    endproperty

		property bvalid_hold;
			@(posedge clk) disable iff(!rstn || !sva_en)
			bvalid && !bready |=> bvalid;
		endproperty

		property b_no_x;
			@(posedge clk) disable iff(!rstn || !sva_en)
			bvalid |-> (!$isunknown(bresp));
		endproperty

		//--------------AR---------------
    property ar_payload_stable;
        @(posedge clk) disable iff(!rstn || !sva_en)
				arvalid && !arready |=> (   
              $stable(araddr)
            &&$stable(arlen)
            &&$stable(arsize) 
            &&$stable(arburst));
    endproperty

		property arvalid_hold;
			@(posedge clk) disable iff(!rstn || !sva_en)
			arvalid &&! arready |=> arvalid;
		endproperty

		property arburst_legal;
			@(posedge clk) disable iff(!rstn || !sva_en)
			arvalid |-> arburst inside {2'b00, 2'b01, 2'b10};
		endproperty

		property ar_wrap_rules;
			@(posedge clk) disable iff(!rstn || !sva_en)
			(arvalid && arburst == 2'b10) |->
				(arlen inside {4'h1, 4'h3, 4'h7, 4'hf}) &&
				((araddr % (1 << arsize)) == 0);
		endproperty

		property ar_no_x;
			@(posedge clk) disable iff(!rstn || !sva_en)
			arvalid |-> (
				     !$isunknown(araddr)
					&& !$isunknown(arburst)
				 	&& !$isunknown(arlen)
				 	&& !$isunknown(arsize));
		endproperty

		//--------------R--------------
    property r_payload_stable;
        @(posedge clk) disable iff(!rstn || !sva_en) 
				rvalid && !rready |=> (   
                $stable(rdata)
             && $stable(rresp)
             && $stable(rlast));
    endproperty

		property rvalid_hold;
			@(posedge clk) disable iff(!rstn || !sva_en)
			rvalid && !rready |=> rvalid;
		endproperty

		property r_no_x;
			@(posedge clk) disable iff(!rstn || !sva_en)
			rvalid |-> (!$isunknown(rresp));
		endproperty

		property reset_rule;
			@(posedge clk)
			!rstn |-> (!awvalid && !wvalid && !bvalid && !arvalid && !rvalid);
		endproperty

		//reset
		assert property (reset_rule)        else $error("AXI_SVA: valid signal is HIGH during reset");
		//AW
    assert property (aw_payload_stable) else $error("AXI_SVA: AW payload changed while waiting for ready");
    assert property (awvalid_hold)      else $error("AXI_SVA: AWVALID dropped before AWREADY");
    assert property (awburst_legal)     else $error("AXI_SVA: Illegal AWBURST value");
    assert property (aw_wrap_rules)     else $error("AXI_SVA: AW WRAP burst rule voilated");
    assert property (aw_no_x)           else $error("AXI_SVA: CMD signal contains X/Z");
		//W
    assert property (w_payload_stable)  else $error("AXI_SVA: W payload changed while waiting for ready");
    assert property (wvalid_hold)       else $error("AXI_SVA: WVALID dropped before WREADY");
    assert property (w_no_x)            else $error("AXI_SVA: DATA signal contains X/Z");
		//B
    assert property (b_payload_stable)  else $error("AXI_SVA: B payload changed while waiting for ready");
    assert property (bvalid_hold)       else $error("AXI_SVA: BVALID dropped before BREADY");
    assert property (b_no_x)            else $error("AXI_SVA: RESP signal contains X/Z");
		//AR
    assert property (ar_payload_stable) else $error("AXI_SVA: AR payload changed while waiting for ready");
    assert property (arvalid_hold)      else $error("AXI_SVA: ARVALID dropped befor ARREADY");
    assert property (arburst_legal)     else $error("AXI_SVA: Illegal ARBURST value");
    assert property (ar_wrap_rules)     else $error("AXI_SVA: AR WRAP burst rule voilated");
    assert property (ar_no_x)           else $error("AXI_SVA: CMD signal contains X/Z");
		//R
    assert property (r_payload_stable)  else $error("AXI_SVA: R payload changed while waiting for ready");
    assert property (rvalid_hold)       else $error("AXI_SVA: RVALID dropped before RREADY");
    assert property (r_no_x)            else $error("AXI_SVA: DATA signal contains X/Z");

endinterface 

`endif
