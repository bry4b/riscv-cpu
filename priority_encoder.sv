module priority_encoder #(
    parameter WIDTH = 64,
    parameter TWO_SIDE = 0
) (
    input [WIDTH-1:0] in,

    output logic [$clog2(WIDTH)-1:0] out_MSB,
    output logic [$clog2(WIDTH)-1:0] out_LSB,
    output logic valid
);

logic valid_MSB, valid_LSB;

localparam NUM_BLOCKS = (WIDTH + 3) >> 2; // 16 blocks
logic [NUM_BLOCKS-1:0] valid_blocks_MSB;
logic [1:0] block_outs_MSB [NUM_BLOCKS-1:0];
logic [NUM_BLOCKS-1:0] valid_blocks_LSB;
logic [1:0] block_outs_LSB [NUM_BLOCKS-1:0];

// generate 4b priority encoders: index 0 is LSB
genvar i;
generate 
    for (i = 0; i < NUM_BLOCKS; i = i + 1) begin : gen_blocks
        priority_encoder_MSB_4b encoder_block_MSB (
            .in (in[(i<<2)+3:(i<<2)]),
            .out (block_outs_MSB[i]),
            .valid (valid_blocks_MSB[i])
        );

        if (TWO_SIDE) begin
            priority_encoder_LSB_4b encoder_block_LSB (
                .in (in[(i<<2)+3:(i<<2)]),
                .out (block_outs_LSB[i]),
                .valid (valid_blocks_LSB[i])        
            );
        end
    end
endgenerate

logic breakout_A, breakout_B;
always_comb begin
    out_MSB = 1'b0;
    valid_MSB = 1'b0;
    breakout_A = 1'b0;
    for (int j = NUM_BLOCKS-1; j >= 0; j = j - 1) begin
        if (~breakout_A) begin
            if (valid_blocks_MSB[j]) begin
                out_MSB = {j[3:0], block_outs_MSB[j]};
                valid_MSB = 1'b1;
                breakout_A = 1'b1;
            end
        end
    end
end
always_comb begin
    if (TWO_SIDE) begin
        out_LSB = 1'b0;
        valid_LSB = 1'b0;
        breakout_B = 1'b0;
        for (int j = 0; j < NUM_BLOCKS; j = j + 1) begin
            if (~breakout_B) begin
                if (valid_blocks_LSB[j]) begin
                    out_LSB = {j, block_outs_LSB[j]};
                    valid_LSB = 1'b1;
                    breakout_B = 1'b1;
                end
            end
        end
    end else begin
        out_LSB = 1'b0;
        valid_LSB = 1'b1;
        breakout_B = 1'b1;
    end
end

assign valid = valid_MSB && valid_LSB;

endmodule



module priority_encoder_MSB_4b (
    input [3:0] in,                 // 4b input 
    output logic [1:0] out,               // 2b output: index of MS asserted bit
    output logic valid                    // HIGH if asserted bit found
);
always_comb begin
    if (in[3]) out = 2'b11;
    else if (in[2]) out = 2'b10;
    else if (in[1]) out = 2'b01;
    else out = 2'b00;
    valid = in != 4'b0;    
end
endmodule

module priority_encoder_LSB_4b (
    input [3:0] in,
    output logic [1:0] out,
    output logic out_valid
);
always_comb begin
    if (in[0]) out = 2'b00;
    else if (in[1]) out = 2'b01;
    else if (in[2]) out = 2'b10;
    else out = 2'b11;
    out_valid = in != 4'b0;
end
endmodule
