`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 12/06/2024 01:50:10 PM
// Design Name: 
// Module Name: AXI_to_AHB_Bridge_tb
// Project Name: AXI_to_AHB_Bridge
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module AXI_to_AHB_Bridge_tb;
localparam ADDRESS_WIDTH = 32;
localparam DATA_WIDTH = 32;
localparam STROBE_WIDTH = 4;
bit ACLK;
bit ARESET_n;
                 // Write Addresss Channel Signals
bit [ADDRESS_WIDTH-1 : 0] AWADDR;
bit [1:0] AWBURST;
bit [2:0] AWSIZE;
bit [3:0] AWLEN;
bit AWVALID;
bit AWREADY;
                 
                 // Write Data Channel Signals
bit [DATA_WIDTH-1 : 0] WDATA;
bit WVALID;
bit [STROBE_WIDTH-1:0] WSTRB; // width is hard coded for datawidth = 32 and will be changed accordingly
bit WLAST;
logic WREADY;
                 
                 // Write Response channel Signals
bit BREADY;
logic [1:0] BRESP;
logic BVALID;
                 
                 // Read Address Channel Signals
bit [ADDRESS_WIDTH-1 : 0] ARADDR;
bit [1:0] ARBURST;
bit [2:0] ARSIZE;
bit [3:0] ARLEN;
bit ARVALID;
logic ARREADY;
                 
                 // Read Data Channel Signals
logic [DATA_WIDTH-1 : 0] RDATA;
logic RVALID;
logic RLAST;
logic [1:0] RRESP;
logic [STROBE_WIDTH-1:0] HWSTRB;
bit RREADY;
                 
                 // AHB Signals from AHB Slave
bit HREADY;
bit HRESP;
bit [DATA_WIDTH-1 : 0] HRDATA;
logic [DATA_WIDTH-1 : 0] HWDATA;
logic [ADDRESS_WIDTH-1 : 0] HADDR;
logic HWRITE;
logic [2:0] HSIZE;
logic [2:0] HBURST;
logic [1:0] HTRANS;

    AXI_to_AHB_Bridge #(32, 32, 4) DUT (.*);
    
    always
    begin
        #10 ACLK = ~ACLK;
    end
    
    initial
    begin
        #2000000
        $display ("Simulation Time Out");
        $finish;
    end
    
    initial
    begin
        ARESET_n = 1;
        @(posedge ACLK);
            ARESET_n = 0;
        @(posedge ACLK);
            ARESET_n = 1;
            
            
       // Writing single beat with OKAY response from AHB
        @(negedge ACLK);
            AWVALID <= 1;
            AWADDR <= 18;
            AWLEN = 0;
            AWSIZE = 2;
            AWBURST = 0;
            HREADY = 1;
            WLAST = 0;
        wait (AWREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
        @(negedge ACLK);
            AWVALID = 0;
            WVALID = 1;
            WDATA = 20;
            WLAST = 1;
            WSTRB = 15;
            HREADY = 1; // AHB is ready 
        wait (HTRANS == 2); // wait here till AHB recieve response
            HRESP = 0;  
        wait (BVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           BREADY = 1;
           
           
           #500
          
           
        // Writing single beat with ERROR response from AHB
        @(negedge ACLK);
            AWVALID <= 1;
            AWADDR <= 30;
            AWLEN = 0;
            AWSIZE = 2;
            AWBURST = 0;
            HREADY = 1; // AHB is ready 
            WLAST = 0;
        wait (AWREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
        @(negedge ACLK);
            AWVALID = 0;
            WVALID = 1;
            WDATA = 500;
            WLAST = 1;
            WSTRB = 15;
        wait (HTRANS == 2); // wait here till AHB recieve response
            @(posedge ACLK);
             HRESP = 1; // Eroor  
        wait (BVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           BREADY = 1;
           
           
           #500
           
           
           
           // Writing single beat with OKAY response from AHB (AHB busy
        @(negedge ACLK);
            AWVALID <= 1;
            AWADDR <= 200;
            AWLEN = 0;
            AWSIZE = 2;
            AWBURST = 0;
            HREADY = 1; // AHB is ready 
            WLAST = 0;
        wait (AWREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
            AWVALID = 0;
            WVALID = 1;
            WDATA = 705;
            WLAST = 1;
            WSTRB = 15;
        wait (HTRANS == 2); // wait here till AHB recieve response
            @(negedge ACLK);
             HREADY = 0; // AHB is BUSY for data
             HRESP = 0; // OKAY
        #100
            @(negedge ACLK)
            HREADY = 1; // AHB is now available
        wait (BVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           BREADY = 1;
           
           
           #500
           
           
           // Reading single beat with OKAY response from AHB
        @(negedge ACLK);
            ARVALID <= 1;
            ARADDR <= 31;
            ARLEN = 0;
            ARSIZE = 2;
            ARBURST = 0;
            HREADY = 1; // INITIALLY SALVE IS READY
        wait (ARREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
        @(negedge ACLK);
            ARVALID = 0;
        wait (HTRANS == 2); // wait here till AHB recieve response
            @(posedge ACLK);
             HRESP = 0;
             HRDATA = 150;  
        wait (RVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           RREADY = 1;
           $display("RLAST is %d", RLAST);
           $display("READ DATA: %d", RDATA);
           
           
           #500
           
             // Reading single beat with ERROR response from AHB
        @(negedge ACLK);
            ARVALID <= 1;
            ARADDR <= 31;
            ARLEN = 0;
            ARSIZE = 2;
            ARBURST = 0;
            HREADY = 1; // INITIALLY SALVE IS READY
        wait (ARREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
        @(negedge ACLK);
            ARVALID = 0;
        wait (HTRANS == 2); // wait here till AHB recieve response
            @(posedge ACLK);
             HRESP = 1;
             HRDATA = 250;  
        wait (RVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           RREADY = 1;
           $display("RLAST is %d", RLAST);
           $display("READ DATA: %d", RDATA);
           
           
           
           
           #500
           
           
           // Reading single beat with ERROR response from AHB (Slave Busy)
        @(negedge ACLK);
            ARVALID <= 1;
            ARADDR <= 31;
            ARLEN = 0;
            ARSIZE = 2;
            ARBURST = 0;
            HREADY = 1; // INITIALLY SALVE IS READY
            HRDATA = 0;
            HRESP = 0;
        wait (ARREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
        @(negedge ACLK);
            ARVALID = 0;
        wait (HTRANS == 2); // wait here till AHB recieve response
            HREADY = 0;
            @(posedge ACLK); // wait for one more cycle
            @(posedge ACLK); // wait for one more cycle
            @(posedge ACLK); 
             HREADY = 1;
             HRESP = 1;
             HRDATA = 250;  
        wait (RVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           RREADY = 1;
           $display("RLAST is %d", RLAST);
           $display("READ DATA: %d", RDATA);
           
           
           
           #500
           
           
           
           // Writing BURST of length 16 (wrapping) with no error and delay
        @(negedge ACLK);
            ARVALID = 0;
            AWVALID = 1;
            AWADDR = 48;
            AWLEN = 15;
            AWSIZE = 2;
            AWBURST = 2;
            HREADY = 1; // Slave is ready
            WLAST = 0;
            WVALID = 0;
            BREADY = 0;
        wait (AWREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
        @(posedge ACLK);
            AWVALID = 0;
            WVALID = 1;
            WDATA = 10;
            WSTRB = 1;
            HRESP = 0;
        wait (WREADY); // wait here till HS
        
        //@(posedge ACLK); // one posedge to latch HS
        for (int i=2; i<17; i++)
        begin
            @(posedge ACLK);
            WDATA = i*10;
            WSTRB = i;
            if (i == 16)
                WLAST = 1;
        end
        wait (BVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           BREADY = 1;
           
           
           #800
           
           
           
         // Reading Burst of length 16 (incrementing)
         @(negedge ACLK);
            AWVALID = 0;
            ARVALID = 1;
            ARADDR = 112;
            ARSIZE = 2;
            ARBURST = 1; // incrementing
            ARLEN = 15;
            HREADY = 1; //slave busy
            RREADY = 0;
         wait (ARREADY); // wait here till HS
         @(posedge ACLK); // one posedge to latch HS
         wait (HTRANS == 2) // wait for HTRNS = 2 (NONSEQ)
        // @(posedge ACLK);
            for (int i = 1; i<17; i++)
            begin
                @(posedge ACLK);
                HRESP = 0;
                HRDATA = i*4;
                if (RVALID && !RREADY)
                begin
                    #2
                    RREADY = 1;
                    ARVALID = 0;
                end
            end  
           
           
          #800 
          
          
          
          
          // Reading Burst of length 16 (incrementing) changing HREADY  
         @(negedge ACLK);
            AWVALID = 0;
            ARVALID = 1;
            ARADDR = 200;
            ARSIZE = 2;
            ARBURST = 1; // incrementing
            ARLEN = 15;
            HREADY = 1; //slave busy
            RREADY = 0;
         wait (ARREADY); // wait here till HS
         @(posedge ACLK); // one posedge to latch HS
         wait (HTRANS == 2) // wait for HTRNS = 2 (NONSEQ)
        // @(posedge ACLK);
            for (int i = 1; i<19; i++)
            begin
                @(posedge ACLK);
                HRESP = 0;
                HRDATA = i*30;
                if (RVALID && !RREADY)
                begin
                    
                    RREADY = 1;
                    ARVALID = 0;
                end
                if (i == 6)
                    HREADY = 0;
                if (i == 8)
                    HREADY = 1;
            end 
            
            
            #800
           
           
        // Writing BURST of length 16 (incrementing with + 4)
        @(negedge ACLK);
            AWVALID <= 1;
            AWADDR <= 18;
            AWLEN = 15;
            AWSIZE = 2;
            AWBURST = 1; // incrementing
            HREADY = 1;
            WLAST = 0;
        wait (AWREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
        @(negedge ACLK);
            AWVALID = 0;
            WVALID = 1;
            WDATA = 1;
            WSTRB = 15;
        wait (WREADY); // wait here till HS
        @(posedge ACLK); // one posedge to latch HS
        for (int i=2; i<16; i++)
        begin
            @(negedge ACLK);
            WDATA = i;
            WSTRB = 15; 
        end
            @(negedge ACLK);
            WDATA = 16;
            WSTRB = 15;
            WLAST = 1;
         @(posedge ACLK);   
         @(negedge ACLK);
            HRESP = 0;
            WDATA = 0;
            WSTRB = 0;
            WLAST = 0; 
        wait (BVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           BREADY = 1;
           HRESP = 0;
           
           
           
           
           
         #500
         
         
         // Reading Burst of length 16 (wrapping)
         @(negedge ACLK);
            AWVALID = 1;
            ARVALID = 1;
            ARADDR = 112;
            ARSIZE = 2;
            ARBURST = 2; // wrapping
            ARLEN = 15;
         wait (ARREADY); // wait here till HS
            @(posedge ACLK); // one posedge to latch HS
         wait (HTRANS == 2) // wait for HTRNS = 2 (NONSEQ)
        // @(posedge ACLK);
            for (int i = 1; i<17; i++)
            begin
                @(negedge ACLK);
                HRESP = 0;
                HRDATA = i*4;
                if (RVALID)
                begin
                    RREADY = 1;
                    ARVALID = 0;
                end
                if (i == 10)
                begin
                    HREADY = 0;
                    RREADY = 0;
                    
                    #40;
                    continue;
                    HREADY = 1;
                end
                RREADY = 1;
            end
            
            
            #500
        
        // Writing BURST of length 8 (wrapping)
        @(negedge ACLK);
            AWVALID <= 1;
            AWADDR <= 100;
            AWLEN = 7;
            AWSIZE = 2;
            AWBURST = 2;
            HREADY = 1;
            WLAST = 0;
        wait (AWREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
        @(negedge ACLK);
            AWVALID = 0;
            WVALID = 1;
            WDATA = 10;
            WSTRB = 1;
        wait (WREADY); // wait here till HS
        @(posedge ACLK); // one posedge to latch HS
        for (int i=2; i<8; i++)
        begin
            @(negedge ACLK);
            WDATA = i*10;
            WSTRB = i;
            if (i==3)
            begin
                HRESP = 1;
            end
            else
            begin
                HRESP = 0;
            end
        end
            @(negedge ACLK);
            WDATA = 30;
            WSTRB = 15;
            WLAST = 1;
         @(posedge ACLK);   
         @(negedge ACLK);
            HRESP = 1;
            WDATA = 0;
            WSTRB = 0;
            WLAST  = 0; 
        wait (BVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           BREADY = 1;
           HRESP = 0;
        
        
        
        
        #500
        
        // Reading Burst of length 8 (incremental)
         @(negedge ACLK);
            ARVALID <= 1;
            ARADDR <= 10;
            ARSIZE = 2;
            ARBURST = 1; // incrementing
            ARLEN = 7;
            RREADY = 1;
         wait (ARREADY); // wait here till HS
         @(posedge ACLK); // one posedge to latch HS
         wait (HTRANS == 2) // wait for HTRNS = 2 (NONSEQ)
        // @(posedge ACLK);
            ARVALID = 0;
            AWVALID = 0;
            for (int i = 1; i<9; i++)
            begin
                @(posedge ACLK);
                HRESP <= 0;
                HRDATA <= i*20;
                if (RVALID)
                begin
                    RREADY <= 1;
                    ARVALID <= 0;
                end
                if (i == 4)
                begin
                    HRESP <= 1;
                end
            end
         //ARVALID  = 0;
         
        
        #400;
        
        
        
        /////////// ARbitor functionality Testing by starting transaction at same time////////
         // Writing single beat with OKAY response from AHB
        repeat(10)
        begin
        @(posedge ACLK);
            AWVALID <= 1;
            AWADDR <= 18;
            AWLEN <= 0;
            AWSIZE <= 2;
            AWBURST <= 0;
            HREADY <= 1;
            WLAST <= 0;
            ARVALID <= 1;
            ARADDR <= 31;
            ARLEN <= 0;
            ARSIZE <= 2;
            ARBURST <= 0;
        wait (AWREADY | ARREADY); // wait here till AWREADY
       // @(posedge ACLK); // one posedge to latch HS
       if (AWREADY)
           begin
            @(posedge ACLK);
                AWVALID = 0;
                ARVALID = 0;
                WVALID = 1;
                WDATA = 20;
                WLAST = 1;
                WSTRB = 15;
                HREADY = 1; // AHB is ready 
            wait (HTRANS == 2); // wait here till AHB recieve response
                HRESP = 0;  
            wait (BVALID); // wait here till BVALID = 1
             @(posedge ACLK); // one posedge to latch HS
               BREADY = 1;
            end
        else if (ARREADY)
        begin
            @(posedge ACLK);
            ARVALID = 0;
            AWVALID = 0;
            wait (HTRANS == 2); // wait here till AHB recieve response
            @(posedge ACLK);
             HRESP = 0;
             HRDATA = 150;  
            wait (RVALID); // wait here till BVALID = 1
                @(posedge ACLK); // one posedge to latch HS
                RREADY = 1;
        end
           #500;
        end
        
        
        
        
         // Writing BURST of length 8 (Fixed)
        @(negedge ACLK);
            ARVALID <= 0;
            AWVALID <= 1;
            AWADDR <= 2000;
            AWLEN = 10;
            AWSIZE = 2;
            AWBURST = 0;
            HREADY = 1;
            WLAST = 0;
        wait (AWREADY); // wait here till AWREADY
        @(posedge ACLK); // one posedge to latch HS
        @(posedge ACLK);
            AWVALID = 0;
            WVALID = 1;
            WDATA = 10;
            WSTRB = 1;
            HRESP = 0;
        wait (WREADY); // wait here till HS
       // @(posedge ACLK); // one posedge to latch HS
        for (int i=2; i<11; i++)
        begin
            @(posedge ACLK);
            WDATA = i*10;
            WSTRB = i;
        end
            @(posedge ACLK);
            WDATA = 30;
            WSTRB = 15;
            WLAST = 1;
        wait (BVALID); // wait here till BVALID = 1
         @(posedge ACLK); // one posedge to latch HS
           BREADY = 1;
           
           
           #300;
         
        $finish;
    end
endmodule
