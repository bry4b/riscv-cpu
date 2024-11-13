`ifndef _parameters_svh
`define _parameters_svh

parameter NUM_REG = 32;
parameter NUM_REG_LOG2 = $clog2(NUM_REG);
parameter NUM_P_REG = 2*NUM_REG;
parameter INSTR_SIZE = 32;
parameter REG_SIZE = 32;
parameter ROB_SIZE = 16;
parameter ROB_SIZE_LOG2 = $clog2(ROB_SIZE);

`endif
