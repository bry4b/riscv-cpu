`ifndef _parameters_svh
`define _parameters_svh

localparam NUM_REG = 32;
localparam NUM_REG_LOG2 = $clog2(NUM_REG);
localparam NUM_TAGS = 64;
localparam NUM_TAGS_LOG2 = $clog2(NUM_TAGS);
localparam INSTR_SIZE = 32;
localparam REG_SIZE = 32;
localparam ROB_SIZE = 64;
localparam ROB_SIZE_LOG2 = $clog2(ROB_SIZE);
localparam RETIRE_PORTS = 1;
localparam IQ_SIZE = 64;
localparam ISSUE_PORTS = 3;

`endif
