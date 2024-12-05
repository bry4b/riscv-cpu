/*
IF module should use the program counter to read one instruction per cycle from the one-port instruction ROM (READ-ONLY MEMORY) sequentially. 
If there are no more instructions left, you should have some sort of signal or logic to stop fetching instructions.
*/

module instr_fetch # (
    parameter SIZE = 48,
    parameter FILE
) (
    input clk,
    input [7:0] addr,

    output logic [31:0] mem_data,
    output logic stop
);

logic [7:0] mem [0:SIZE-1];

initial begin
    $display("Initializing Instruction Memory");
    for (int i = 0; i < SIZE; i++) begin
        mem[i] = 8'b0;
    end
    $readmemh (FILE, mem);
end

always_ff @(posedge clk) begin
    mem_data <= {mem[addr], mem[addr+1], mem[addr+2], mem[addr+3]};
    if (mem_data == 32'h0) begin
        stop <= 1'b1;
    end else begin
        stop <= 1'b0;
    end
end

endmodule


