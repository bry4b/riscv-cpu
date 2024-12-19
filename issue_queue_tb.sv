`timescale 1ns/1ns

module issue_queue_tb (
    output logic clk,
    output logic rst
);

// `include "constants.sv"

// instruction fetch
logic [7:0] program_count;
logic [31:0] instruction;

// decode
logic [4:0] rd;
logic [4:0] rs1;
logic [4:0] rs2;
logic [31:0] imm;
logic [7:0] ctrls;
logic [3:0] alu_sel;
logic decode_valid;

// rename
logic [5:0] tag_rd;
logic [5:0] tag_rs1;
logic [5:0] tag_rs2;
logic rename_ready;

// regfile 
logic [31:0] rs1_data;
logic [31:0] rs2_data;

// currently unused ROB inputs
logic [5:0] rob_index [0:2];
logic [5:0] tag_rd_complete [0:2];
logic [31:0] rob_data_rd [0:2];
logic rob_complete [0:2];

logic [5:0] rob_tag_rs [0:1];
assign rob_tag_rs[1] = tag_rs2;
assign rob_tag_rs[0] = tag_rs1;

// ROB outputs
logic [31:0] rob_data_rs [0:1];
logic rob_contains_rs [0:1];
logic rob_ready_rs [0:1];
logic [4:0] rob_retire_reg;
logic [5:0] rob_retire_tag;
logic [31:0] rob_retire_reg_data;
logic rob_retire_valid;
logic [5:0] rob_tail;
logic rob_full;

// issue queue outputs
logic [3:0] iq_fu_op [0:2];
logic [31:0] iq_fu_rs1 [0:2];
logic [31:0] iq_fu_rs2 [0:2];
logic [5:0] iq_fu_tags [0:2];
logic [5:0] iq_fu_rob_index [0:2];
logic iq_fu_valid [0:2];
logic iq_stall;

// FU outputs
logic [31:0] cdb_data [0:2];
logic [5:0] cdb_tags [0:2];
logic [5:0] cdb_rob_index [0:2];
logic cdb_valid [0:2];

instr_fetch #(
    .SIZE(36),
    // .FILE(".\\demo.txt")
    .FILE("C:\\Users\\bryan\\Documents\\school\\ucla\\UCLA 24F\\eeM116C\\riscv-cpu\\demo.txt")
) IF ( 
    .clk(clk), 
    .addr(program_count), 
    .mem_data(instruction)
);

decode DE (
    .instr(instruction),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .ctrls(ctrls),
    .alu_sel(alu_sel),
    .valid(decode_valid)
);

rename RE (
    .clk(clk),
    .rst(rst),
    .stall_in(~decode_valid),

    .retire_tag(1'b0),      // not retiring right now
    .retire_valid(1'b0),    // not retiring right now

    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),

    // outputs
    .tag_rd(tag_rd),
    .tag_rs1(tag_rs1),
    .tag_rs2(tag_rs2),
    .rename_ready(rename_ready)
);

arch_reg_file ARF (
    .clk(clk),
    .rst(rst),
    
    .rs1(rs1),
    .rs2(rs2),

    .retire_reg(rob_retire_reg),
    .retire_reg_data(rob_retire_reg_data),
    .retire_valid(rob_retire_valid),
    
    .rs1_data(rs1_data),
    .rs2_data(rs2_data)
);

reorder_buffer ROB (
    .clk(clk),
    .rst(rst),
    .stall_in(1'b0),

    .pc(program_count),
    .arch_rd(rd),
    .tag_rd(tag_rd),
    .in_valid(rename_ready),

    .rob_index(rob_index),
    .tag_rd_complete(tag_rd_complete),
    .data_rd(rob_data_rd),
    .complete(rob_complete),
    
    .tag_rs(rob_tag_rs),
    
    // outputs
    .data_rs(rob_data_rs),
    .rob_contains_rs(rob_contains_rs),
    .ready_rs(rob_ready_rs),

    .retire_reg(rob_retire_reg),
    .retire_tag(rob_retire_tag),
    .retire_reg_data(rob_retire_reg_data),
    .retire_valid(rob_retire_valid),

    .rob_tail(rob_tail),
    .rob_full(rob_full)
);

issue_queue IQ (
    .clk(clk),
    .rst(rst),
    .stall_in(1'b0),

    // from ROB
    .rob_tail(rob_tail),
    .rob_data_rs(rob_data_rs),
    .rob_contains_rs(rob_contains_rs),
    .rob_ready_rs(rob_ready_rs),
    
    // from RENAME
    .op(alu_sel),
    .tag_rd(tag_rd),
    .tag_rs1(tag_rs1),
    .tag_rs2(tag_rs2),
    .imm(imm),
    .in_valid(rename_ready),

    // from ARF
    .data_rs1(rs1_data),
    .data_rs2(rs2_data),

    // from common data bus
    .cdb_tags(cdb_tags),
    .cdb_data(cdb_data),
    .cdb_valid(cdb_valid),
    
    // outputs to feed into the FUs
    .fu_op(iq_fu_op),
    .fu_rs1(iq_fu_rs1),
    .fu_rs2(iq_fu_rs2),
    .fu_tags(iq_fu_tags),
    .fu_rob_index(iq_fu_rob_index),
    .fu_valid(iq_fu_valid),

    .iq_stall(iq_stall)
);

genvar i;
generate
    for (i = 0; i < 3; i = i + 1) begin : genFUs
        functional_unit FU (
            .clk(clk),
            .rst(rst),

            .op(iq_fu_op[i]),
            .rs1(iq_fu_rs1[i]),
            .rs2(iq_fu_rs2[i]),
            .tags_in(iq_fu_tags[i]),
            .rob_index_in(iq_fu_rob_index[i]),
            .valid_in(iq_fu_valid[i]),

            // outputs
            .rd(cdb_data[i]),
            .tags_out(cdb_tags[i]),
            .rob_index_out(cdb_rob_index[i]),
            .valid_out(cdb_valid[i])
        );
    end
endgenerate

initial begin
    clk = 0;
    rst = 0;
    #10 rst = 1;
    #10 rst = 0;
    program_count = 8'd0;
    // #10 assert (instruction == 32'h00600113);
    // #20 assert (instruction == 32'h00f00193);
    #200 $stop;
end

always begin
    #5 clk = ~clk;
end

always @(posedge clk) begin
    if (rst) begin
        program_count <= 8'd0;
    end else begin
        program_count <= program_count + 3'd4;
    end
end

endmodule