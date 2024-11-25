module issue_queue #(
    parameter IQ_SIZE = 64,
    parameter ISSUE_PORTS = 3,
    parameter INSTR_SIZE = 32
) (
    input clk,
    input rst,
    input stall_in, 

    // from ROB: retire up to one instruction per cycle
    input [ROB_SIZE_LOG2-1:0] rob_tail,     // reorder buffer tail
    input [REG_SIZE-1:0] data_rs_rob [0:1],
    input ready_rs [0:1],

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
    output logic [ROB_SIZE_LOG2-1:0] fu_rob [0:ISSUE_PORTS-1],  // rob index
     
    output logic iq_stall
);

`include "constants.sv"
localparam IQ_SIZE_LOG2 = $clog2(IQ_SIZE);

/*
    reservation station data layout:
    [63:32]     src 1 
    [31:0]      src 2 / immediate           
*/
logic [REG_SIZE*2-1:0] iq_data [0:IQ_SIZE-1];

/* 
    reservation station tags layout:
    [32:31]     functional unit
    [30:25]     ROB index
    [24:20]     micro-op
    [19:14]     destination tag
    [13:8]      src 1 tag
    [7:2]       src 2 tag       // if src 2 tag is 0, src 2 data stores immediate value (or 0, if immediate is not used)
    [1]         src 1 ready
    [0]         src 2 ready
*/
logic [32:0] iq_tags [0:IQ_SIZE-1]; 

logic [IQ_SIZE_LOG2-1:0] iq_head;
logic [IQ_SIZE_LOG2-1:0] iq_tail;
logic iq_full;
assign iq_full = (rob_head == rob_tail + 1'b1);
assign iq_stall = stall_in | iq_full;

logic [2:0] fu_ready;       // functional unit ready

always_ff @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < IQ_SIZE; i = i + 1) begin
            iq_data[i] <= 64'b0;
            iq_tags[i] <= 33'b0;
        end
        iq_head <= 1'b0;
        iq_tail <= 1'b0;
        fu_ready <= 3'b0;
    end else begin
        if (in_valid) begin
            // write new row to IQ
            // FIFO implementation 
            iq_tail <= iq_tail + 1'b1;

            iq_tags[iq_head][32:31] <= 2'b0;        // TODO: ASSIGN FUNCTIONAL UNITS (ROUND-ROBIN? PRIORITY? ASSIGN WHEN ISSUE?)
            iq_tags[iq_head][30:25] <= rob_tail;
            iq_tags[iq_head][24:20] <= op;
            iq_tags[iq_head][19:14] <= tag_rd;
            iq_tags[iq_head][13:8]  <= tag_rs1;
            iq_tags[iq_head][7:2]   <= tag_rs2;
            iq_tags[iq_head][1:0]   <= ready_rs;

            if (ready_rs[0]) begin
                // write ROB data to src 1
                iq_data[iq_head][63:32] <= data_rs_rob[0];
            end else begin
                // write ARF data to src 1
                iq_data[iq_head][63:32] <= data_rs1;
            end

            if (ready_rs[1]) begin
                // write ROB data to src 2
                iq_data[iq_head][31:0] <= data_rs_rob[1];
            end else begin
                // write ARF data to src 2
                iq_data[iq_head][31:0] <= data_rs2;
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