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
    [63:32]     src 1 
    [31:0]      src 2 / immediate           
*/
logic [REG_SIZE*2-1:0] iq_data [0:IQ_SIZE-1];

/* 
    reservation station tags layout:
    [27:25]     functional units ready
    [24:19]     destination tag
    [18:13]     src 1 tag
    [12]        src 1 ready
    [11:6]      src 2 tag
    [5]         src 2 ready
    [4]         immediate flag (1 if src2 holds immediate value)
    [3:0]       ROB index
*/
logic [27:0] iq_tags [0:IQ_SIZE-1]; 

logic [4:0] register_status [0:NUM_REG*2-1];



endmodule