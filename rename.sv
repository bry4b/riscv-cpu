// TODO: reimplement RAT to read from free pool bitvector using two sided priority decoder: instrA -> LSB, instrB -> MSB
// TODO: place preg back into free pool (create busy table and OR busy register after complete?)

module rename # (
    parameter NUM_REG = 32
) (
    input clk,
    input rst,

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

// logic [5:0] free_pool [0:NUM_REG-1];                       // functions as a queue to refill 
// foreach (free_pool[i]) free_pool[i] = init_free(i);

// 64-bit vector for free pool: 1 at index represent free register, 0 at index represents busy register
logic [NUM_ENTRIES-1:0] free_pool;                  

// todo: implement this later please !
// logic [5:0] next_free_preg = free_pool[0];

always_ff @(posedge clk) begin
    if (rst) begin
        int i;
        for (i = 0; i < NUM_REG-1; i = i+1) begin
            register_alias_table[i] <= REG_SIZE'(i);
            free_pool[i] <= NUM_REG + REG_SIZE'(i);
        end
    end else begin

        // write to alias table
        if (rd_A != 'd0 && rd_B != 'd0) begin
            // both rd_A and rd_B need to pull from free pool
            prd_A_new <= free_pool[0];
            prd_A_old <= register_alias_table[rd_A];
            register_alias_table[rd_A] <= free_pool[0];

            prd_B_new <= free_pool[1];
            prd_B_old <= register_alias_table[rd_B];
            register_alias_table[rd_B] <= free_pool[1];
            
            free_pool[0:NUM_REG-3] <= free_pool[2:NUM_REG-1];
            free_pool[NUM_REG-2] <= REG_SIZE'('b0);
            free_pool[NUM_REG-1] <= REG_SIZE'('b0);
            
        end else if (rd_A != 'd0) begin
            // only rd_A needs to pull from free pool
            prd_A_new <= free_pool[0];
            prd_A_old <= register_alias_table[rd_A];
            register_alias_table[rd_A] <= free_pool[0];

            prd_B_new <= REG_SIZE'('d0); // do nothing
            prd_B_old <= REG_SIZE'('d0); // do nothing

            free_pool[0:NUM_REG-2] <= free_pool[1:NUM_REG-1];
            free_pool[NUM_REG-1] <= REG_SIZE'('b0);
				
        end else if (rd_B != 'd0) begin
            // only rd_B needs to pull from free pool
            prd_B_new <= free_pool[0];
            prd_B_old <= register_alias_table[rd_B];
            register_alias_table[rd_B] <= free_pool[0];

            prd_A_new <= REG_SIZE'('d0); // do nothing
            prd_A_old <= REG_SIZE'('d0); // do nothing

            free_pool[0:NUM_REG-2] <= free_pool[1:NUM_REG-1];
            free_pool[NUM_REG-1] <= REG_SIZE'('b0);
            
        end else begin
            // neither instruction pulls from free pool                             
            prd_A_new <= REG_SIZE'('d0); // do nothing
            prd_A_old <= REG_SIZE'('d0); // do nothing
            prd_B_new <= REG_SIZE'('d0); // do nothing
            prd_B_old <= REG_SIZE'('d0); // do nothing
            
        end
        
        // rename rs1, rs2
        prs1_A <= register_alias_table[rs1_A];
        prs2_A <= register_alias_table[rs2_A];

        prs1_B <= register_alias_table[rs1_B];
        prs2_B <= register_alias_table[rs2_B];

        register_alias_table[0] <= REG_SIZE'('d0);
    end
end

endmodule


module priority_encoder_MSB_4b (
    input [3:0] in,                 // 4b input 
    output [1:0] out,               // 2b output: index of MS asserted bit
    output valid                    // HIGH if asserted bit found
);

always_comb begin
    if (in[3]) out = 2'b11;
    else if (in[2]) out = 2'b10;
    else if (in[1]) out = 2'b01;
    else out = 2'b00;
    valid = in != 4'b0;    
end

endmodule

module priority_encoder_MSB #(
    parameter WIDTH = 64
) (
    input [WIDTH-1:0] in,
    output [$clog2(WIDTH)-1:0] out,
    output valid
);

localparam NUM_BLOCKS = (WIDTH + 3) >> 2; // 16 blocks
logic [NUM_BLOCKS-1:0] valid_blocks;
logic [1:0] block_outs [NUM_BLOCKS-1:0];

// generate 4b priority encoders: index 0 is LSB
genvar i;
generate 
    for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : gen_blocks
        priority_encoder_MSB_4b encoder_block (
            .in (in[(i<<2)+3:(i<<2)]),
            .out (block_outs[i]),
            .valid (valid_blocks(i))
        );
    end
endgenerate

always_comb begin
    out = 'b0;
    valid = 1'b0;
    integer j;
    for (j = NUM_BLOCKS-1; j >= 0; j = j - 1) begin
        if (valid_blocks[j]) begin
            out = {j, block_outs[j]};
            valid = 1'b1;
            break;
        end
    end
end

endmodule

module priority_encoder_LSB_4b (
    input [3:0] in,
    output [1:0] out,
    output out_valid
);

always_comb begin
    if (in[0]) out = 2'b00;
    else if (in[1]) out = 2'b01;
    else if (in[2]) out = 2'b10;
    else out = 2'b11;
    out_valid = in != 4'b0;
end

endmodule