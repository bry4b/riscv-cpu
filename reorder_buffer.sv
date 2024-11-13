module reorder_buffer #(
    parameter ROB_SIZE = 16,
    parameter COMMIT_PORTS = 1
) (
    input clk,
    input rst,
    input stall_in,

    // new ROB entry
    input [7:0] pc,
    input [REG_SIZE:0] new_dest_reg,
    input [REG_SIZE:0] old_dest_reg,

    // change if an instruction has completed
    input index_in,
    input completed,
    
    // index keeps track of top-most instruction in ROB
    output logic [$clog2(ROB_SIZE)-1:0] index_out,
    output logic [REG_SIZE:0] new_dest_reg_out,
    output logic [REG_SIZE:0] old_dest_reg_out,
    
    // if completed out is 2, can retire top 2 instructions in ROB
    output logic [1:0] completed_out,
    output logic valid
);

`include "constants.sv"

/*
ROB layout:
bits [21] valid
bits [20:15] new desination register
bits [14:9] old destination register
bits [8:1] pc
bits [0] completed
*/
logic [21:0] rob [0:ROB_SIZE-1];

logic [$clog2(ROB_SIZE)-1:0] rob_head = 4'b0;
logic [$clog2(ROB_SIZE)-1:0] rob_tail = 4'b0;

logic stall;
assign stall = stall_in | (rob_tail == ROB_SIZE-1);

initial begin
    for (int i = 0; i < ROB_SIZE; i = i + 1) begin
        rob[i] = 22'b0;
    end
end

always_comb begin

end

always_ff @(posedge clk) begin
    if (~stall_in) begin
        rob[rob_tail][21] <= 1'b1;
        rob[rob_tail][20:15] <= new_dest_reg;
        rob[rob_tail][14:9] <= old_dest_reg;
        rob[rob_tail][8:1] <= pc;
        rob[rob_tail][0] <= 1'b0;

        rob_tail <= rob_tail + 1'b1;

        // push entries of ROB to beginning !
        if (rob_tail == ROB_SIZE-1) begin
            for (int i = 0; i < rob_tail - rob_head; i++) {
                rob[i] <= rob[rob_head+i];
                rob[rob_head+i] <= 22'b0;
            }
            rob_tail <= rob_tail - rob_head;
            rob_head <= 0;
        end
    end
    
    // complete
    if (completed) begin
        rob[index_in][0] = 1'b1; // set completed
       
        // change FUs
        
        // change ready table
        ready_table[rob[index_in][20:15]] = 1'b1;
        
        
    end
end

always_ff @(posedge clk) begin
    // retire
    if (rob_head < ROB_SIZE-1 && rob[rob_head][0] == 1'b1 && rob[rob_head+1][0] == 1'b1) begin
        // retire top two instructions
        index_out <= rob_head;
        new_dest_reg_out <= rob[rob_head]

    end else if (rob_head < ROB_SIZE && rob[rob_head][0] == 1'b1) begin
        // retire top instruction
        
    end
end

endmodule