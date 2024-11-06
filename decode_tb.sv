`timescale 1ns/10ps

module decode_tb (
    output logic [6:0] opcode_A,
    output logic [6:0] opcode_B
);

logic [31:0] instr_A;
logic [4:0] rd_A      [0:1];
logic [2:0] funct3_A  [0:1];
logic [4:0] rs1_A     [0:1];
logic [4:0] rs2_A     [0:1];
logic [6:0] funct7_A  [0:1];
logic [31:0] imm_A    [0:1];
logic [7:0] ctrls_A   [0:1];

logic [31:0] instr_B;
logic [4:0] rd_B      [0:1];
logic [2:0] funct3_B  [0:1];
logic [4:0] rs1_B     [0:1];
logic [4:0] rs2_B     [0:1];
logic [6:0] funct7_B  [0:1];
logic [31:0] imm_B    [0:1];
logic [7:0] ctrls_B   [0:1];

decode UUT (
    .instr_A(instr_A),
    .instr_B(instr_B),

    .opcode_A(opcode_A),
    .opcode_B(opcode_B),

    .rd_A(rd_A),
    .funct3_A(funct3_A),
    .rs1_A(rs1_A),
    .rs2_A(rs2_A),
    .funct7_A(funct7_A),
    .imm_A(imm_A),
    .ctrls_A(ctrls_A),
    .rd_B(rd_B),
    .funct3_B(funct3_B),
    .rs1_B(rs1_B),
    .rs2_B(rs2_B),
    .funct7_B(funct7_B),
    .imm_B(imm_B),
    .ctrls_B(ctrls_B)
);

initial begin
    instr_A = 32'b0;
    instr_B = 32'b0;
end

initial begin

end


endmodule