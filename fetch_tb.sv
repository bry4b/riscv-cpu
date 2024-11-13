module fetch_tb (
    output logic clk
);

logic [7:0] program_count;
logic [31:0] instruction;

instr_fetch #(
    .FILE("F:\\bryan\\Documents\\school yuck\\ucla\\UCLA 24F\\eeM116C\\189 project\\riscv-cpu\\r-test-hex.txt")
)IMEM ( 
    .clk(clk), 
    .addr(program_count), 
    .mem_data(instruction)
);

initial begin
    clk = 1'b0;
    program_count = 8'd0;
    #20 assert (instruction == 32'h00600113);
	 
	#20 program_count = 8'h4;
    #20 assert (instruction == 32'h00f00193);
    #100 
	$stop;
end

always begin
    #10 clk = ~clk;
end

endmodule