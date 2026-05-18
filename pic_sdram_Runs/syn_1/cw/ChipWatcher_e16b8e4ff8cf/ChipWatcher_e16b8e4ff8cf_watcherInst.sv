module ChipWatcher_e16b8e4ff8cf ( 
    input [11:0] probe0, 
    input       clk  
);  
    localparam CWC_BUS_NUM = 1;
    localparam CWC_BUS_DIN_NUM = 12;
    localparam CWC_CTRL_LEN = 102;
	localparam CWC_BUS_CTRL_LEN = 40;
    localparam INPUT_PIPE_NUM = 2;
    localparam OUTPUT_PIPE_NUM = 0;
	localparam CWC_CAPTURE_CTRL_EXIST = 1;
    localparam RAM_LEN = 12;
    localparam RAM_DATA_DEPTH = 1024;
    localparam STAT_REG_LEN = 24;
    localparam integer CWC_BUS_WIDTH[0:CWC_BUS_NUM-1] = { 12 };
    localparam integer CWC_BUS_DIN_POS[0:CWC_BUS_NUM-1] = { 0 };    
    localparam integer CWC_BUS_CTRL_POS[0:CWC_BUS_NUM-1] = { 0 };

    wire                     cwc_rst;
    wire [CWC_CTRL_LEN-1:0]  cwc_control;
    wire [STAT_REG_LEN-1:0]  cwc_status;  

	top_cwc_hub #(
		.CWC_BUS_NUM(CWC_BUS_NUM),
		.CWC_BUS_DIN_NUM(CWC_BUS_DIN_NUM),
		.CWC_CTRL_LEN(CWC_CTRL_LEN),
		.CWC_BUS_CTRL_LEN(CWC_BUS_CTRL_LEN),
		.CWC_BUS_WIDTH(CWC_BUS_WIDTH),
		.CWC_BUS_DIN_POS(CWC_BUS_DIN_POS),
		.CWC_BUS_CTRL_POS(CWC_BUS_CTRL_POS),
		.RAM_DATA_DEPTH(RAM_DATA_DEPTH),
		.CWC_CAPTURE_CTRL_EXIST(CWC_CAPTURE_CTRL_EXIST),
		.RAM_LEN(RAM_LEN),
		.INPUT_PIPE_NUM(INPUT_PIPE_NUM),
		.OUTPUT_PIPE_NUM(OUTPUT_PIPE_NUM)
	)

	 wrapper_cwc_top(
		.cwc_trig_clk(clk),
		.cwc_control(cwc_control),
		.cwc_status(cwc_status),
		.cwc_rst(cwc_rst),
		.cwc_bus_din({probe0}),
		.ram_data_din({probe0})
	);

    AL_LOGIC_DEBUGHUB #(
		.CTRL_LEN(CWC_CTRL_LEN),
		.STAT_LEN(STAT_REG_LEN)
	) wrapper_debughub(
		.clk(clk),
		.control(cwc_control),
		.status(cwc_status),
		.rst(cwc_rst)
	);

endmodule


