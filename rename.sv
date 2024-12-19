module rename # (   // rename stage processing one instruction per cycle
    parameter NUM_REG = 32,
    parameter NUM_REG_LOG2 = $clog2(NUM_REG),
    parameter NUM_TAGS = 64,
    parameter NUM_TAGS_LOG2 = $clog2(NUM_TAGS)
) (
    input clk,
    input rst,
    input stall_in,

    input [NUM_TAGS_LOG2-1:0] retire_tag [0:1],
    input [1:0] retire_valid, // assert HIGH when instruction is retired to free up tag_free in free pool

    input [6:0] opcode, 
    input [NUM_REG_LOG2-1:0] rd,
    input [NUM_REG_LOG2-1:0] rs1,
    input [NUM_REG_LOG2-1:0] rs2,

    output logic [NUM_TAGS_LOG2-1:0] tag_rd,
    output logic [NUM_TAGS_LOG2-1:0] tag_rs1,
    output logic [NUM_TAGS_LOG2-1:0] tag_rs2,
    output logic rename_ready,
    
    // load/store stuff
    output logic load_store     // if this is 1 then instruction goes to load/store unit instead of issue queue
);

logic [NUM_TAGS_LOG2-1:0] rat [0:NUM_REG-1];

// 64-bit vector for free pool: 1 at index represent free register, 0 at index represents busy register
logic [NUM_TAGS_LOG2-1:0] tag_counter; 
logic [NUM_TAGS-1:0] free_pool;                  

logic [NUM_TAGS_LOG2-1:0] first_free_tag; // rd pulls from MS asserted bit of free pool
logic [NUM_TAGS_LOG2-1:0] last_free_tag;
logic encoder_valid;

logic stall;
assign stall = ~encoder_valid | stall_in;

assign load_store = (opcode == 7'b0000011 || opcode == 7'b0100011) & rename_ready;

priority_encoder #(
    .WIDTH(NUM_TAGS),
    .TWO_SIDE(0)
) encoder (
    .in (free_pool),
    .out_MSB (first_free_tag),
    .out_LSB (last_free_tag),
    .valid (encoder_valid)
);

always_comb begin
    // assign new tag to destination register
    if (~stall) begin
        tag_rd = (rd != 1'b0) ? first_free_tag : 1'b0;
        rename_ready = 1'b1;
    end else begin
        tag_rd = 1'b0;
        rename_ready = 1'b0;
    end

    // rename rs1, rs2 to tags stored in RAT
    tag_rs1 = rat[rs1];
    tag_rs2 = rat[rs2];
end

always @(posedge clk) begin
    if (rst) begin // initialize RAT and free pool
        int i;
        for (i = 0; i < NUM_REG; i = i+1) begin
            rat[i] <= NUM_REG_LOG2'(i);
        end
        for (i = 0; i < NUM_TAGS; i = i+1) begin
            free_pool[i] <= (i < NUM_REG) ? 1'b0 : 1'b1;
        end
    
    end else if (~stall) begin
        // recover free tag after retire
        for (int i = 0; i < 2; i++) begin
            if (retire_valid[i] && retire_tag[i] != 1'b0) begin
                free_pool[retire_tag[i]] <= 1'b1;
            end
        end

        // write newly assigned tag to RAT. store has rd = 0 so this good!!!
        if (rd != 1'b0) begin
            rat[rd] <= first_free_tag;
            free_pool[first_free_tag] <= 1'b0;
        end
    end
end

initial begin
    // initialize RAT and free pool
    int i;
    for (i = 0; i < NUM_REG; i = i+1) begin
        rat[i] = NUM_REG_LOG2'(i);
    end
    for (i = 0; i < NUM_TAGS; i = i+1) begin
        free_pool[i] = (i < NUM_REG) ? 1'b0 : 1'b1;
    end
end

endmodule

