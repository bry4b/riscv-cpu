// ROB + register ready table
module reorder_buffer #(
    parameter ROB_SIZE = 64,
    parameter RETIRE_PORTS = 1
) (
    input clk,
    input rst,
    input stall_in,

    // new ROB entry
    input [7:0] pc,
    input [NUM_REG_LOG2-1:0] arch_rd,
    input [NUM_TAGS_LOG2-1:0] tag_rd,
    input in_valid,

    // store destination register data if an instruction has completed
    // can issue up to 3 instructions at a time, so we need to be able to store 3 completed registers
    input [ROB_SIZE_LOG2-1:0] rob_index [0:2], 
    input [NUM_TAGS_LOG2-1:0] tag_rd_complete [0:2],
    input [REG_SIZE-1:0] data_rd [0:2],
    input complete [0:2],

    // check if source register is ready during dispatch
    input [NUM_TAGS_LOG2-1:0] tag_rs [0:1],

    // output source register if ready
    output logic [REG_SIZE-1:0] data_rs [0:1],
    output logic ready_rs [0:1],
    
    // retire instruction at rob_head if completed & update register file
    output logic [NUM_REG_LOG2-1:0] retire_reg,
    output logic [NUM_TAGS_LOG2-1:0] retire_tag,
    output logic [REG_SIZE-1:0] retire_reg_data,
    output logic retire_valid, 

    output logic [ROB_SIZE_LOG2-1:0] rob_tail,
    output logic rob_full
);

`include "constants.sv"

localparam ROB_SIZE_LOG2 = $clog2(ROB_SIZE);

/*  
    reorder buffer layout:
    [0]     completed
    [8:1]   pc
    [13:9]  destination architectural register (5bit)
    [19:14] destination register tag (6bit)
    [51:20] destination register data (32bit)
*/
logic [51:0] rob [0:ROB_SIZE-1];

logic [63:0] ready_table;

logic [ROB_SIZE_LOG2-1:0] rob_head;     // pointer to head of circular buffer 
logic [ROB_SIZE_LOG2-1:0] rob_head_d;   // next pointer to head of circular buffer 

logic stall;
assign rob_full = (rob_head == rob_tail + 1'b1);
assign stall = stall_in | rob_full;     // stall if ROB is full

logic breakout [0:1];                   // control break of source register output 

// write to ROB
always_ff @(posedge clk) begin
    if (rst) begin
        rob_head <= 1'b0;
        rob_tail <= 1'b0;
        ready_table <= 64'b0;
        for (int i = 0; i < ROB_SIZE; i = i + 1) begin
            rob[i] = 52'b0;
        end
    end else begin 
        rob_head <= rob_head_d;

        if (~stall & in_valid) begin
            // push new entry to ROB
            rob[rob_tail][0]        <= 1'b0;        // completed bit
            rob[rob_tail][8:1]      <= pc;          // PC
            rob[rob_tail][13:9]     <= arch_rd;     // destination architectural rd
            rob[rob_tail][19:14]    <= tag_rd;      // destination register tag
            rob[rob_tail][51:20]    <= 32'b0;       // data (nothing yet, updates when instruction completes)

            ready_table[tag_rd]     <= 1'b0;
            rob_tail <= rob_tail + 1'b1;
        end
    
        // complete, update register value in ROB
        for (int i = 0; i < 3; i = i + 1) begin
            if (complete[i]) begin
                rob[rob_index[i]][0] <= 1'b1;           // set completed
                rob[rob_index[i]][51:20] <= data_rd[i]; // store register data
                ready_table[tag_rd_complete[i]] <= 1'b1;
            end
        end
        
        // TODO: change FU ready states
        // i think this should be done outside the ROB (the FUs themselves can output a bit to indicate if they are busy)
    end
end

// if rs1 or rs2 being dispatched is ready, look in ROB for value, and set valid bit
// reservation station: if valid bit, overwrite ARF value with ROB value
always_comb begin
    for (int i = 0; i < 2; i = i + 1) begin
        breakout[i] = 1'b0;
        if (ready_table[tag_rs[i]]) begin
            for (int j = 0; j < ROB_SIZE; j = j + 1) begin
                if (~breakout[i] && rob[j][19:14] == tag_rs[i]) begin
                    data_rs[i] = rob[j][51:20];
                    ready_rs[i] = 1'b1;
                    breakout[i] = 1'b1;
                end
            end
        end
    end
end

// TODO: retire when rob_head is completed
// possibly done?
always_comb begin
    retire_reg = rob[rob_head][20:15];
    retire_tag = rob[rob_head][19:14];
    retire_reg_data = rob[rob_head][57:26];
    if (rob[rob_head][0] == 1'b1) begin
        // retire data from instruction at head of ROB
        retire_valid = 1'b1;
        rob_head_d = rob_head + 1'b1;
    end else begin
        // no instruction to retire
        retire_valid = 1'b0;
        rob_head_d = rob_head;
    end
end

initial begin
    rob_head <= 1'b0;
    rob_tail <= 1'b0;
    ready_table <= 64'b0;
    for (int i = 0; i < ROB_SIZE; i = i + 1) begin
        rob[i] = 52'b0;
    end
end

endmodule