// ROB + register ready table
module reorder_buffer #(
    parameter NUM_REG = 32,
    parameter NUM_REG_LOG2 = $clog2(NUM_REG),
    parameter NUM_TAGS = 64,
    parameter NUM_TAGS_LOG2 = $clog2(NUM_TAGS),
    parameter REG_SIZE = 32,
    parameter ROB_SIZE = 64,
    parameter ROB_SIZE_LOG2 = $clog2(ROB_SIZE)
) (
    input clk,
    input rst,
    input stall_in,

    // new ROB entry
    input [7:0] pc,
    input [NUM_REG_LOG2-1:0] arch_rd,
    input [NUM_TAGS_LOG2-1:0] tag_rd,
    input in_valid,

    // if an instruction has completed, store destination register data
    // can issue up to 3 instructions at a time, so we need to be able to store 3 completed registers
    input [ROB_SIZE_LOG2-1:0] rob_index [0:2], 
    input [NUM_TAGS_LOG2-1:0] tag_rd_complete [0:2],
    input [REG_SIZE-1:0] data_rd [0:2],
    input complete [0:2],

    // load instruction completion -> store data from memory (thru LSU) in ROB 
    input [ROB_SIZE_LOG2-1:0] load_rob_index,
    input [REG_SIZE-1:0] load_data_rd,
    input load_complete,

    // check if source register is ready during dispatch
    input [NUM_TAGS_LOG2-1:0] tag_rs [0:1],

    // // load/store asks ROB for data from specific tag
    // input [NUM_TAGS_LOG2-1:0] loadstore_rs2_tag,
    // output logic loadstore_rs2_contains, // output if the ROB contains the data for the tag
    // output logic [REG_SIZE-1:0] loadstore_rs2_data, // output load/store data if in ROB

    // output source register if completed but not retired
    output logic [REG_SIZE-1:0] data_rs [0:1],
    output logic rob_contains_rs [0:1],

    // output ready table for source register
    output logic ready_rs [0:1],
    
    // retire instruction at rob_head if completed & update register file
    output logic [NUM_REG_LOG2-1:0] retire_reg [0:1],
    output logic [NUM_TAGS_LOG2-1:0] retire_tag [0:1],
    output logic [REG_SIZE-1:0] retire_reg_data [0:1],
    output logic [1:0] retire_valid, 

    output logic [ROB_SIZE_LOG2-1:0] rob_tail,
    output logic rob_full
);

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
always @(posedge clk) begin
    if (rst) begin
        rob_head <= 1'b0;
        rob_tail <= 1'b0;
        ready_table <= -64'd1;
        for (int i = 0; i < ROB_SIZE; i = i + 1) begin
            rob[i] <= 52'b0;
        end
    end else begin 
        rob_head <= rob_head_d;

        // push new entry to ROB
        if (~stall & in_valid) begin
            rob[rob_tail][0]        <= 1'b0;        // completed bit
            rob[rob_tail][8:1]      <= pc;          // PC
            rob[rob_tail][13:9]     <= arch_rd;     // destination architectural rd
            rob[rob_tail][19:14]    <= tag_rd;      // destination register tag
            rob[rob_tail][51:20]    <= 32'b0;       // data (nothing yet, updates when instruction completes)

            if (tag_rd != 1'b0) begin
                ready_table[tag_rd] <=1'b0;
            end

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

        if (load_complete) begin
            rob[load_rob_index][0] <= 1'b1;
            rob[load_rob_index][51:20] <= load_data_rd;
            ready_table[rob[load_rob_index][19:14]] <= 1'b1;
        end

        // clear ROB rows if they're retired
        if (retire_valid[0]) begin
            rob[rob_head] <= 1'b0;        
        end
        if (retire_valid[1]) begin
            rob[rob_head + 1'b1] <= 1'b0;
        end

        // TODO: change FU ready states
        // i think this should be done outside the ROB (the FUs themselves can output a bit to indicate if they are busy)
    end
end

// if rs1 or rs2 being dispatched is ready, look in ROB for value, and set valid bit
// reservation station: if valid bit, overwrite ARF value with ROB value
// TODO: REFACTOR THIS SHIT BECAUSE THE DATAPATH IS UGLY AS FUCK or just dont care about it haha im lazy
always_comb begin
    for (int i = 0; i < 2; i = i + 1) begin
        breakout[i] = 1'b0;
        if (ready_table[tag_rs[i]]) begin
            for (int j = 0; j < ROB_SIZE; j = j + 1) begin
                if (~breakout[i] && rob[j][19:14] == tag_rs[i]) begin
                    data_rs[i] = rob[j][51:20];
                    rob_contains_rs[i] = 1'b1;
                    breakout[i] = 1'b1;
                end else begin
                    data_rs[i] = 32'b0;
                    rob_contains_rs[i] = 1'b0;
                    breakout[i] = 1'b0;
                end
            end
        end else begin
            data_rs[i] = 32'b0;
            rob_contains_rs[i] = 1'b0;
        end
    end
end

// output ready table
always_comb begin
    for (int i = 0; i < 2; i = i + 1) begin
        ready_rs[i] = ready_table[tag_rs[i]];
    end
end

// retire head instruction when it has been completed
always_comb begin
    retire_reg[0] = rob[rob_head][13:9];
    retire_tag[0] = rob[rob_head][19:14];
    retire_reg_data[0] = rob[rob_head][51:20];

    retire_reg[1] = rob[rob_head+1'b1][13:9];
    retire_tag[1] = rob[rob_head+1'b1][19:14];
    retire_reg_data[1] = rob[rob_head+1'b1][51:20];
    
    if (rob[rob_head][0] == 1'b1) begin             // retire data from instruction at head of ROB
        retire_valid[0] = 1'b1;
        if (rob[rob_head+1'b1][0] == 1'b1) begin    // retire data from instruction at head+1 of ROB
            retire_valid[1] = 1'b1;
            rob_head_d = rob_head + 2'd2;        
        end else begin    
            retire_valid[1] = 1'b0;                  // only the head of ROB is retire-able
            rob_head_d = rob_head + 1'b1;
        end
    
    end else begin                                  // no instructions to retire
        retire_valid = 2'b0;
        rob_head_d = rob_head;
    end
end

initial begin
    rob_head <= 1'b0;
    rob_tail <= 1'b0;
    ready_table <= -64'd1;
    for (int i = 0; i < ROB_SIZE; i = i + 1) begin
        rob[i] = 52'b0;
    end
end

endmodule