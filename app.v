module app (
    input                   	sys_clk		,  //系统时钟
    input                   	udp_rx_clk	,  //UDP接收时钟
    input                   	udp_tx_clk	,  //UDP发送时钟
    input                   	reset		,  //复位信号低电平有效

//udp2app信号    
    input               		app_rx_data_valid	,  //应用层接收数据有效
    input  [7:0]         		app_rx_data			,  //应用层接收数据
    input wire [15:0]        	app_rx_data_length	,  //应用层接收数据长度
    input wire [15:0]        	app_rx_port_num		,  //应用层接收端口号
    

    output [11:0]              	VGA_D				,  //VGA数据输出
    output                     	VGA_HSYNC			,  //VGA水平同步
    output                     	VGA_VSYNC			,  //VGA垂直同步
    output                     	rd_en				,  //读使能
	output   					VGA_EN				  //VGA使能
);

wire        wr_en;  //写使能

reg       clk25M;  //25MHz时钟
wire [23:0]  ram_data;  //RAM数据
wire [23:0]  rgb;  //RGB颜色数据
wire [16:0] wr_addr;  //写地址
wire [16:0] addr;  //读地址
wire [23:0] ram_data_1;  //RAM数据副本

//25MHz时钟生成（通过系统时钟分频）
always @(posedge sys_clk or negedge reset) begin
	if (!reset)
		clk25M <= 0;
	else
		clk25M <= ~clk25M;
end

//地址生成和数据处理模块
addr_crt u_addr_crt(
 .      clk   (udp_rx_clk),  //UDP接收时钟
 .      rst_n  (reset),  //复位信号
 .      udp_data (app_rx_data),  //UDP接收数据
 .      udp_vaild  (app_rx_data_valid),  //UDP数据有效
 .      udp_length (app_rx_data_length),  //UDP数据长度
 .      wr_addr (wr_addr),  //写地址输出
 .      wr_en  (wr_en),  //写使能输出
 .      rd_en  (rd_en),  //读使能输出
 .      ram_data (ram_data)  //RAM数据输出
);

assign ram_data_1=ram_data[23:0];  //RAM数据赋值

//RAM存储器模块
ram  u_ram (
	.dia   (ram_data_1	)	,  //数据输入A
	.addra (wr_addr)	,  //地址输入A
	.clka  (udp_rx_clk	)	,  //时钟A
	.dob	(rgb	)	,  //数据输出B
	.addrb (addr)	,  //地址输入B
	.clkb  (sys_clk ),  //时钟B
	.wea(wr_en),  //写使能A
	.cea(wr_en)  //片选使能A
);

/*ROM BMP模块（注释掉）
rom_bmp u_rom_bmp (
	.addra 	(addr),  //地址输入
	.clka 		(clk25M),  //时钟
	.doa 			(rgb)  //数据输出
);*/

//VGA显示模块
vga_disp_rtl u_vga_disp_rtl(
	.clk25M 	(sys_clk),  //25MHz时钟
	.reset_n    (reset),  //复位信号
	.rgb		(rgb),  //RGB输入数据
    //输出
	.VGA_HSYNC	(VGA_HSYNC),  //水平同步
	.VGA_VSYNC	(VGA_VSYNC),  //垂直同步
    .VGA_EN     (VGA_EN),  //VGA使能
	.addr		(addr),  //地址输出
	.VGA_D		(VGA_D)  //VGA数据输出
);

/*另一种VGA显示模块（注释掉）
vga_disp u_vga_disp(
	.	clk25M		(sys_clk),
	.	reset_n     (reset),
	.   rgb	        (rgb),
	.	VGA_HSYNC	(VGA_HSYNC),
	. 	VGA_VSYNC 	(VGA_VSYNC),
	.	addr        (addr),
	.   VGA_D       (VGA_D),
	.dis_en       (dis_en)
);*/

endmodule