module issue_queue #(
    parameter IQ_SIZE = 16,
    parameter ISSUE_PORTS = 2,
    parameter INSTR_SIZE = 32
) (
    input clk,
    input rst,
    input stall_in, 

    input [ROB_SIZE_LOG2-1:0] rob_index,    // reorder buffer tail
    input [4:0] uop,                        // micro-op
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
    issue queue layout:
                            
*/

logic [] reservation_station [0:IQ_SIZE-1];

endmodule