`timescale 1ns/1ns

module pipeline_tb (
    output logic clk,
    output logic rst
);

`include "constants.sv"

logic [7:0] program_count;
logic [31:0] instruction;

logic [6:0] opcode;
logic [4:0] rd;
logic [2:0] funct3;
logic [4:0] rs1;
logic [4:0] rs2;
logic [6:0] funct7;
logic [31:0] imm;
logic [7:0] ctrls;

logic [5:0] tag_old;
logic [5:0] tag_new;
logic [5:0] tag_rs1;
logic [5:0] tag_rs2;


instr_fetch #(
    .SIZE(48),
    .FILE("F:\\bryan\\Documents\\school yuck\\ucla\\UCLA 24F\\eeM116C\\189 project\\riscv-cpu\\r-test-hex.txt")
)IMEM ( 
    .clk(clk), 
    .addr(program_count), 
    .mem_data(instruction)
);

decode DECODE (
    .instr(instruction),
    .opcode(opcode),
    .rd(rd),
    .funct3(funct3),
    .rs1(rs1),
    .rs2(rs2),
    .funct7(funct7),
    .imm(imm),
    .ctrls(ctrls)
);

rename UUT (
    .clk(clk),
    .rst(rst),
    .stall_in(1'b0),
    .prd_free(1'b0),
    .commit_free(1'b0),

    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),

    .tag_old(prd_old),
    .tag_new(prd_new),
    .tag_rs1(prs1),
    .tag_rs2(prs2)
);

initial begin
    clk = 0;
    rst = 1;
    #10 rst = 0;
    program_count = 8'd0;
    #10 assert (instruction == 32'h00600113);
    
    #20 assert (instruction == 32'h00f00193);

    #100 $stop;
end

always begin
    #10 clk = ~clk;
end

always @(posedge clk) begin
    if (rst) begin
        program_count <= 8'd0;
    end else begin
        program_count <= program_count + 3'd4;
    end
end

endmodule