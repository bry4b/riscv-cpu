module arch_reg_file #(
    parameter NUM_REG = 32,
    parameter NUM_REG_LOG2 = $clog2(NUM_REG),
    parameter REG_SIZE = 32
) (
    input clk, 
    input rst,

    input [NUM_REG_LOG2-1:0] rs1,
    input [NUM_REG_LOG2-1:0] rs2,
    
    input [NUM_REG_LOG2-1:0] retire_reg [0:1],
    input [REG_SIZE-1:0] retire_reg_data [0:1],
    input [1:0] retire_valid, 

    output logic [REG_SIZE-1:0] rs1_data,
    output logic [REG_SIZE-1:0] rs2_data

);

logic [REG_SIZE-1:0] arf [0:NUM_REG-1];

always_comb begin
    rs1_data = arf[rs1];
    rs2_data = arf[rs2];
end

always @(posedge clk) begin
    if (rst) begin
        for (int i = 0; i < NUM_REG; i = i + 1) begin
            arf[i] <= 32'b0;
        end    
    end else begin
        if (retire_valid[0] & (retire_reg[0] != 1'b0)) begin
            arf[retire_reg[0]] <= retire_reg_data[0];
        end
        if (retire_valid[1] & (retire_reg[1] != 1'b0)) begin
            arf[retire_reg[1]] <= retire_reg_data[1];
        end
    end
end

initial begin
    for (int i = 0; i < NUM_REG; i = i + 1) begin
        arf[i] = 32'b0;
    end
end

endmodule

