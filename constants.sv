`ifndef _parameters_svh
`define _parameters_svh

parameter NUM_REG = 32;
parameter NUM_REG_LOG2 = $clog2(NUM_REG);
parameter NUM_TAGS = 64;
parameter NUM_TAGS_LOG2 = $clog2(NUM_TAGS);
parameter INSTR_SIZE = 32;
parameter REG_SIZE = 32;
parameter ROB_SIZE = 64;
parameter ROB_SIZE_LOG2 = $clog2(ROB_SIZE);
parameter RETIRE_PORTS = 1;
parameter IQ_SIZE = 64,
parameter ISSUE_PORTS = 3,

`endif
