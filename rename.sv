module rename # (   // rename stage processing one instruction per cycle
    parameter NUM_REG = 32
) (
    input clk,
    input rst,
    input stall_in,

    input [NUM_REG_LOG2:0] prd_free,
    input commit_free, // assert HIGH when instruction is committed to free up prd_free in free pool

    input [NUM_REG_LOG2-1:0] rd_A,
    input [NUM_REG_LOG2-1:0] rs1_A,
    input [NUM_REG_LOG2-1:0] rs2_A,

    output logic [NUM_REG_LOG2:0] prd_A_old,
    output logic [NUM_REG_LOG2:0] prd_A_new,
    output logic [NUM_REG_LOG2:0] prs1_A,
    output logic [NUM_REG_LOG2:0] prs2_A
);

`include "constants.sv"

logic [5:0] register_alias_table [0:NUM_REG-1];

// 64-bit vector for free pool: 1 at index represent free register, 0 at index represents busy register
logic [NUM_P_REG-1:0] free_pool;                  

logic [NUM_REG_LOG2:0] first_free_prd; // rd_A pulls from MS asserted bit of free pool
logic encoder_valid;

logic stall;
assign stall = ~encoder_valid | stall_in;

priority_encoder #(
    .WIDTH(NUM_P_REG),
    .TWO_SIDE(0)
) encoder (
    .in (free_pool),
    .out_MSB (first_free_prd),
    .out_LSB (1'b0),
    .valid (encoder_valid)
);

always_comb begin
    // assign new, old destination registers to go to ROB
    if (rd_A != 'd0) begin
        prd_A_old = register_alias_table[rd_A];
        prd_A_new = first_free_prd;
    end else begin
        prd_A_old = 'd0;
        prd_A_new = 'd0;
    end

    // rename rs1
    prs1_A = register_alias_table[rs1_A];
    prs2_A = register_alias_table[rs2_A];
end

always_ff @(posedge clk) begin
    if (rst) begin
        // initialize RAT and free pool
        int i;
        for (i = 0; i < NUM_REG-1; i = i+1) begin
            register_alias_table[i] <= NUM_REG_LOG2'(i);
            free_pool[i] <= (i < NUM_REG) ? 1'b0 : 1'b1;
        end
    end else if (~stall) begin
        // recover free register after commit
        if (commit_free) begin
            free_pool[prd_free] <= 1'b1;
        end

        // write to RAT
        if (rd_A != 'd0) begin
            register_alias_table[rd_A] <= first_free_prd;
            free_pool[first_free_prd] <= 1'b0;
        end
        
        // assert that x0 == p0
        register_alias_table[0] <= NUM_REG_LOG2'('d0);
    end
end

endmodule
