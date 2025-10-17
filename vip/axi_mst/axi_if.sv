`ifndef AXI_IF__SV
`define AXI_IF__SV

interface axi_intf #(parameter DATA_WIDTH = 32, ADDR_WIDTH = 16)(input bit clk, bit rstn);
    // Write Address
    //logic [8:0] AWID;
    logic [ADDR_WIDTH-1:0] awaddr;
    logic [3:0] awlen;
    logic [2:0] awsize;
    logic [1:0] awburst;
    logic awvalid, awready;

    // write data
    logic [DATA_WIDTH-1:0] wdata;
    logic [(DATA_WIDTH/8)-1:0] wstrb;
    logic wlast, wvalid, wready;

    // write response
    logic [1:0] bresp;
    logic bvalid, bready;

    // read address
    logic [ADDR_WIDTH-1:0] araddr;
    logic [3:0] arlen;
    logic [2:0] arsize;
    logic [1:0] arburst;
    logic arvalid, arready;

    // read data
    logic [DATA_WIDTH-1:0] rdata;
    logic [1:0] rresp;
    logic rlast, rvalid, rready;

    /* Clocking Blocks: 3 CBs are defined as follows
            1. m_drv_cb - Clocking block for master driver
            2. s_drv_cb - Clocking block for slave driver
            3. mon_cb   - Clocking block for monitors of both master and slave */
    clocking m_drv_cb @(posedge clk);
        output awaddr, awlen, awsize, awburst,awvalid, wdata, wstrb, wlast, 
                bready, araddr, arlen, arsize, arburst, arvalid, rready;
        input  awready, wready, bresp, bvalid, arready, rdata, rresp, rlast, rvalid;
    endclocking

    clocking mon_cb @(posedge clk);
        input awaddr, awlen, awsize, awburst,awvalid, wdata, wstrb, wlast, wvalid, 
                bready, araddr, arlen, arsize, arburst, arvalid, rready;
        input awready, wready, bresp, bvalid, arready, rdata, rresp, rlast, rvalid;
    endclocking

    clocking s_drv_cb @(posedge clk);
        input  awaddr, awlen, awsize, awburst,awvalid, wdata, wstrb, wlast, wvalid, 
                bready, araddr, arlen, arsize, arburst, arvalid, rready;
        output awready, wready, bresp, bvalid, arready, rdata, rresp, rlast, rvalid;
    endclocking

    modport mdrv(clocking m_drv_cb, input rstn);
    modport mmon(clocking mon_cb,   input rstn);
    modport sdrv(clocking s_drv_cb, input rstn);
    modport smon(clocking mon_cb,   input rstn);

    // *************************************************************************************************
    //                                      Assertions
    // *************************************************************************************************
    // Property to check whether all write address channel remains stable after AWVALID is asserted
    property aw_valid;
        @(posedge clk) $rose(awvalid) |-> (  
                                            $stable(awaddr)
                                            &&$stable(awlen)
                                            &&$stable(awsize) 
                                            &&$stable(awburst)) throughout awready[->1];
    endproperty

    // property to check whether all write address channel remains stable after awvalid is asserted
    property w_valid;
        @(posedge clk) $rose(wvalid) |-> (
																						$stable(wdata)
                                            && $stable(wstrb)
                                            && $stable(wlast)) throughout wready[->1];
    endproperty

    // property to check whether all write address channel remains stable after awvalid is asserted
    property b_valid;
        @(posedge clk) $rose(bvalid) |-> (
                                            $stable(bresp)) throughout bready[->1];
    endproperty

    // property to check whether all write address channel remains stable after awvalid is asserted
    property ar_valid;
        @(posedge clk) $rose(arvalid) |-> (   
                                            $stable(araddr)
                                            &&$stable(arlen)
                                            &&$stable(arsize) 
                                            &&$stable(arburst)) throughout arready[->1];
    endproperty

    // property to check whether all write address channel remains stable after awvalid is asserted
    property r_valid;
        @(posedge clk) $rose(rvalid) |-> (   
                                            $stable(rdata)
                                            && $stable(rresp)
                                            && $stable(rlast)) throughout rready[->1];
    endproperty

    assert property (aw_valid);
    assert property (w_valid);
    assert property (b_valid);
    assert property (ar_valid);
    assert property (r_valid);

endinterface 

`endif
