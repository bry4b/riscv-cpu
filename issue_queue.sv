module issue_queue #(
    parameter IQ_SIZE = 64,
    parameter ISSUE_PORTS = 3,
    parameter INSTR_SIZE = 32
) (
    input clk,
    input rst,
    input stall_in, 

    // from ROB
    input [ROB_SIZE_LOG2-1:0] rob_tail,     // reorder buffer tail
    input [REG_SIZE-1:0] data_rs_rob [0:1],
    input valid_data_rs [0:1],

    // from rename
    input [4:0] op,                         // operation: 4-bit alu_sel + 1 bit for load/store
    input [NUM_TAGS_LOG2-1:0] tag_rd,       // destination register
    input [NUM_TAGS_LOG2-1:0] tag_rs1,      // source register 1
    input [NUM_TAGS_LOG2-1:0] tag_rs2,      // source register 2
    input [31:0] imm,                       // immediate
    input in_valid,                         // instruction valid
    
    // from ARF
    input [REG_SIZE-1:0] data_rs1,          // source register 1 data from ARF
    input [REG_SIZE-1:0] data_rs2,          // source register 2 data from ARF
    
    // from common data bus (FU computation results)
    input [NUM_TAGS_LOG2-1:0] cdb_tags [0:ISSUE_PORTS-1],   // tags from FU output
    input [REG_SIZE-1:0] cdb_data [0:ISSUE_PORTS-1],        // data from FU output
    input cdb_valid [0:ISSUE_PORTS-1],                      // valid bit of FU output

    // to FUs (what we issue)
    output logic [4:0] fu_op [0:ISSUE_PORTS-1],                 // operations
    output logic [REG_SIZE-1:0] fu_rs1 [0:ISSUE_PORTS-1],       // rs1
    output logic [REG_SIZE-1:0] fu_rs2 [0:ISSUE_PORTS-1],       // rs2 or immediate
    output logic [NUM_TAGS_LOG2-1:0] fu_tags [0:ISSUE_PORTS-1], // rd tag
    output logic [ROB_SIZE_LOG2-1:0] fu_rob [0:ISSUE_PORTS-1]   // rob index
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
    [28:27]     functional unit
    [26:21]     ROB index
    [20:15]     destination tag
    [14:9]      src 1 tag
    [8:3]       src 2 tag
    [2]         immediate flag (1 if src2 holds immediate value)
    [1]         src 1 ready
    [0]         src 2 ready
*/
logic [28:0] iq_tags [0:IQ_SIZE-1]; 

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < IQ_SIZE; i = i + 1) begin
            iq_data[i] = 64'b0;
            iq_tags[i] = 29'b0;
        end
    end else begin
        if (in_valid) begin
            // write new instruction tags to IQ
            // probably use priority queue to find first available entry of IQ

            if (valid_data_rs[0]) begin
                // write ROB data to src 1
            end else begin
                // write ARF data to src 1
            end
            if (valid_data_rs[1]) begin
                // write ROB data to src 2
            end else begin
                // write ARF data to src 2
            end
        end
    
        // use 64 bit ready vector - each bit corresponds to a row in IQ, assign bit = rs1 ready & rs2 ready & row valid

    end
end

initial begin
    for (int i = 0; i < IQ_SIZE; i = i + 1) begin
        iq_data[i] = 64'b0;
        iq_tags[i] = 29'b0;
    end
end

endmodule