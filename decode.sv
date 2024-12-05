module decode #(
    parameter INSTR_WIDTH = 32,
    parameter N_INSTR_PER_CYCLE = 1
) (
    input [INSTR_WIDTH-1:0] instr,

    output logic [4:0]  rd,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [31:0] imm,
    output logic [7:0]  ctrls,      // [7] regwrite, [6] alusrc, [5] memtoreg, [4] memre, [3] memwr, [2] byteword, [1:0] aluop
    output logic [3:0]  alu_sel,

    output logic valid
);

// `include "constants.sv"

logic [6:0] opcode;
logic [2:0] funct3;
logic [6:0] funct7;

assign opcode = instr[6:0];

decode_ALUOp #(.INSTR_WIDTH(INSTR_WIDTH)) d1 (
    .instr (instr),
    .aluop (ctrls[1:0]),
    .alu_sel (alu_sel)
);

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

            valid = 1'b1;
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

            valid = 1'b1;
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

            valid = 1'b1;
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

            valid = 1'b1;
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

            valid = 1'b1;
        end

        default: begin // invalid instruction
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

            valid = 1'b0;
        end 

    endcase
end

endmodule


module decode_ALUOp # (
    parameter INSTR_WIDTH = 32
) (
    input [INSTR_WIDTH-1:0] instr,
    input [1:0] aluop,

    output logic [3:0] alu_sel
);

always_comb begin
    case (aluop)
        2'b00: alu_sel = 4'b0000; // ADD
        2'b01: alu_sel = 4'b0001; // SUB
        default: begin
            case (instr[14:12])
                3'b000: begin
                    case (instr[30] & instr[5])
                        1'b0: alu_sel = 4'b0000; // ADD
                        1'b1: alu_sel = 4'b0001; // SUB
                    endcase
                end

                3'b100: begin
                    alu_sel = 4'b1000; // XOR
                end

                3'b110: begin
                    alu_sel = 4'b1100; // OR
                end

                3'b111: begin
                    alu_sel = 4'b1110; // AND
                end

                3'b001: begin
                    alu_sel = 4'b0010; // SLL
                end

                3'b101: begin
                    case (instr[30]) 
                        1'b0: alu_sel = 4'b1010; // SRL
                        1'b1: alu_sel = 4'b1011; // SRA
                    endcase
                end

                default: begin
                    alu_sel = 4'b0000; // ADD
                end

            endcase
        end

    endcase
end
endmodule

// ALU select signals taken from top 4 bits of ALU control signals found here: https://cepdnaclk.github.io/e16-co502-RV32IM-pipeline-implementation-group1/2-hardware_units/1-control_unit/1-control_signals.html