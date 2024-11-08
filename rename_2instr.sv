// TODO: place preg back into free pool (create busy table and OR busy register after complete?)

module rename # (
    parameter NUM_REG = 32
) (
    input clk,
    input rst,

    input [REG_SIZE-1:0] rd_A_free,
    input [REG_SIZE-1:0] rd_B_free,
    input commit_free_A,
    input commit_free_B,

    input [REG_SIZE-1:0] rd_A,
    input [REG_SIZE-1:0] rs1_A,
    input [REG_SIZE-1:0] rs2_A,
    input [REG_SIZE-1:0] rd_B,
    input [REG_SIZE-1:0] rs1_B,
    input [REG_SIZE-1:0] rs2_B,

    output logic [REG_SIZE:0] prd_A_old,
    output logic [REG_SIZE:0] prd_A_new,
    output logic [REG_SIZE:0] prs1_A,
    output logic [REG_SIZE:0] prs2_A,
    output logic [REG_SIZE:0] prd_B_old,
    output logic [REG_SIZE:0] prd_B_new,
    output logic [REG_SIZE:0] prs1_B,
    output logic [REG_SIZE:0] prs2_B
);

`include "constants.sv"

localparam NUM_ENTRIES = 2*NUM_REG;
localparam REG_SIZE = $clog2(NUM_REG);

// logic [5:0] register_alias_table [0:NUM_REG-1] = '{foreach (register_alias_table[i]) init_RAT(i)};  // index corresponds to a-reg, 6-bit value corresponds to p-reg
logic [5:0] register_alias_table [0:NUM_REG-1];

// 64-bit vector for free pool: 1 at index represent free register, 0 at index represents busy register
logic [NUM_ENTRIES-1:0] free_pool;                  

logic [REG_SIZE:0] first_free_prd;     // rd_A pulls from MS asserted bit of free pool
logic [REG_SIZE:0] last_free_prd;      // rd_B pulls from LS asserted bit of free pool
logic encoder_valid;

priority_encoder #(
    .WIDTH(NUM_ENTRIES),
    .TWO_SIDE(1)
) encoder (
    .in (free_pool),
    .out_MSB (first_free_prd),
    .out_LSB (last_free_prd),
    .valid (encoder_valid)
);

// todo: implement this later please !
// logic [5:0] next_free_preg = free_pool[0];

always_comb begin
    if (rd_A != 'd0) begin
        prd_A_old = register_alias_table[rd_A];
        prd_A_new = first_free_prd;
    end else begin
        prd_A_old = 'd0;
        prd_A_new = 'd0;
    end
    if (rd_B != 'd0) begin
        prd_B_old = register_alias_table[rd_B];
        prd_B_new = last_free_prd;
    end else begin
        prd_B_old = 'd0;
        prd_B_new = 'd0;
    end

    // rename rs1, rs2
    prs1_A = register_alias_table[rs1_A];
    prs2_A = register_alias_table[rs2_A];

    prs1_B = register_alias_table[rs1_B];
    prs2_B = register_alias_table[rs2_B];
end

always_ff @(posedge clk) begin
    if (rst) begin
        int i;
        for (i = 0; i < NUM_REG-1; i = i+1) begin
            register_alias_table[i] <= REG_SIZE'(i);
            free_pool[i] <= (i < NUM_REG) ? 0 : 1;
        end
    end else begin
        if (free_valid) begin
            free_pool[rd_A_free] <= 1'b1;
            free_pool[rd_B_free] <= 1'b1;
        end

        // write to alias table
        if (rd_A != 'd0) begin
            register_alias_table[rd_A] <= first_free_prd;
            free_pool[first_free_prd] <= 1'b0;
        end
        if (rd_B != 'd0) begin
            register_alias_table[rd_B] <= last_free_prd;
            free_pool[last_free_prd] <= 1'b0;
        end
        
        register_alias_table[0] <= REG_SIZE'('d0);
    end
end

endmodule
