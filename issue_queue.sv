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
    input load_store,                       // load/store instruction

    // from ARF
    input [REG_SIZE-1:0] data_rs1,          // source register 1 data from ARF
    input [REG_SIZE-1:0] data_rs2,          // source register 2 data from ARF

    // from common data bus (FU computation results)
    input [NUM_TAGS_LOG2-1:0] cdb_tags [0:ISSUE_PORTS-1],   // tags from FU output
    input [REG_SIZE-1:0] cdb_data [0:ISSUE_PORTS-1],        // data from FU output
    input cdb_valid [0:ISSUE_PORTS-1],                      // valid bit of FU output

    input [NUM_TAGS_LOG2-1:0] load_tag,
    input [REG_SIZE-1:0] load_data,
    input load_valid,

    // to FUs (what we issue)
    output logic [3:0] fu_op [0:ISSUE_PORTS-1],                 // operations
    output logic [REG_SIZE-1:0] fu_rs1 [0:ISSUE_PORTS-1],       // rs1
    output logic [REG_SIZE-1:0] fu_rs2 [0:ISSUE_PORTS-1],       // rs2 or immediate
    output logic [NUM_TAGS_LOG2-1:0] fu_tags [0:ISSUE_PORTS-1], // rd tag
    output logic [ROB_SIZE_LOG2-1:0] fu_rob_index [0:ISSUE_PORTS-1],  // rob index
    output logic fu_valid [0:ISSUE_PORTS-1],
    output logic fu_loadstore [0:ISSUE_PORTS-1],
        
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
    [32]        is load_store
    [31:30]     functional unit
    [29:24]     ROB index
    [23:20]     micro-op
    [19:14]     destination tag
    [13:8]      src 1 tag
    [7:2]       src 2 tag       // if src 2 tag is 0, src 2 data stores immediate value (or 0, if immediate is not used)
    [1]         src 1 ready
    [0]         src 2 ready
*/
logic [32:0] iq_tags [0:IQ_SIZE-1]; 

/*
    4 bit representing whether each instruction is ready to forward
*/
logic [3:0] iq_ready [0:IQ_SIZE-1];

