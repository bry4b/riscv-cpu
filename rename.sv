module rename # (   // rename stage processing one instruction per cycle
    parameter NUM_REG = 32,
    parameter NUM_REG_LOG2 = $clog2(NUM_REG),
    parameter NUM_TAG = 64,
    parameter NUM_TAG_LOG2 = $clos(NUM_TAG)
) (
    input clk,
    input rst,
    input stall_in,

    input [NUM_REG_LOG2:0] tag_free,
    input commit_free, // assert HIGH when instruction is committed to free up tag_free in free pool

    input [NUM_REG_LOG2-1:0] rd,
    input [NUM_REG_LOG2-1:0] rs1,
    input [NUM_REG_LOG2-1:0] rs2,

    output logic [NUM_REG_LOG2:0] tag_old,
    output logic [NUM_REG_LOG2:0] tag_new,
    output logic [NUM_REG_LOG2:0] tag_rs1,
    output logic [NUM_REG_LOG2:0] tag_rs2
);

logic [NUM_TAG_LOG2-1:0] register_alias_table [0:NUM_REG-1];

// 64-bit vector for free pool: 1 at index represent free register, 0 at index represents busy register
logic [NUM_TAG_LOG2-1:0] tag_counter; 
logic [NUM_P_REG-1:0] free_pool;                  

logic [NUM_REG_LOG2:0] first_free_tag; // rd pulls from MS asserted bit of free pool
logic [NUM_REG_LOG2:0] last_free_tag;
logic encoder_valid;

logic stall;
assign stall = ~encoder_valid | stall_in;

priority_encoder #(
    .WIDTH(NUM_P_REG),
    .TWO_SIDE(0)
) encoder (
    .in (free_pool),
    .out_MSB (first_free_tag),
    .out_LSB (last_free_tag),
    .valid (encoder_valid)
);

always_comb begin
    // assign new, old destination registers to go to ROB
    if (rd != 1'b0) begin
        tag_old = register_alias_table[rd];
        tag_new = first_free_tag;
    end else begin
        tag_old = 1'b0;
        tag_new = 1'b0;
    end

    // rename rs1
    prs1 = register_alias_table[rs1];
    prs2 = register_alias_table[rs2];
end

always @(posedge clk) begin
    if (rst) begin
        // initialize RAT and free pool
        int i;
        for (i = 0; i < NUM_REG; i = i+1) begin
            register_alias_table[i] <= NUM_REG_LOG2'(i);
        end
        for (i = 0; i < NUM_P_REG; i = i+1) begin
            free_pool[i] = (i < NUM_REG) ? 1'b0 : 1'b1;
        end
    end else if (~stall) begin
        // recover free register after commit
        if (commit_free) begin
            free_pool[tag_free] <= 1'b1;
        end

        // write to RAT
        if (rd != 'd0) begin
            register_alias_table[rd] <= first_free_tag;
            free_pool[first_free_tag] <= 1'b0;
        end
        
        // assert that x0 == p0
        register_alias_table[0] <= 1'b0;
    end
end

initial begin
    // initialize RAT and free pool
    int i;
    for (i = 0; i < NUM_REG; i = i+1) begin
        register_alias_table[i] = NUM_REG_LOG2'(i);
    end
    for (i = 0; i < NUM_P_REG; i = i+1) begin
        free_pool[i] = (i < NUM_REG) ? 1'b0 : 1'b1;
    end
end

endmodule
