module RISCV_top #(
    parameter ROM_ADDR_WIDTH = 8;
    parameter INSTR_WIDTH = 32
) (
    input clk,
    input rst, 
    input [INSTR_WIDTH-1:0] instr_A,
    input [INSTR_WIDTH-1:0] instr_B,

    output logic [ROM_ADDR_WIDTH-1:0] pc_A,
    output logic [ROM_ADDR_WIDTH-1:0] pc_B,
    output logic done
);

always_ff @(posedge clk) begin
    if (rst) begin
        pc_A <= 0;
        pc_B <= 0;
    end else begin
        // TODO: set done signal when reach instruction of all 0s
        pc_A <= pc_A + 4'd8;
        pc_B <= pc_B + 4'd8;
    end
end

// make pipeline buffer or smt





endmodule
