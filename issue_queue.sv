module issue_queue #(
    parameter IQ_SIZE = 64,
    parameter ISSUE_PORTS = 3,
    parameter INSTR_SIZE = 32,
    parameter REG_SIZE = 32,
    parameter NUM_TAGS = 64,
    parameter NUM_TAGS_LOG2 = $clog2(NUM_TAGS),
    parameter ROB_SIZE = 64,
    parameter ROB_SIZE_LOG2 = $clog2(ROB_SIZE)
) (
    input clk,
    input rst,
    input stall_in, 

    // from ROB: retire up to one instruction per cycle
    input [ROB_SIZE_LOG2-1:0] rob_tail,     // reorder buffer tail
    input [REG_SIZE-1:0] rob_data_rs [0:1],
    input rob_contains_rs [0:1],
    input rob_ready_rs [0:1],

    // from rename
    input [3:0] op,                         // operation: 4-bit alu_sel (load/store bit not needed due to separate load/store queue)
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
    output logic [3:0] fu_op [0:ISSUE_PORTS-1],                 // operations
    output logic [REG_SIZE-1:0] fu_rs1 [0:ISSUE_PORTS-1],       // rs1
    output logic [REG_SIZE-1:0] fu_rs2 [0:ISSUE_PORTS-1],       // rs2 or immediate
    output logic [NUM_TAGS_LOG2-1:0] fu_tags [0:ISSUE_PORTS-1], // rd tag
    output logic [ROB_SIZE_LOG2-1:0] fu_rob_index [0:ISSUE_PORTS-1],  // rob index
        
    output logic iq_stall
);

// `include "constants.sv"
localparam IQ_SIZE_LOG2 = $clog2(IQ_SIZE);

/*
    reservation station data layout:
    [63:32]     src 1 
    [31:0]      src 2 / immediate           
*/
logic [REG_SIZE*2-1:0] iq_data [0:IQ_SIZE-1];

/* 
    reservation station tags layout:
    [31:30]     functional unit
    [29:24]     ROB index
    [23:20]     micro-op
    [19:14]     destination tag
    [13:8]      src 1 tag
    [7:2]       src 2 tag       // if src 2 tag is 0, src 2 data stores immediate value (or 0, if immediate is not used)
    [1]         src 1 ready
    [0]         src 2 ready
*/
logic [31:0] iq_tags [0:IQ_SIZE-1]; 

logic [IQ_SIZE_LOG2-1:0] iq_head;
logic [IQ_SIZE_LOG2-1:0] iq_tail;
logic iq_full;
assign iq_full = (iq_head == iq_tail + 1'b1);
assign iq_stall = stall_in | iq_full;

logic [2:0] fu_ready;       // functional unit ready

always @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < IQ_SIZE; i = i + 1) begin
            iq_data[i] <= 64'b0;
            iq_tags[i] <= 32'b0;
        end
        iq_head <= 1'b0;
        iq_tail <= 1'b0;
        fu_ready <= 3'b0;
    end else begin
        if (in_valid) begin
            // write new row to IQ
            // FIFO implementation 
            iq_tail <= iq_tail + 1'b1;

            iq_tags[iq_tail][31:30] <= 2'b0;        // TODO: ASSIGN FUNCTIONAL UNITS (ROUND-ROBIN? PRIORITY? ASSIGN WHEN ISSUE?)
            iq_tags[iq_tail][29:24] <= rob_tail;
            iq_tags[iq_tail][23:20] <= op;
            iq_tags[iq_tail][19:14] <= tag_rd;
            iq_tags[iq_tail][13:8]  <= tag_rs1;
            iq_tags[iq_tail][7:2]   <= tag_rs2;
            iq_tags[iq_tail][1:0]   <= {rob_ready_rs[1], rob_ready_rs[0]};

            if (rob_ready_rs[0]) begin
                if (rob_contains_rs[0]) begin
                    // write ROB data to src 1
                    iq_data[iq_tail][63:32] <= rob_data_rs[0];
                end else begin
                    // write ARF data to src 1
                    iq_data[iq_tail][63:32] <= data_rs1;
                end
            end

            if (tag_rs2 == 1'b0) begin
                // load immediate into src 2 data
                iq_data[iq_tail][31:0] <= imm;
            end else if (rob_ready_rs[1]) begin
                if (rob_contains_rs[1]) begin
                    // write ROB data to src 2
                    iq_data[iq_tail][31:0] <= rob_data_rs[1];
                end else begin
                    // write ARF data to src 2
                    iq_data[iq_tail][31:0] <= data_rs2;
                end
            end
        end
    end
end

initial begin
    for (int i = 0; i < IQ_SIZE; i = i + 1) begin
        iq_data[i] <= 64'b0;
        iq_tags[i] <= 32'b0;
    end
    iq_head <= 1'b0;
    iq_tail <= 1'b0;
    fu_ready <= 3'b0;
end

endmodule