module decode #(
    parameter INSTR_WIDTH = 32,
    parameter N_INSTR_PER_CYCLE = 1
) (
    input [INSTR_WIDTH-1:0] instr,

    output logic [6:0]  opcode,
    output logic [4:0]  rd,
    output logic [2:0]  funct3,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [6:0]  funct7,
    output logic [31:0] imm,
    output logic [7:0]  ctrls
);

`include "constants.sv"

decode_single #(.INSTR_WIDTH(INSTR_WIDTH)) d0 (
    .instr (instr),
    .opcode (opcode),
    .rd (rd),
    .funct3 (funct3),
    .rs1 (rs1),
    .rs2 (rs2),
    .funct7 (funct7),
    .imm (imm),
    .ctrls (ctrls)
);

endmodule


module decode_single #(
    parameter INSTR_WIDTH = 32
) (
    input [INSTR_WIDTH-1:0] instr,
    
    output logic [6:0] opcode,
    output logic [4:0] rd,
    output logic [2:0] funct3,
    output logic [4:0] rs1,
    output logic [4:0] rs2,
    output logic [6:0] funct7,
    output logic [31:0] imm,
    output logic [7:0] ctrls
);

assign opcode = instr[6:0];

always_comb begin
    case(opcode)
        7'b0110011: begin // R-type (ADD, XOR)
            rd      = instr[11:7];
            funct3  = instr[14:12];
            rs1     = instr[19:15];
            rs2     = instr[24:20];
            funct7  = instr[31:25];
            imm     = 'd0;  // no immediate, set to 0

            ctrls[7]    = 1'b1; // REGWRITE
            ctrls[6]    = 1'b0; // ALUSRC
            ctrls[5]    = 1'b0; // MEMTOREG
            ctrls[4]    = 1'b0; // MEMRE
            ctrls[3]    = 1'b0; // MEMWR
            ctrls[2]    = 1'b0; // BYTEORWORD
            ctrls[1:0]  = 2'b10; // R-type ALUOP
        end

        7'b0000011: begin // Load (LW, LB)
            rd      = instr[11:7];
            funct3  = instr[14:12];
            rs1     = instr[19:15];
            rs2     = 'd0; // no rs2
            funct7  = 'd0; // no funct7
            imm     = {instr[31:20], 20'b0} >>> 20; // arithmetic right shift to sign extend

            ctrls[7]    = 1'b1;
            ctrls[6]    = 1'b1;
            ctrls[5]    = 1'b1;
            ctrls[4]    = 1'b1;
            ctrls[3]    = 1'b0;
            ctrls[2]    = (funct3 == 3'b000) ? 1'b0 : 1'b1;
            ctrls[1:0]  = 2'b00; // ADD ALUOP
        end
        
        7'b0010011: begin // I-type (ADDI, ORI, SRAI)
            rd      = instr[11:7];
            funct3  = instr[14:12];
            rs1     = instr[19:15];
            rs2     = 'd0; // no rs2
            funct7  = 'd0; // no funct7
            imm     = {instr[31:20], 20'b0} >>> 20;

            ctrls[7]    = 1'b1;
            ctrls[6]    = 1'b1;
            ctrls[5]    = 1'b0;
            ctrls[4]    = 1'b0;
            ctrls[3]    = 1'b0;
            ctrls[2]    = 1'b1; // WORD
            ctrls[1:0]  = 2'b10;
        end

        7'b0100011: begin // Store
            rd      = 5'd0;
            funct3  = instr[14:12];
            rs1     = instr[19:15];
            rs2     = instr[24:20];
            funct7  = 'd0; // no funct7
            imm     = {instr[31:25], instr[11:7], 20'b0} >>> 20; 
            
            ctrls[7]    = 1'b0;
            ctrls[6]    = 1'b1;
            ctrls[5]    = 1'b0;
            ctrls[4]    = 1'b0;
            ctrls[3]    = 1'b1;
            ctrls[2]    = (funct3 == 3'b000) ? 1'b0 : 1'b1;
            ctrls[1:0]  = 2'b10;
        end

        7'b0110111: begin // LUI
            rd      = instr[11:7];
            funct3  = instr[14:12];
            rs1     = 'd0; // no rs1
            rs2     = 'd0; // no rs2
            funct7  = 'd0; // no funct7
            imm     = {instr[31:12], 12'b0}; 

            ctrls[7]    = 1'b1;
            ctrls[6]    = 1'b1;
            ctrls[5]    = 1'b0;
            ctrls[4]    = 1'b0;
            ctrls[3]    = 1'b0;
            ctrls[2]    = 1'b1; // WORD
            ctrls[1:0]  = 2'b00; // force ADD with x0
        end

        default: begin
            rd      = 'd0;
            funct3  = 'd0;
            rs1     = 'd0; 
            rs2     = 'd0;
            funct7  = 'd0;
            imm     = 'd0;

            ctrls[7]    = 1'b0;
            ctrls[6]    = 1'b0;
            ctrls[5]    = 1'b0;
            ctrls[4]    = 1'b0;
            ctrls[3]    = 1'b0;
            ctrls[2]    = 1'b0;
            ctrls[1:0]  = 2'b00;
        end 

    endcase
    
end


endmodule