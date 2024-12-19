module functional_unit #(
    parameter REG_SIZE = 32,
    parameter NUM_TAGS = 64,
    parameter NUM_TAGS_LOG2 = $clog2(NUM_TAGS),
    parameter ROB_SIZE = 64,
    parameter ROB_SIZE_LOG2 = $clog2(ROB_SIZE)
) (
    input clk,
    input rst, 

    input [3:0] op,                             // operations
    input [REG_SIZE-1:0] rs1,                   // rs1
    input [REG_SIZE-1:0] rs2,                   // rs2 or immediate
    input [NUM_TAGS_LOG2-1:0] tags_in,         // rd tag
    input [ROB_SIZE_LOG2-1:0] rob_index_in,    // rob index
    input valid_in,

    output logic [REG_SIZE-1:0] rd,             // rd
    output logic [NUM_TAGS_LOG2-1:0] tags_out,  
    output logic [ROB_SIZE_LOG2-1:0] rob_index_out,
    output logic valid_out
    
);

logic [REG_SIZE-1:0] rd_d;

// 32-bit ALU
always_comb begin
    if (valid_in) begin
        case (op)
            4'b0000: begin // ADD
                rd = rs1 + rs2;
            end
            4'b0001: begin // SUBTRACT
                rd = rs1 - rs2;
            end
            4'b1000: begin // XOR
                rd = rs1 ^ rs2;
            end
            4'b1110: begin // AND
                rd = rs1 & rs2;
            end
            4'b0010: begin // SLL (shift left logical)
                rd = rs1 <<< rs2;
            end
            4'b1010: begin // SRL (shift right logical)
                rd = rs1 >>> rs2;
            end
            4'b1011: begin // SRA (shift right arithmetic)
                rd = rs1 >> rs2;
            end
            default: begin
                // do nothing
                rd = 32'b0;
            end
        endcase
    end else begin
        rd = 32'b0;
    end
end

assign tags_out = tags_in;
assign rob_index_out = rob_index_in;
assign valid_out = valid_in;

// always @(posedge clk) begin
//     if (rst) begin
//         rd <= 32'b0;
//         tags_out <= 1'b0;
//         rob_index_out <= 1'b0;
// 		valid_out <= 1'b0;
//     end else begin
//         rd <= rd_d;
//         tags_out <= tags_in;
//         rob_index_out <= rob_index_in;
// 		valid_out <= valid_in;
//     end
// end

endmodule