// forwarding from CDB to IQ
always_comb begin
    for (int i = 0; i < IQ_SIZE; i = i + 1) begin
        if (iq_tags[i][1] != 1'b1) begin        // rs1 is not ready, check CDB for forwarding
            if (cdb_valid[0] && cdb_tags[0] != 1'b0 && cdb_tags[0] == iq_tags[i][13:8]) begin
                iq_ready[i][3:2] = 2'b00;

            end else if (cdb_valid[1] && cdb_tags[1] != 1'b0 && cdb_tags[1] == iq_tags[i][13:8]) begin
                iq_ready[i][3:2] = 2'b01;
            
            end else if (cdb_valid[2] && cdb_tags[2] != 1'b0 && cdb_tags[2] == iq_tags[i][13:8]) begin
                iq_ready[i][3:2] = 2'b10;
                
            end else begin
                iq_ready[i][3:2] = 2'b11;       // not in CDB
            end
        end else begin
            iq_ready[i][3:2] = 2'b11;           // already ready
        end

        if (iq_tags[i][0] != 1'b1) begin        // rs2 is not ready, check CDB for forwarding
            if (cdb_valid[0] && cdb_tags[0] != 1'b0 && cdb_tags[0] == iq_tags[i][7:2]) begin
                iq_ready[i][1:0] = 2'b00;
            
            end else if (cdb_valid[1] && cdb_tags[1] != 1'b0 && cdb_tags[1] == iq_tags[i][7:2]) begin
                iq_ready[i][1:0] = 2'b01;
            
            end else if (cdb_valid[2] && cdb_tags[2] != 1'b0 && cdb_tags[2] == iq_tags[i][7:2]) begin
                iq_ready[i][1:0] = 2'b10;
            
            end else begin
                iq_ready[i][1:0] = 2'b11;       // not in CDB
            end
        end else begin
            iq_ready[i][1:0] = 2'b11;           // already ready
        end
    end
end

logic [IQ_SIZE_LOG2-1:0] iq_head;
logic [IQ_SIZE_LOG2-1:0] iq_tail;
logic iq_full;
assign iq_full = (iq_head == iq_tail + 1'b1);
assign iq_stall = stall_in | iq_full;

logic [2:0] fu_ready;       // functional unit ready

always @(posedge clk) begin
    fu_ready = 3'b111;
    if (rst) begin
        for (int i = 0; i < IQ_SIZE; i = i + 1) begin
            iq_data[i] <= 64'b0;
            iq_tags[i] <= 32'b0;
        end
        iq_head <= 1'b0;
        iq_tail <= 1'b0;
    end else begin
        if (in_valid) begin
            // write new row to IQ
            // FIFO implementation 
            iq_tail <= iq_tail + 1'b1;
            iq_tags[iq_tail][32] <= load_store;
            iq_tags[iq_tail][31:30] <= 2'b0;
            iq_tags[iq_tail][29:24] <= rob_tail;
            iq_tags[iq_tail][23:20] <= op;

            if (~load_store) begin
                iq_tags[iq_tail][19:14] <= tag_rd;
            end else begin // if load or store instruction, don't want to actually commit/retire this computation
                iq_tags[iq_tail][19:14] <= 5'b0;
            end
            iq_tags[iq_tail][13:8]  <= tag_rs1;
            iq_tags[iq_tail][7:2]   <= tag_rs2;

            // when entering a new entry in the issue queue, look for rs1, rs2 data from CDB -> ROB -> ARF.
            if (tag_rs1 == cdb_tags[0] && tag_rs1 != 1'b0) begin
                iq_tags[iq_tail][1] <= 1'b1;            // rs1 is ready
                iq_data[iq_tail][63:32] <= cdb_data[0]; // load CDB data into src 1 data

            end else if (tag_rs1 == cdb_tags[1] && tag_rs1 != 1'b0) begin
                iq_tags[iq_tail][1] <= 1'b1;
                iq_data[iq_tail][63:32] <= cdb_data[1];

            end else if (tag_rs1 == cdb_tags[2] && tag_rs1 != 1'b0) begin
                iq_tags[iq_tail][1] <= 1'b1;
                iq_data[iq_tail][63:32] <= cdb_data[2];

            end else if (rob_ready_rs[0]) begin
                iq_tags[iq_tail][1] <= 1'b1;
                if (rob_contains_rs[0]) begin
                    // write ROB data to src 1
                    iq_data[iq_tail][63:32] <= rob_data_rs[0];
                end else begin
                    // write ARF data to src 1
                    iq_data[iq_tail][63:32] <= data_rs1;
                end

            end else if (load_valid && tag_rs1 == load_tag && tag_rs1 != 1'b0) begin
                iq_tags[iq_tail][1] <= 1'b1;
                iq_data[iq_tail][63:32] <= load_data;

            end else begin
                iq_tags[iq_tail][1] <= 1'b0;
            end

            // load values for rs2 from CDB/ROB/ARF
            if (tag_rs2 == 1'b0 || load_store) begin    // if load/store ignore rs2
                iq_tags[iq_tail][0] <= 1'b1;
                iq_data[iq_tail][31:0] <= imm;          // load immediate into src 2 data

            end else if (tag_rs2 == cdb_tags[0]) begin
                iq_tags[iq_tail][0] <= 1'b1;
                iq_data[iq_tail][31:0] <= cdb_data[0];  // load CDB data into src 2 data

            end else if (tag_rs2 == cdb_tags[1]) begin
                iq_tags[iq_tail][0] <= 1'b1;
                iq_data[iq_tail][31:0] <= cdb_data[1];

            end else if (tag_rs2 == cdb_tags[2]) begin
                iq_tags[iq_tail][0] <= 1'b1;
                iq_data[iq_tail][31:0] <= cdb_data[2];

            end else if (load_valid && tag_rs2 == load_tag) begin
                iq_tags[iq_tail][0] <= 1'b1;
                iq_data[iq_tail][31:0] <= load_data;

            end else if (rob_ready_rs[1]) begin
                iq_tags[iq_tail][0] <= 1'b1;
                if (rob_contains_rs[1]) begin
                    // write ROB data to src 2
                    iq_data[iq_tail][31:0] <= rob_data_rs[1];
                end else begin
                    // write ARF data to src 2
                    iq_data[iq_tail][31:0] <= data_rs2;
                end

            end else if (load_valid && tag_rs2 == load_tag) begin
                iq_tags[iq_tail][1] <= 1'b1;
                iq_data[iq_tail][31:0] <= load_data;

            end else begin
                iq_tags[iq_tail][0] <= 1'b0;
            end
        end

        // input CDB data into IQ
        for (int i = 0; i < IQ_SIZE; i = i + 1) begin
            if (iq_ready[i][3:2] != 2'b11) begin
                iq_tags[i][1] <= 1'b1; // rs1 is ready
                iq_data[i][63:32] <= cdb_data[iq_ready[i][3:2]];
            end
            if (iq_ready[i][1:0] != 2'b11) begin
                iq_tags[i][0] <= 1'b1; // rs2 is ready
                iq_data[i][31:0] <= cdb_data[iq_ready[i][1:0]];
            end

            if (iq_tags[i][1] != 1'b1 && load_valid && load_tag != 1'b0 && load_tag == iq_tags[i][13:8]) begin        // rs1 is not ready, check CDB for forward from loadstore unit
                iq_tags[i][1] <= 1'b1;
                iq_data[i][63:32] <= load_data;
            end
            if (iq_tags[i][0] != 1'b1 && load_valid && load_tag != 1'b0 && load_tag == iq_tags[i][7:2]) begin        // rs2 is not ready, check CDB for forward from loadstore unit
                iq_tags[i][0] <= 1'b1;
                iq_data[i][31:0] <= load_data;
            end
        end

        // issue logic
        if (fu_ready != 3'b000) begin // at least one FU is ready, so can attempt to issue
            fu_loadstore[0] = 1'b0;
            fu_loadstore[1] = 1'b0;
            fu_loadstore[2] = 1'b0;
            
            for (int i = 0; i < 64; i = i + 1) begin
                if ((iq_tags[i][1] || iq_ready[i][3:2] != 2'b11)
                    && (iq_tags[i][0] || iq_ready[i][1:0] != 2'b11)) begin // instruction is ready to be issued

                    if (fu_ready[0] == 1'b1) begin 
                        fu_ready[0] = 1'b0;
                        
                        fu_op[0] <= iq_tags[i][23:20]; // op type
                        fu_rs1[0] <= (iq_tags[i][1]) ? (iq_data[i][63:32]) : (cdb_data[iq_ready[i][3:2]]);
                        fu_rs2[0] <= (iq_tags[i][0]) ? (iq_data[i][31:0]) : (cdb_data[iq_ready[i][1:0]]);
                        fu_tags[0] <= iq_tags[i][19:14];
                        fu_rob_index[0] <= iq_tags[i][29:24];
                        fu_loadstore[0] = iq_tags[i][32];

                        iq_data[i] <= 64'b0;
                        iq_tags[i] <= 32'b0;
                        // iq_head = iq_head + 1'b1;

                    end else if (fu_ready[1] == 1'b1) begin
                        fu_ready[1] = 1'b0;

                        fu_op[1] <= iq_tags[i][23:20]; // op type
                        fu_rs1[1] <= (iq_tags[i][1]) ? (iq_data[i][63:32]) : (cdb_data[iq_ready[i][3:2]]); 
                        fu_rs2[1] <= (iq_tags[i][0]) ? (iq_data[i][31:0]) : (cdb_data[iq_ready[i][1:0]]);
                        fu_tags[1] <= iq_tags[i][19:14];
                        fu_rob_index[1] <= iq_tags[i][29:24];
                        fu_loadstore[1] = iq_tags[i][32];

                        iq_data[i] <= 64'b0;
                        iq_tags[i] <= 32'b0;
                        // iq_head = iq_head + 1'b1;

                        
                    end else if (fu_ready[2] == 1'b1) begin
                        fu_ready[2] = 1'b0;

                        fu_op[2] <= iq_tags[i][23:20]; // op type
                        fu_rs1[2] <= (iq_tags[i][1]) ? (iq_data[i][63:32]) : (cdb_data[iq_ready[i][3:2]]);
                        fu_rs2[2] <= (iq_tags[i][0]) ? (iq_data[i][31:0]) : (cdb_data[iq_ready[i][1:0]]);
                        fu_tags[2] <= iq_tags[i][19:14];
                        fu_rob_index[2] <= iq_tags[i][29:24];
                        fu_loadstore[2] = iq_tags[i][32];

                        iq_data[i] <= 64'b0;
                        iq_tags[i] <= 32'b0;
                        // iq_head = iq_head + 1'b1;

                    end 
                end
            end
        end

    fu_valid[0] <= ~fu_ready[0];
    fu_valid[1] <= ~fu_ready[1];
    fu_valid[2] <= ~fu_ready[2];

    end
end


// // issue logic
// always_comb begin
//     fu_ready = 3'b111;
    
//     fu_op[0] = 4'b0;
//     fu_rs1[0] = 32'b0;
//     fu_rs2[0] = 32'b0;
//     fu_tags[0] = 6'b0;
//     fu_rob_index[0] = 6'b0;
    
//     fu_op[1] = 4'b0;
//     fu_rs1[1] = 32'b0;
//     fu_rs2[1] = 32'b0;
//     fu_tags[1] = 6'b0;
//     fu_rob_index[1] = 6'b0;

//     fu_op[2] = 4'b0;
//     fu_rs1[2] = 32'b0;
//     fu_rs2[2] = 32'b0;
//     fu_tags[2] = 6'b0;
//     fu_rob_index[2] = 6'b0;

//     for (int i = 0; i < 64; i = i + 1) begin
//         if ((iq_tags[i][1] || iq_ready[i][3:2] != 2'b11)
//             && (iq_tags[i][0] || iq_ready[i][1:0] != 2'b11)) begin // instruction is ready to be issued

//             if (fu_ready[0] == 1'b1) begin 
//                 fu_ready[0] = 1'b0;
                
//                 fu_op[0] = iq_tags[i][23:20]; // op type
//                 fu_rs1[0] = (iq_tags[i][1]) ? (iq_data[i][63:32]) : (cdb_data[iq_ready[i][3:2]]);
//                 fu_rs2[0] = (iq_tags[i][0]) ? (iq_data[i][31:0]) : (cdb_data[iq_ready[i][1:0]]);
//                 fu_tags[0] = iq_tags[i][19:14];
//                 fu_rob_index[0] = iq_tags[i][29:24];

//             end else if (fu_ready[1] == 1'b1) begin
//                 fu_ready[1] = 1'b0;

//                 fu_op[1] = iq_tags[i][23:20]; // op type
//                 fu_rs1[1] = (iq_tags[i][1]) ? (iq_data[i][63:32]) : (cdb_data[iq_ready[i][3:2]]);
//                 fu_rs2[1] = (iq_tags[i][0]) ? (iq_data[i][31:0]) : (cdb_data[iq_ready[i][1:0]]);
//                 fu_tags[1] = iq_tags[i][19:14];
//                 fu_rob_index[1] = iq_tags[i][29:24];
                
//             end else if (fu_ready[2] == 1'b1) begin
//                 fu_ready[2] = 1'b0;

//                 fu_op[2] = iq_tags[i][23:20]; // op type
//                 fu_rs1[2] = (iq_tags[i][1]) ? (iq_data[i][63:32]) : (cdb_data[iq_ready[i][3:2]]);
//                 fu_rs2[2] = (iq_tags[i][0]) ? (iq_data[i][31:0]) : (cdb_data[iq_ready[i][1:0]]);
//                 fu_tags[2] = iq_tags[i][19:14];
//                 fu_rob_index[2] = iq_tags[i][29:24];

//             end 
//         end
//     end

//     fu_valid[0] <= ~fu_ready[0];
//     fu_valid[1] <= ~fu_ready[1];
//     fu_valid[2] <= ~fu_ready[2];
// end


initial begin
    for (int i = 0; i < IQ_SIZE; i = i + 1) begin
        iq_data[i] <= 64'b0;
        iq_tags[i] <= 32'b0;
    end
    iq_head <= 1'b0;
    iq_tail <= 1'b0;
end

endmodule