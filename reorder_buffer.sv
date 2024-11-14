module reorder_buffer #(
    parameter ROB_SIZE = 16,
    parameter COMMIT_PORTS = 1
) (
    input clk,
    input rst,
    input stall_in,

    // new ROB entry
    input [7:0] pc,
    input [NUM_REG_LOG2:0] old_p_reg,
    input [NUM_REG_LOG2:0] new_p_reg,
    input [NUM_REG_LOG2-1:0] arch_reg,
    input in_valid,

    // store destination register data if an instruction has completed
    input [ROB_SIZE_LOG2-1:0] index_A,
    input [ROB_SIZE_LOG2-1:0] index_B,
    input [REG_SIZE-1:0] complete_A_data,
    input [REG_SIZE-1:0] complete_B_data,
    input [1:0] complete,
    
    // commit instruction at rob_head if completed & update register file
    // commit 1 or 2 instructions per cycle? 
    output logic [NUM_REG_LOG2:0] commit_reg_A,
    output logic [NUM_REG_LOG2:0] commit_reg_B,
    output logic [REG_SIZE-1:0] commit_reg_A_data,
    output logic [REG_SIZE-1:0] commit_reg_B_data,
    output logic [1:0] commit_valid, 

    output logic [ROB_SIZE_LOG2-1:0] rob_tail,
    output logic rob_full
);

`include "constants.sv"

localparam ROB_SIZE_LOG2 = $clog2(ROB_SIZE);

/*  
    reorder buffer layout:
    [57:26] destination register data
    [25:21] destination architectural register
    [20:15] new destination physical register
    [14:9]  old destination physical register
    [8:1]   pc
    [0]     completed                               
*/
logic [57:0] rob [0:ROB_SIZE-1];

logic [ROB_SIZE_LOG2-1:0] rob_head; // pointer to head of circular buffer
logic [ROB_SIZE_LOG2-1:0] rob_head_d; // pointer to head of circular buffer

logic stall;
assign rob_full = (rob_head == rob_tail + 1'b1);
assign stall = stall_in | rob_full; // stall if ROB is full

initial begin
    for (int i = 0; i < ROB_SIZE; i = i + 1) begin
        rob[i] = 1'b0;
    end
end

always_ff @(posedge clk) begin
    if (rst) begin
        rob_head <= 1'b0;
        rob_tail <= 1'b0;
        for (int i = 0; i < ROB_SIZE; i = i + 1) begin
            rob[i] = 1'b0;
        end
    end else begin
        rob_head <= rob_head_d;

        if (~stall & in_valid) begin
            // push new entry to ROB
            rob[rob_tail][0]        <= 1'b0;
            rob[rob_tail][8:1]      <= pc;
            rob[rob_tail][14:9]     <= old_p_reg;
            rob[rob_tail][20:15]    <= new_p_reg;
            rob[rob_tail][25:21]    <= arch_reg;
            rob[rob_tail][57:26]    <= 1'b0;

            rob_tail <= rob_tail + 1'b1;

            // we might not need this if we keep ROB as circular buffer
            // // push entries of ROB to beginning !
            // if (rob_tail == ROB_SIZE-1) begin
            //     for (int i = 0; i < rob_tail - rob_head; i++) {
            //         rob[i] <= rob[rob_head+i];
            //         rob[rob_head+i] <= 22'b0;
            //     }
            //     rob_tail <= rob_tail - rob_head;
            //     rob_head <= 0;
            // end
        end
    
        // complete
        if (completed[0]) begin
            rob[index_A][0] <= 1'b1; // set completed
            rob[index_A][57:26] <= complete_A_data; // store register data
        
            // change FUs
            // i think this should be done outside the ROB (the FUs themselves can output a bit to indicate if they are busy)
            
            // change ready table
            // i think this could be tracked in the issue queue 
            // ready_table[rob[index_A][20:15]] <= 1'b1;
        end
        if (completed[1]) begin
            rob[index_B][0] <= 1'b1; // set completed
            rob[index_B][57:26] <= complete_B_data; // store register data
        end
    end
end

// commit when rob_head is completed (up to two instructions at a time)
always_comb begin
    if (rob[rob_head][0] == 1'b1 && rob[rob_head+1'b1][0] == 1'b1) begin
        // commit data from instruction at head of ROB
        commit_reg_A = rob[rob_head][20:15];
        commit_reg_B = rob[rob_head+1'b1][20:15];
        commit_reg_A_data = rob[rob_head][57:26];
        commit_reg_B_data = rob[rob_head+1'b1][57:26];
        commit_valid = 2'b10;
        rob_head_d = rob_head + 2'd2;
    end else if (rob[rob_head][0] == 1'b1) begin
        commit_reg_A = rob[rob_head][20:15];
        commit_reg_B = 1'b0;
        commit_reg_A_data = rob[rob_head][57:26];
        commit_reg_B_data = 1'b0;
        commit_valid = 2'b01;
        rob_head_d = rob_head + 1'd1;
    end else begin
        commit_reg_A = 1'b0;
        commit_reg_B = 1'b0;
        commit_reg_A_data = 1'b0;
        commit_reg_B_data = 1'b0;
        commit_valid = 2'b00;
        rob_head_d = rob_head;
    end

end

endmodule