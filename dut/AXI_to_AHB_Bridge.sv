`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NCDC
// Engineer: WADOOD ALAM
// 
// Create Date: 12/05/2024 07:12:29 PM
// Design Name: AXI_to AHB Control + Datapath
// Module Name: Simple_Transaction_Converter
// Project Name: AXI4 to AHB5 Bridge 
// Target Devices: xc7a100tifgg676-1L (Artix-7 FPGA)
// Tool Versions: Vivado 2019.1
// Description: The project acts as a bridge between AXI master and AHB slave. It supports single transfers (Read and Write)
//              It also supports Fixed, Incremental and Wrapping bursts (read and write both)
//              It convert response from AHB slave and provide AXI equivalent response to master.
//              It has write latency of 3 clock cycles and read latency of 5 cycles
//              Data_width address_width and strobe_width are parameterized and can be set to
//              Data_width = 8,16,32,64,128
//              Address_width = 8,16,32,64
//              strobe_width = data_width/8
//              An arbitor of round robintype has been integrated which gives priority to write upon reset
//              and then works in a round robin passion
//              beat size(bytes) can be provided as per the data_width i.e size <= data_width/8;
//              fixed and incrementing burts can be of any length between 1 and 16
//              wrapping burst length is restricted as per AXI4 as (2,4,8,16)
//              BRESP and RRESP can take only two values (0 for OKAY) and (2 for SLVERRER)
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module AXI_to_AHB_Bridge#(parameter ADDRESS_WIDTH = 32, DATA_WIDTH = 32, STOBE_WIDTH = 4)
                 (input ACLK,
                 input ARESET_n,
                 // Write Addresss Channel Signals
                 input [ADDRESS_WIDTH-1 : 0] AWADDR,
                 input [1:0] AWBURST, // Fixed, Incrementing, wrapping
                 input [2:0] AWSIZE, // maximum size can be 128 bytes per beat
                 input [3:0] AWLEN,  // maximum length can be 15+1 = 16 beats per burst
                 input AWVALID,
                 output logic AWREADY,
                 
                 // Write Data Channel Signals
                 input [DATA_WIDTH-1 : 0] WDATA,
                 input WVALID,
                 input [STOBE_WIDTH-1:0] WSTRB, // It is necessary when beat size < data_width/8
                 input WLAST,
                 output logic WREADY,
                 
                 // Write Response channel Signals
                 input BREADY,
                 output logic [1:0] BRESP,
                 output logic BVALID,
                 
                 // Read Address Channel Signals
                 input [ADDRESS_WIDTH-1 : 0] ARADDR,
                 input [1:0] ARBURST, // Fixed, Incrementing, wrapping
                 input [2:0] ARSIZE, // maximum size can be 128 bytes per beat
                 input [3:0] ARLEN, // maximum length can be 15+1 = 16 beats per burst
                 input ARVALID,
                 output logic ARREADY,
                 
                 // Read Data Channel Signals
                 output logic [DATA_WIDTH-1 : 0] RDATA,
                 output logic RVALID,
                 output logic RLAST,
                 output logic [1:0] RRESP,
                 input RREADY,
                 
                 // AHB Signals from AHB Slave
                 input HREADY, // indication of the readiness of AHB slave
                 input HRESP, // 0 mean okay and 1 mean SLVERROR
                 input [DATA_WIDTH-1 : 0] HRDATA,
                 output logic [DATA_WIDTH-1 : 0] HWDATA,
                 output logic [ADDRESS_WIDTH-1 : 0] HADDR,
                 output logic HWRITE, // 1 mean writing and 0 mean reading
                 output logic [2:0] HSIZE, // maximum size can be 128 bytes per beat
                 output logic [2:0] HBURST,// single transfer, incrementing undefined length,wrap4, wrap8, wrap16 can be enabled only
                 output logic [1:0] HTRANS, // 0 IDLE, 1 BUSY, 2 NONSEQ, 3 SEQ
                 output logic [STOBE_WIDTH-1:0] HWSTRB // required when beat size <= Data_width/8 (one strb signal for each byte)
                 );
    
            // internal control signals and Registers
            logic trigger_write; // signal that will trigger AHB FSM in write mode from AXI FSM
            logic trigger_read; // signal that will trigger AHB FSM in read mode from AXI FSM
            logic w_ack; // Signal that tells AXI FSM that AHB transaction has completed (from AHB to AXI)
            logic r_ack; // Signal that tells AXI FSM that i have started recieving data from AHB slave (from AHB to AXI)
            logic write_done; // Signal that tells AHB FSM that AXI writing is done from W channel (from AXI to AHB)
            logic read_done; // Signal that tells AHB FSM that AXI reading is done from read_fifo (from AXI to AHB)
            logic AHB_busy; // status of AHB transaction resource (0 free, 1 busy)
            logic burst_read_done; // signal from AHB FSM to AXI FSM after complete reading all data from AHB slave (from AHB to AXI)
            logic fifo_rst; // fifo_rst signal that will reset both read and write fifo when transaction completed
            logic arbitor_ack; // status of AXI FSM to arbitor so that arbitor can assume AWVALID and ARVALID (from AXI to arbitor)
            logic start_writing; // signal coming from arbitor to AXI FSM which tell AXI to start in writing mode and look for WVALID
            logic start_reading; // signal coming from arbitor to AXI FSM which tells AXI to start in reading mode and recieve data from AHB slave
            
            // write address channel registers stores control information and address for write transaction
            logic [ADDRESS_WIDTH-1 : 0] AWADDR_reg;
            logic [1:0] AWBURST_reg;
            logic [2:0] AWSIZE_reg;
            logic [3:0] AWLEN_reg;
            
            // write response channel register that stores response from AHB slave in write transactions
            logic [1:0] BRESP_reg;
            
            
            // read address channel registers stores control information and address for read transaction
            logic [ADDRESS_WIDTH-1 : 0] ARADDR_reg;
            logic [1:0] ARBURST_reg;
            logic [2:0] ARSIZE_reg;
            logic [3:0] ARLEN_reg;
            
            // read data channel registers that stores response from AHB slave in read transactions
            logic [1:0] RRESP_reg;
            
            // Wrapping bursts parameters which stores information(wrap_boundry and wrap_start_address afetr wrap around)
            logic [ADDRESS_WIDTH-1 : 0] wrap_start;
            logic [ADDRESS_WIDTH-1 : 0] wrap_boundry;
            
            // New Address registers for AHB bursts
            logic [ADDRESS_WIDTH-1 : 0] AHB_write_address;
            logic [ADDRESS_WIDTH-1 : 0] AHB_read_address;
            
            // AXI HS signals (for all 5 channels have separate handshakes)
            logic AW_HS;
            logic W_HS;
            logic B_HS;
            logic AR_HS;
            logic R_HS;
            
            // AXI channels HS logic 
            assign AW_HS = AWVALID & AWREADY;
            assign W_HS = WVALID & WREADY;
            assign B_HS = BVALID & BREADY;
            assign AR_HS = ARVALID & ARREADY;
            assign R_HS = RVALID & RREADY;
            
            
            // write data fifo control signals that will be monitored and controlled by both FSMs
            logic write_data_wr_en;
            logic write_data_rd_en;
            logic write_data_full;
            logic write_data_empty;
            
            // reading and writing logic of write data fifo
            // writing to write_data_fifo is controlled by AXI FSM and AXI manager
            assign write_data_wr_en = (AXI_PS == AXI_WRITE_DATA) & W_HS & (~write_data_full);
            // reading from write_data_fifo is controlled by AHB FSM and AHB subordinate
            assign write_data_rd_en = (AHB_PS == AHB_WRITE_DATA) & HREADY & (~write_data_empty);
            
            
            // read data fifo control signals that will be monitored and controlled by both FSMs
            logic read_data_wr_en;
            logic read_data_rd_en;
            logic read_data_full;
            logic read_data_empty;
            
            // reading and writing logic of read data fifo
            // writing to read_data_fifo is controlled by AHB FSM and AHB subordinate
            assign read_data_wr_en = ((AHB_PS == AHB_READ_DATA)  & HREADY & (~read_data_full) & (read_counter != 0)) | ((AHB_PS == AHB_READ_ACK) & (ARLEN_reg == 0) & (AXI_PS == AXI_TRIGGER_READ) ); // first logic is for burst and second is for single transfer
            // reading from read_data_fifo is controlled by AXI FSM and AXI manager
            assign read_data_rd_en = (((AXI_PS == AXI_READ_DATA) | (AXI_PS == AXI_REMAINING_READ_DATA)) & RREADY & (~read_data_empty)) | ((AXI_PS == AXI_READ_DATA) & (ARLEN_reg == 0) & (~read_data_empty)) | ((AXI_PS == AXI_READ_DATA) & (ARLEN_reg !=0) & (axi_read_counter == 0));
            
            // control signals logic for AXI FSM
            assign trigger_write = (AXI_PS == AXI_WRITE_DATA);
            assign trigger_read = (AXI_PS == AXI_TRIGGER_READ);
            assign AWREADY = (AXI_PS == AXI_WRITE_ADDRESS);
            assign WREADY = (AXI_PS == AXI_WRITE_DATA);
            assign BVALID = (AXI_PS == AXI_B_RESP);
            assign ARREADY = (AXI_PS == AXI_READ_ADDRESS);
            // for RLAST first expression logic asserts RLAST for bursts with OKAY response from AHB slave
            //           second expression logic asserts RLAST for bursts with ERROR response from AHB slave
            //           third expression asserts RLAST for single read transfer (OKAY and ERROR reponse both are catered)
            assign RLAST = ((AXI_PS == AXI_READ_DATA) & (AXI_NS == AXI_READ_DONE)) | ((AXI_PS == AXI_REMAINING_READ_DATA)& (AXI_NS == AXI_READ_DONE)) | ((AXI_PS == AXI_READ_DATA) & (ARLEN_reg == 0) & (read_data_empty) & RVALID);
            assign BRESP = (AXI_PS == AXI_B_RESP) ? BRESP_reg : 2'b00 ;
            assign fifo_rst = (AXI_PS == AXI_IDLE);
            // this signal indicated that both FSM (AXI and AHB) are in idle state and arbitor can initiate new transfer
            assign arbitor_ack = (AXI_PS == AXI_IDLE) & (~AHB_busy);
            
            // control signals logic for AHB FSM
            // for handshking between both FSMs
            assign read_done = (AXI_PS == AXI_READ_DONE); // Signal to AHB FSM that reading from fifo has performed successfully (from AXI to AHB)
            // for handshaking between both FSMs
            assign write_done = (AXI_PS == AXI_B_RESP); // Signal to AHB FSM that reponse are going to be written and indicated that writing has completed(from AXI to AHB)
            assign AHB_busy = (AHB_PS != AHB_IDLE); // indicated that AHB FSM is busy
            assign w_ack = (AHB_PS == AHB_WRITE_ACK); // Signal to AXI FSM that writing has completed to AHB slave such that reading from write_data fifo has completed for transaction and now AXI FSM can write response on B channel (from AHB to AXI)
            assign r_ack = (AHB_PS == AHB_READ_ACK) | ((AHB_PS == AHB_READ_DATA) & (~read_data_empty)); // Signal to AXI FSM that data has been recieved from AHB slave and AXI can start writing that data to AXI R channel (from AHB to AXI)
            assign burst_read_done = (AHB_PS == AHB_READ_ACK); // signal from AHB FSM that indicated that reading from AHB slave has been completed and AXI FSM can finish transaction once it read all data from dead_data fifo (from AHB to AXI)
                       
            // counters that keep track of the burst length 
            logic [4:0] read_counter; // used by AHB FSM to keep track of the beats readed from AHB slave
            logic [4:0] write_counter; // used by AHB FSM to keep track of the beats that has been written to AHB Slave from write_data fifo
            logic [4:0] rem_read_counts; // used by AXI FSM to keep track of remaining bytes when HRESP gives error in the middle of burst so that read burst on the AXI side can be completed with error response on remaining beats (only applicable for burts)
            logic [4:0] axi_read_counter; // used by axi FSM to keep track of reading data from read_data fifo that has been recieved from AHB slave
            
            // RVALID logic 
            logic RVALID_reg;
            assign RVALID = RVALID_reg;
            
       ///////////// FSM for AXI read and write///////////////////
            // States using enum (one hot encoding scheme)
            typedef enum logic [10:0] {
                                      AXI_IDLE = 11'b00000000001,
                                      AXI_WRITE_ADDRESS = 11'b00000000010,
                                      AXI_WRITE_DATA_WAIT = 11'b00000000100,
                                      AXI_WRITE_DATA = 11'b00000001000,
                                      AXI_WAIT_WRITE_ACK = 11'b00000010000,
                                      AXI_B_RESP = 11'b00000100000,
                                      AXI_READ_ADDRESS = 11'b00001000000,
                                      AXI_TRIGGER_READ = 11'b00010000000,
                                      AXI_READ_DATA = 11'b00100000000,
                                      AXI_REMAINING_READ_DATA = 11'b01000000000,
                                      AXI_READ_DONE = 11'b10000000000
                                      } AXI_FSM_STATES;
                    
            // State Registers
            AXI_FSM_STATES AXI_PS, AXI_NS;
            
            // State Transition (Sequential Logic)
            always_ff @(posedge ACLK or negedge ARESET_n) // Asynchronous active low reset
            begin
                if (!ARESET_n)
                    AXI_PS <= AXI_IDLE;
                else
                    AXI_PS <= AXI_NS;
            end
            
            // Next State Calculation (Combinational Block)
            always_comb
            begin
                case (AXI_PS)
                AXI_IDLE:
                    begin
                        if (start_writing && !AHB_busy)
                        begin
                            AXI_NS = AXI_WRITE_ADDRESS;
                        end
                        else if (start_reading && !AHB_busy)
                        begin
                             AXI_NS = AXI_READ_ADDRESS;
                        end
                        else
                        begin
                            AXI_NS = AXI_IDLE;
                        end
                     end
                AXI_WRITE_ADDRESS:
                    begin
                        if (AW_HS)
                        begin
                            AXI_NS = AXI_WRITE_DATA_WAIT;
                        end
                        else
                        begin
                            AXI_NS = AXI_WRITE_ADDRESS;
                        end
                    end
                AXI_WRITE_DATA_WAIT:
                    begin
                        if (WVALID)
                        begin
                            AXI_NS = AXI_WRITE_DATA;
                        end
                        else
                        begin
                            AXI_NS = AXI_WRITE_DATA_WAIT;
                        end
                    end
                AXI_WRITE_DATA:
                    begin
                        if (W_HS && WLAST)
                        begin
                            AXI_NS = AXI_WAIT_WRITE_ACK;
                        end
                        else
                        begin
                            AXI_NS = AXI_WRITE_DATA;
                        end
                    end
                AXI_WAIT_WRITE_ACK:
                    begin
                        if (w_ack)
                        begin
                            AXI_NS = AXI_B_RESP;
                        end
                        else
                        begin
                            AXI_NS = AXI_WAIT_WRITE_ACK;
                        end
                    end
                AXI_B_RESP:
                    begin
                        if (B_HS)
                        begin
                            AXI_NS = AXI_IDLE;
                        end
                        else
                        begin
                            AXI_NS = AXI_B_RESP;
                        end
                    end
                
                
                AXI_READ_ADDRESS:
                    begin
                        if (AR_HS)
                        begin
                            AXI_NS = AXI_TRIGGER_READ;
                        end
                        else
                        begin
                            AXI_NS = AXI_READ_ADDRESS;
                        end
                    end
                AXI_TRIGGER_READ:
                    begin
                        if (r_ack)
                        begin
                            AXI_NS = AXI_READ_DATA;
                        end
                        else
                        begin
                            AXI_NS = AXI_TRIGGER_READ;
                        end
                    end
                AXI_READ_DATA:
                    begin
                        // 
                        if ((ARLEN_reg != 0) && R_HS && (RRESP_reg == 2'b10) && burst_read_done) // incase if error response has recieved during read transfer bursts
                        begin
                            AXI_NS = AXI_REMAINING_READ_DATA;
                        end
                        else if (R_HS && axi_read_counter == ARLEN_reg-1) // in case burst transfer with okay responses
                        begin
                            AXI_NS = AXI_READ_DONE;
                        end
                        else if (R_HS && (ARLEN_reg == 0)) // incase of single transfer
                        begin
                            AXI_NS = AXI_READ_DONE;
                        end
                        else
                        begin
                            AXI_NS = AXI_READ_DATA;
                        end
                    end
                AXI_REMAINING_READ_DATA:
                    begin
                        if (rem_read_counts == ARLEN_reg + 3) // the +3 is used as AXI FSM starts after 2 (reads has done to read_Data fifo) +1
                        begin
                            AXI_NS = AXI_READ_DONE;
                        end
                        else
                        begin
                            AXI_NS = AXI_REMAINING_READ_DATA;
                        end
                    end
                AXI_READ_DONE:
                    begin
                            AXI_NS = AXI_IDLE;
                    end
                default:
                    begin
                        AXI_NS = AXI_IDLE;
                    end
                endcase
            end
            
            // Registers and counters with enable control from AXI FSM
            always_ff @(posedge ACLK or negedge ARESET_n)
            begin
                if (!ARESET_n)
                begin
                    // Registers that hold information for whole transaction
                    AWADDR_reg <= 0;
                    AWBURST_reg <= 0;
                    AWSIZE_reg <= 0;
                    AWLEN_reg <= 0;
                    ARADDR_reg <= 0;
                    ARBURST_reg <= 0;
                    ARSIZE_reg <= 0;
                    ARLEN_reg <= 0;
                    // output response of R channel
                    RRESP <= 0;
                    // counters
                    rem_read_counts <= 0;
                    axi_read_counter <= 0;
                    // R channel Valid signal will use it
                    RVALID_reg <= 0;
                end
                else
                begin
                if (AXI_PS == AXI_IDLE)
                    begin
                        AWADDR_reg <= 0;
                        AWBURST_reg <= 0;
                        AWSIZE_reg <= 0;
                        AWLEN_reg <= 0;
                        ARADDR_reg <= 0;
                        ARBURST_reg <= 0;
                        ARSIZE_reg <= 0;
                        ARLEN_reg <= 0;
                        RRESP <= 0;
                        rem_read_counts <= 0;
                        axi_read_counter <= 0;
                        RVALID_reg <= 0;
                     end
                if (AXI_PS == AXI_WRITE_ADDRESS)
                    begin
                        AWADDR_reg <= AWADDR;
                        AWBURST_reg <= AWBURST;
                        AWSIZE_reg <= AWSIZE;
                        AWLEN_reg <= AWLEN;
                    end
                if (AXI_PS == AXI_READ_ADDRESS)
                    begin
                        ARADDR_reg <= ARADDR;
                        ARBURST_reg <= ARBURST;
                        ARSIZE_reg <= ARSIZE;
                        ARLEN_reg <= ARLEN;
                    end
                if (AXI_PS == AXI_READ_DATA)
                    begin
                        RRESP <= RRESP_reg;
                        rem_read_counts <= read_counter;
                        // (ARLEN_reg == 0) is used for single transfer
                        // ((ARLEN_reg !=0) && (~read_data_empty)) is used for burst
                        // (axi_read_counter == 0) is used for first beat of the burst
                        if ((ARLEN_reg == 0) || ((ARLEN_reg !=0) && (~read_data_empty)) || (axi_read_counter == 0))
                        begin
                            RVALID_reg <= 1;
                        end
                        else
                        begin
                            RVALID_reg <= 0;
                        end
                        
                        if (R_HS)
                        begin
                            axi_read_counter <= axi_read_counter +1;
                        end
                        else
                        begin
                            axi_read_counter <= axi_read_counter;
                        end
                    end
                if (AXI_PS == AXI_REMAINING_READ_DATA)
                    begin
                        RRESP <= RRESP_reg;
                        RVALID_reg <= 1;
                        if (R_HS)
                        begin
                            rem_read_counts <= rem_read_counts + 1;
                        end
                        else
                        begin
                            rem_read_counts <= rem_read_counts;
                        end
                    end
                if (AXI_PS == AXI_READ_DONE)
                    begin
                        RRESP <= 0;
                        RVALID_reg <= 0;
                    end
                end
            end
            
                     
            
            ////////////////////// FSM for AHB read and write /////////////////////////////////
            // States (one hot encdoing states)
            typedef enum logic [6:0] {
                                      AHB_IDLE = 7'b00000001,
                                      AHB_WRITE_ADDRESS = 7'b0000010,
                                      AHB_WRITE_DATA = 7'b0000100,
                                      AHB_WRITE_ACK = 7'b0001000,
                                      AHB_READ_ADDRESS = 7'b0010000,
                                      AHB_READ_DATA = 7'b0100000,
                                      AHB_READ_ACK = 7'b1000000} AHB_FSM_STATES;
                    
            // State Registers
            AHB_FSM_STATES AHB_PS, AHB_NS;
            
            // State Transition (Sequential Logic)
            always_ff @(posedge ACLK or negedge ARESET_n) // Asynchronous active low reset
            begin
                if (!ARESET_n)
                    AHB_PS <= AHB_IDLE;
                else
                    AHB_PS <= AHB_NS;
            end
            
            // Next State Calculation and Output (Combinational Block)
            always_comb
            begin
                case (AHB_PS)
                AHB_IDLE:
                    begin
                        // state transition logic
                        if (trigger_write && HREADY)
                        begin
                            AHB_NS = AHB_WRITE_ADDRESS;
                        end
                        else if (trigger_read && HREADY)
                        begin
                            AHB_NS = AHB_READ_ADDRESS;
                        end
                        else
                        begin
                            AHB_NS = AHB_IDLE;
                        end
                    end
                AHB_WRITE_ADDRESS:
                    begin
                        // state transition logic
                        if (HREADY)
                        begin
                           AHB_NS = AHB_WRITE_DATA; 
                        end
                        else
                        begin
                            AHB_NS = AHB_WRITE_ADDRESS;
                        end
                    end
                AHB_WRITE_DATA:
                    begin
                        // state transition logic
                        if (HREADY && (write_counter == AWLEN_reg)) // write_counter is the number of data packets send by AHB
                        begin
                           AHB_NS = AHB_WRITE_ACK; 
                        end
                        else if (HRESP)
                        begin
                            AHB_NS = AHB_WRITE_ACK;
                        end
                        else
                        begin
                            AHB_NS = AHB_WRITE_DATA;
                        end
                    end
                AHB_WRITE_ACK:
                    begin
                        // state transition logic
                        if (write_done)
                        begin
                            AHB_NS = AHB_IDLE;
                        end
                        else
                        begin
                            AHB_NS = AHB_WRITE_ACK;
                        end
                    end
                AHB_READ_ADDRESS:
                    begin
                        // state transition logic
                        if (HREADY)
                        begin
                            AHB_NS = AHB_READ_DATA;
                        end
                        else
                        begin
                            AHB_NS = AHB_READ_ADDRESS;
                        end
                    end
                AHB_READ_DATA:
                    begin
                        // state transition logic
                        if (HREADY && (read_counter == ARLEN_reg + 1)) // incase of burst transfer
                        begin
                            AHB_NS = AHB_READ_ACK;
                        end
                        else if (HREADY && (ARLEN_reg == 0) ) // incase of single transfer
                        begin
                            AHB_NS = AHB_READ_ACK;
                        end
                        else if (HRESP) // if error response come from AHB slave
                        begin
                            AHB_NS = AHB_READ_ACK;
                        end
                        else
                        begin
                            AHB_NS = AHB_READ_DATA;
                        end
                    end
                AHB_READ_ACK:
                    begin
                        // state transition logic
                        if (read_done)
                        begin
                            AHB_NS = AHB_IDLE;
                        end
                        else
                        begin
                            AHB_NS = AHB_READ_ACK;
                        end
                    end  
                default:
                    begin
                        AHB_NS = AHB_IDLE;
                    end
                endcase
            end
            
            // Registers and counters with enable control from AHB FSM
            always_ff @(posedge ACLK or negedge ARESET_n) // asynchronous reset
            begin
                if (!ARESET_n)
                begin
                    // output control parameters of transaction to AHB slave
                    HADDR <= 0;
                    HBURST <= 0;
                    HSIZE <= 0;
                    HWRITE <= 0;
                    HTRANS <= 0;
                    // it will hold reponse from slave in case of reading
                    RRESP_reg <= 0;
                    // it will hold reponse of slave in case of writing
                    BRESP_reg <= 0;
                    // counters
                    read_counter <= 0;
                    write_counter <= 0;
                    // wrap start address that is used when address is wrap around in wrapping burst, which is calculated on the bases of AXI transaction control parameters recieved either from AW or AR channel
                    wrap_start <= 0;
                    // wrap start boundry that is used to detect when to wrap around  in wrapping burst, which is calculated on the bases of AXI transaction control parameters recieved either from AW or AR channel
                    wrap_boundry <= 0;
                    // address that has to be provided with each beat incase of burst and can be incremented as per burst type
                    AHB_write_address <= 0;
                    AHB_read_address <= 0;
                end
                else
                begin
                        if (AHB_PS == AHB_IDLE)
                            begin
                                HADDR <= 0;
                                HBURST <= 0;
                                HSIZE <= 0;
                                HWRITE <= 0;
                                HTRANS <= 0;
                                RRESP_reg <= 0;
                                BRESP_reg <= 0;
                                read_counter <= 0;
                                write_counter <= 0; 
                                wrap_start <= 0;
                                wrap_boundry <= 0;
                                AHB_write_address <= 0;
                                AHB_read_address <= 0;
                            end
                        if (AHB_PS == AHB_WRITE_ADDRESS)
                            begin
                                HADDR <= AWADDR_reg;
                                AHB_write_address <= AWADDR_reg;
                                HTRANS <= 2; // NONSEQ
                                HWRITE <= 1;
                                HSIZE <= AWSIZE_reg;
                                wrap_start <= AWADDR_reg & (~(((AWLEN_reg+1) << AWSIZE_reg) - 1));
                                wrap_boundry <= AWADDR_reg | (((AWLEN_reg+1) << AWSIZE_reg) - 1);
                                case (AWBURST_reg)
                                    2'b00: // Fixed
                                        begin
                                                HBURST <= 0; // Single Transfer
                                        end
                                    2'b01: //Incremental
                                        begin
                                            if (AWLEN_reg != 0)
                                            begin
                                                HBURST <= 1; // incremental burst with undefined length
                                            end
                                            else
                                            begin
                                                HBURST <= 0; // Single Transfer
                                            end
                                        end
                                    2'b10: //wrap
                                        begin
                                            if (AWLEN_reg == 1) // it mean wrap with length 2
                                            begin
                                                HBURST <= 1; // incrementing burst with undefined length
                                            end
                                            else if (AWLEN_reg == 3) // it mean wrap with length 4
                                            begin
                                                HBURST <= 2; // wrap4 burst type
                                            end
                                            else if (AWLEN_reg == 7) // it mean wrap with length 8
                                            begin
                                                HBURST <= 4; // wrap8 burst type
                                            end
                                            else if (AWLEN_reg == 15) // it mean wrap with length 16
                                            begin
                                                HBURST <= 6; // wrap16 burst type
                                            end
                                            else
                                            begin
                                                HBURST <= 0; // Single Transfer
                                            end
                                        end
                                    default: // invalid
                                        begin
                                            HBURST <= 0; // single
                                        end
                                endcase
                            end
                        if (AHB_PS == AHB_WRITE_DATA)
                            begin
                                BRESP_reg <= {HRESP,1'b0};
                                if (HREADY)
                                begin
                                    write_counter <= write_counter + 1;
                                end
                                else
                                begin
                                    write_counter <= write_counter;
                                end
                                
                                if (write_counter == AWLEN_reg && HREADY) // this the last transfer that is going to be sent to AHB on next posedge clk
                                begin
                                    HADDR <= 0;
                                    HBURST <= 0;
                                    HSIZE <= 0;
                                    HWRITE <= 1;
                                    HTRANS <= 0;
                                    AHB_write_address <= 0;
                                end
                                else
                                begin
                                    case (AWBURST_reg)
                                        2'b00: // Fixed
                                            begin
                                                HTRANS <= 2; // NONSEQ
                                                HADDR <= AHB_write_address;
                                            end
                                        2'b01: //Incremental
                                            begin
                                                HTRANS <= 3; // SEQ
                                                if (HREADY)
                                                begin
                                                    HADDR <= AHB_write_address + (1 << AWSIZE_reg); // this address will be assign on next posedge so calculated in present cycle (current_address +beat_size)
                                                    AHB_write_address <= AHB_write_address + (1 << AWSIZE_reg);
                                                end
                                            end
                                        2'b10: //wrap
                                            begin
                                                HTRANS <= 3; // SEQ
                                                if (HREADY)
                                                begin
                                                    if ((AHB_write_address + (1 << AWSIZE_reg)) > wrap_boundry) // if next address cross wrap boundry
                                                    begin
                                                        HADDR <= wrap_start; // then next address will be wrap start address
                                                        AHB_write_address <= wrap_start;
                                                    end
                                                    else
                                                    begin
                                                        HADDR <= AHB_write_address + (1 << AWSIZE_reg); // next address will be current address + beat_size
                                                        AHB_write_address <= AHB_write_address + (1 << AWSIZE_reg);
                                                    end
                                                end
                                            end
                                        default: // invalid
                                            begin
                                                HTRANS <= 0; // IDLE
                                                HADDR <= 0;
                                                AHB_write_address <= 0;
                                            end
                                    endcase
                                end
                            end
                        if (AHB_PS == AHB_WRITE_ACK)
                            begin
                                HADDR <= 0;
                                HBURST <= 0;
                                HSIZE <= 0;
                                HWRITE <= 0;
                                HTRANS <= 0;
                                AHB_write_address <= 0;
                            end
                        if (AHB_PS == AHB_READ_ADDRESS)
                            begin
                                HADDR <= ARADDR_reg;
                                AHB_read_address <= ARADDR_reg;
                                HTRANS <= 2; // NONSEQ
                                HWRITE <= 0;
                                HSIZE <= ARSIZE_reg;
                                wrap_start <= ARADDR_reg & (~(((ARLEN_reg+1) << ARSIZE_reg) - 1));
                                wrap_boundry <= ARADDR_reg | (((ARLEN_reg+1) << ARSIZE_reg) - 1);
                                case (ARBURST_reg)
                                    2'b00: // Fixed
                                        begin
                                                HBURST <= 0; // Single Transfer
                                        end
                                    2'b01: //Incremental
                                        begin
                                            if (ARLEN_reg != 0)
                                            begin
                                                HBURST <= 1; // incremental burst with undefined length
                                            end
                                            else
                                            begin
                                                HBURST <= 0; // Single Transfer
                                            end
                                        end
                                    2'b10: //wrap
                                        begin
                                            if (ARLEN_reg == 1) // it mean wrap with length 2
                                            begin
                                                HBURST <= 1; // incrementing burst with undefined length
                                            end
                                            else if (ARLEN_reg == 3) // it mean wrap with length 4
                                            begin
                                                HBURST <= 2; // wrap4 burst type
                                            end
                                            else if (ARLEN_reg == 7) // it mean wrap with length 8
                                            begin
                                                HBURST <= 4; // wrap8 burst type
                                            end
                                            else if (ARLEN_reg == 15) // it mean wrap with length 16
                                            begin
                                                HBURST <= 6; // wrap16 burst type
                                            end
                                            else
                                            begin
                                                HBURST <= 0; // Single Transfer
                                            end
                                        end
                                    default: // invalid
                                        begin
                                            HBURST <= 0; // single
                                        end
                                endcase
                            end
                        if (AHB_PS == AHB_READ_DATA)
                            begin
                                RRESP_reg <= {HRESP,1'b0};
                                if (HREADY)
                                begin
                                    read_counter <= read_counter + 1;
                                end
                                else
                                begin
                                    read_counter <= read_counter;
                                end
                                if (((read_counter == ARLEN_reg) || (read_counter == ARLEN_reg+1)) && HREADY) // if this is the second last data to be provided then the next tranfer should be of ideal type
                                begin
                                    HADDR <= 0;
                                    HBURST <= 0;
                                    HSIZE <= 0;
                                    HWRITE <= 0;
                                    HTRANS <= 0;
                                    AHB_read_address <= 0;
                                end
                                else
                                begin
                                    case (ARBURST_reg)
                                        2'b00: // Fixed
                                            begin
                                                HTRANS <= 2; // NONSEQ
                                                HADDR <= AHB_read_address;
                                            end
                                        2'b01: //Incremental
                                            begin
                                                HTRANS <= 3; // SEQ
                                                if (HREADY)
                                                begin
                                                    HADDR <= AHB_read_address + (1 << ARSIZE_reg); // similar scenario like incase of writes
                                                    AHB_read_address <= AHB_read_address + (1 << ARSIZE_reg);
                                                end
                                            end
                                        2'b10: //wrap
                                            begin
                                                HTRANS <= 3; // SEQ
                                                if (HREADY)
                                                begin
                                                    if ((AHB_read_address + (1 << ARSIZE_reg)) > wrap_boundry)
                                                    begin
                                                        HADDR <= wrap_start;
                                                        AHB_read_address <= wrap_start;
                                                    end
                                                    else
                                                    begin
                                                        HADDR <= AHB_read_address + (1 << ARSIZE_reg); // +4 here
                                                        AHB_read_address <= AHB_read_address + (1 << ARSIZE_reg);
                                                    end
                                                end
                                            end
                                        default: // invalid
                                            begin
                                                HTRANS <= 0; // IDLE
                                                HADDR <= 0;
                                                AHB_read_address <= 0;
                                            end
                                    endcase
                                end
                            end
                        if (AHB_PS == AHB_READ_ACK)
                            begin
                                HTRANS <= 0; // IDLE
                                HBURST <= 0; // single
                                HADDR <= 0;
                                HSIZE <= 0;
                                AHB_read_address <= 0;
                                RRESP_reg <= RRESP_reg;
                            end
                end
            end
            
            // write data fifo instance
            data_fifo write_data_fifo (
                .clk(ACLK),      // input wire clk
                .srst(~ARESET_n | fifo_rst),    // input wire srst
                .din({WSTRB,WDATA}),      // input wire [35 : 0] din (stores data and strobes)
                .wr_en(write_data_wr_en),  // input wire wr_en
                .rd_en(write_data_rd_en),  // input wire rd_en
                .dout({HWSTRB,HWDATA}),    // output wire [35 : 0] dout
                .full(write_data_full),    // output wire full
                .empty(write_data_empty)  // output wire empty
                );
                
            // read data fifo instance
            data_fifo read_data_fifo (
                .clk(ACLK),      // input wire clk
                .srst(~ARESET_n | fifo_rst),    // input wire srst
                .din({4'd0,HRDATA}),      // input wire [35 : 0] din (in recieving data there is no strobes
                .wr_en(read_data_wr_en),  // input wire wr_en
                .rd_en(read_data_rd_en),  // input wire rd_en
                .dout(RDATA),    // output wire [35 : 0] dout
                .full(read_data_full),    // output wire full
                .empty(read_data_empty)  // output wire empty
                );
                
            // round robin arbiter instance that arbitrate between read and write channels (AW, AR)
            Arbiter_Read_Write Arbitor_inst(.clk(ACLK),
                                            .rst(ARESET_n),
                                            .AWVALID(AWVALID),
                                            .ARVALID(ARVALID),
                                            .ack(arbitor_ack),
                                            .start_writing(start_writing),
                                            .start_reading(start_reading)
                                            );
endmodule
