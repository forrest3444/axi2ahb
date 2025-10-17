`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: NCDC
// Engineer: WADOOD ALAM
// 
// Create Date: 12/13/2024 11:10:29 AM
// Design Name: 
// Module Name: Arbiter_Read_Write
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


module Arbiter_Read_Write(input clk,
                          input rst,
                          input AWVALID,
                          input ARVALID,
                          input ack,
                          output logic start_writing,
                          output logic start_reading
                          );
                          
     typedef enum logic [4:0] {
                               IDLE = 5'b00001,
                               WRITE = 5'b00010,
                               READ = 5'b00100,
                               NEXT_IS_WRITE = 5'b01000,
                               NEXT_IS_READ = 5'b10000
                               } ARBITER_FSM_STATES;
                               
     ARBITER_FSM_STATES ARBITER_PS, ARBITER_NS;
     
     // state transition logic
     always_ff @(posedge clk or negedge rst)
     begin
        if (!rst)
            ARBITER_PS <= IDLE;
        else
            ARBITER_PS <= ARBITER_NS;
     end
     
     // next state calculation block (combinational
     always_comb
     begin
        case(ARBITER_PS)
            IDLE:
                begin
                    if (AWVALID && ack) // initially Write channel has highest priority
                        ARBITER_NS = WRITE;
                    else if (ARVALID && ack)
                        ARBITER_NS = READ;
                    else
                        ARBITER_NS = IDLE;
                end
            WRITE: // In this state the priority should be given to reads
                begin
                    ARBITER_NS = NEXT_IS_READ;
                end
            NEXT_IS_READ:
                begin
                    if (ack && ARVALID)
                        ARBITER_NS = READ;
                    else if (ack && AWVALID && (!ARVALID))
                        ARBITER_NS = WRITE;
                    else
                        ARBITER_NS = NEXT_IS_READ;
                end
            READ:
                begin
                    ARBITER_NS = NEXT_IS_WRITE;
                end
            NEXT_IS_WRITE:
                begin
                    if (ack && AWVALID)
                        ARBITER_NS = WRITE;
                    else if (ack && ARVALID && (!AWVALID))
                        ARBITER_NS = READ;
                    else
                        ARBITER_NS = NEXT_IS_WRITE;
                end
            default:
                begin
                    ARBITER_NS = IDLE;
                end
        endcase
     end
     
     assign start_writing = (ARBITER_PS == WRITE);
     assign start_reading = (ARBITER_PS == READ);
endmodule
