module issue_queue #(
    parameter IQ_SIZE = 16,
    parameter ISSUE_PORTS = 2,
    parameter INSTR_SIZE = 32
) (
    input clk,
    input rst,
    input stall_in, 

    input [ROB_SIZE_LOG2-1:0] rob_index,    // reorder buffer tail
    input [4:0] op,                         // operation: 4-bit alu_sel + 1 bit for load/store
    input [NUM_REG_LOG2:0] prs1,            // source register 1
    input [NUM_REG_LOG2:0] prs2,            // source register 2
    input [NUM_REG_LOG2:0] prd,             // destination register
    input [REG_SIZE-1:0] prs1_data,         // source register 1 data
    input [REG_SIZE-1:0] prs2_data,         // source register 2 data
    input [REG_SIZE-1:0] prd_data,          // destination register data
    input [31:0] imm,                       // immediate
    input in_valid,                         // instruction valid

);

`include "constants.sv"

/*  
    reservation station data layout:
    [127:96]    dest data
    [95:64]     src 1 
    [63:32]     src 2
    [31:0]      immediate           
*/
logic [REG_SIZE*4-1:0] iq_data [0:IQ_SIZE-1];

/* 
    reservation station tags layout:
    [8]         tag for dest reg 
    [7]         tag for src 1
    [6]         tag for src 2 
                    HIGH: src 2 contains real data 
                    LOW: src 2 contains iq_data row index where dest data contains data 
    [5:4]       assigned functional unit
    [3:0]       ROB index
*/
logic [8:0] iq_tags [0:IQ_SIZE-1]; 

logic [4:0] register_status [0:NUM_REG*2-1];



endmodule