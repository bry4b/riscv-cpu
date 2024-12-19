module loadstore_queue #(
    parameter LSQ_SIZE = 16,
    parameter LSQ_SIZE_LOG2 = $clog2(LSQ_SIZE),
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

    // from rename/ROB
    input [6:0] opcode, 
    input [2:0] funct3,
    input [NUM_TAGS_LOG2-1:0] tag_rd,               // destination register (for LOADs)
    input [NUM_TAGS_LOG2-1:0] tag_rs2,              // source register 2 (for STOREs, storing rs2 into mem[rs1 + imm])
    input in_valid,                                 // valid bit -> load_store

    // output logic [NUM_TAGS_LOG2-1:0] rob_tag_rs2,
    input [ROB_SIZE_LOG2-1:0] rob_tail,
    input [REG_SIZE-1:0] rob_rs2_data,
    input rob_ready_rs2,
    input rob_contains_rs2,
    input [REG_SIZE-1:0] arf_rs2_data,

    // from common data bus (FU computation results)
    input [NUM_TAGS_LOG2-1:0] cdb_tags [0:2],   // tags from FU output
    input [REG_SIZE-1:0] cdb_data [0:2],        // data from FU output
    input [ROB_SIZE_LOG2-1:0] cdb_rob_index [0:2],  // rob index of FU output
    input cdb_valid [0:2],                       // valid bit of FU output

    output logic [REG_SIZE-1:0] load_rd,
    output logic [ROB_SIZE_LOG2-1:0] load_rob_index,  // rob index of completed load
    output logic load_ready

);

/*
    load store queue layout: 
    [0:31]      memory address
    [32:63]     store data
    [64:68]     store register tag
    [69:74]     rob index
    [75]        load/store? 1 = store, 0 = load
    [76]        is rs2 ready?
    [77]        is memory address ready?
    [78]        byte/word? 1 = word, 0 = byte
*/
logic [78:0] lsq [0:LSQ_SIZE-1];

logic [LSQ_SIZE_LOG2-1:0] lsq_head;
logic [LSQ_SIZE_LOG2-1:0] lsq_tail;

logic [7:0] data_mem [0:31]; // 32 bytes of mem

