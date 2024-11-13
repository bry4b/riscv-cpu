`timescale 1ns/1ns

module decode_tb (
    output logic clk
);

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

instr_fetch #(
    .SIZE(48),
    .FILE("F:\\bryan\\Documents\\school yuck\\ucla\\UCLA 24F\\eeM116C\\189 project\\riscv-cpu\\r-test-hex.txt")
)IMEM ( 
    .clk(clk), 
    .addr(program_count), 
    .mem_data(instruction)
);

decode UUT (
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

initial begin
    clk = 0;
    program_count = 8'd0;
    #10;
    assert (instruction == 32'h00600113);
    

    #20 program_count = 8'h4;
    #20 assert (instruction == 32'h00f00193);

    #100 
	$stop;
end

always begin
    #10 clk = ~clk;
end


endmodule