// write to queue
always @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < LSQ_SIZE; i = i + 1) begin
            lsq[i] <= 1'b0;
            lsq_head <= 1'b0;
            lsq_tail <= 1'b0;
        end
        for (int i = 0; i < 32; i++) begin
            data_mem[i] <= 8'b0;
        end
        counter <= 4'd0;
        
    end else begin
        if (in_valid) begin
            lsq_tail <= lsq_tail + 1'b1;
            
            lsq[lsq_tail][31:0] <= 1'b0;
            lsq[lsq_tail][68:64] <= tag_rs2; // if store
            lsq[lsq_tail][74:69] <= rob_tail;
            lsq[lsq_tail][75] <= opcode[5]; // load/store
            lsq[lsq_tail][77] <= 1'b0; // instruction doesn't have memory address yet
            lsq[lsq_tail][78] <= funct3 != 1'b0; // byte/word

            if (opcode[5] == 1'b1) begin // only if instruction is a store do we try to get rs2 data
                if (tag_rs2 == cdb_tags[0]) begin
                    lsq[lsq_tail][63:32] <= cdb_data[0];
                    lsq[lsq_tail][76] <= 1'b1;

                end else if (tag_rs2 == cdb_tags[1]) begin
                    lsq[lsq_tail][63:32] <= cdb_data[1];
                    lsq[lsq_tail][76] <= 1'b1;

                end else if (tag_rs2 == cdb_tags[2]) begin
                    lsq[lsq_tail][63:32] <= cdb_data[2];
                    lsq[lsq_tail][76] <= 1'b1;
                    
                end else if (rob_ready_rs2) begin       // if rs2 is ready (either in ROB or in ARF)
                    if (rob_contains_rs2) begin         // if rs2 in ROB
                        lsq[lsq_tail][63:32] <= rob_rs2_data;
                    end else begin                      // if rs2 in ARF
                        lsq[lsq_tail][63:32] <= arf_rs2_data;
                    end
                    lsq[lsq_tail][76] <= 1'b1;
                
                end else begin
                    lsq[lsq_tail][76] <= 1'b0; // rs2 data is NOT ready therefore cannot store
                end
            end
        end 

        // update queue with memory address, or get rs2 value from CDB
        if (cdb_valid[0]) begin
            for (int i = 0; i < LSQ_SIZE; i = i + 1) begin
                if (lsq[i][74:69] == cdb_rob_index[0]) begin
                    lsq[i][31:0] <= cdb_data[0];
                    lsq[i][77] <= 1'b1;
                end else if (lsq[i][68:64] == cdb_rob_index[0]) begin
                    lsq[i][63:32] <= cdb_data[0];
                    lsq[i][76] <= 1'b1;
                end
            end
        end
        if (cdb_valid[1]) begin
            for (int i = 0; i < LSQ_SIZE; i = i + 1) begin
                if (lsq[i][74:69] == cdb_rob_index[1]) begin
                    lsq[i][31:0] <= cdb_data[1];
                    lsq[i][77] <= 1'b1;
                end else if (lsq[i][68:64] == cdb_rob_index[1]) begin
                    lsq[i][63:32] <= cdb_data[1];
                    lsq[i][76] <= 1'b1;
                end
            end
        end
        if (cdb_valid[2]) begin
            for (int i = 0; i < LSQ_SIZE; i = i + 1) begin
                if (lsq[i][74:69] == cdb_rob_index[2]) begin
                    lsq[i][31:0] <= cdb_data[2];
                    lsq[i][77] <= 1'b1;
                end else if (lsq[i][68:64] == cdb_rob_index[2]) begin
                    lsq[i][63:32] <= cdb_data[2];
                    lsq[i][76] <= 1'b1;
                end
            end
        end

        // issue
        if (lsq[lsq_head][77] == 1'b1) begin
            if (lsq[lsq_head][75] == 1'b1 && lsq[lsq_head][76] == 1'b1) begin // STORE (need mem address and rs2 ready)
                if (lsq[lsq_head][78] == 1'b1) begin // store WORD
                    data_mem[lsq[lsq_head][31:0]] <= lsq[lsq_head][63:56];
                    data_mem[lsq[lsq_head][31:0] + 1] <= lsq[lsq_head][55:48];
                    data_mem[lsq[lsq_head][31:0] + 2] <= lsq[lsq_head][47:40];
                    data_mem[lsq[lsq_head][31:0] + 3] <= lsq[lsq_head][39:32];

                end else begin // store BYTE
                    data_mem[lsq[lsq_head][31:0]] <= lsq[lsq_head][39:32];
                end

                if (counter == 4'd10) begin
                    lsq[lsq_head] <= 1'b0;
                    lsq_head <= lsq_head + 1'b1;
                    load_ready <= 1'b1;
                    counter <= 4'd0;
                end else begin
                    load_ready <= 1'b0;
                    counter <= counter + 1'b1;
                end

            end else if (lsq[lsq_head][75] == 1'b0) begin // LOAD (only care about mem address being ready)
                if (lsq[lsq_head][78] == 1'b1) begin  // load WORD
                    load_rd[31:24] <= data_mem[lsq[lsq_head][31:0]];
                    load_rd[23:16] <= data_mem[lsq[lsq_head][31:0] + 1];
                    load_rd[15:8] <= data_mem[lsq[lsq_head][31:0] + 2];
                    load_rd[7:0] <= data_mem[lsq[lsq_head][31:0] + 3];
                    load_rob_index <= lsq[lsq_head][74:69];
                    
                end else begin // load BYTE
                    load_rd[31:8] <= 1'b0;
                    load_rd[7:0] <= data_mem[lsq[lsq_head][31:0]];
                    load_rob_index <= lsq[lsq_head][74:69];
                end

                if (counter == 4'd10) begin
                    lsq[lsq_head] <= 1'b0;
                    lsq_head <= lsq_head + 1'b1;
                    load_ready <= 1'b1;
                    counter <= 4'd0;
                end else begin
                    load_ready <= 1'b0;
                    counter <= counter + 1'b1;
                end
            end
        end 
    end
end

logic [3:0] counter;

endmodule