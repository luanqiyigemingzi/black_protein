`timescale 1ns / 1ps
//********************************************************************** 
// -------------------------------------------------------------------
// >>>>>>>>>>>>>>>>>>>>>>>Copyright Notice<<<<<<<<<<<<<<<<<<<<<<<<<<<< 
// ------------------------------------------------------------------- 
//             /\ --------------- 
//            /  \ ------------- 
//           / /\ \ -----------
//          / /  \ \ ---------
//         / /    \ \ ------- 
//        / /      \ \ ----- 
//       / /_ _ _   \ \ --- 
//      /_ _ _ _ _\  \_\ -
//*********************************************************************** 
// Author: suluyang 
// Email:luyang.su@anlogic.com 
// Date:2020/10/26 
// Description: 
// 
// web：www.anlogic.com 
//------------------------------------------------------------------- 
//*********************************************************************/
module udp_loopback(
    // 用户接收时钟
input   wire		app_rx_clk		   ,
    // 用户发送时钟
input   wire		app_tx_clk		   ,
    // 高电平复位
input   wire		reset              ,
    // 接收数据（24 bit）
input   wire [23:0]	app_rx_data        ,
    // 接收数据有效标志
input   wire		app_rx_data_valid  ,
    // 接收数据长度（字节）
input   wire [15:0] app_rx_data_length ,
    // UDP 发送端准备好
input   wire		udp_tx_ready       ,
    // 发送端应答（表示当前数据已被取走）
input   wire		app_tx_ack         ,
    // 发送数据（8 bit）
output  wire  [7:0] app_tx_data        ,
    // 请求开始发送 UDP 包
output	reg  		app_tx_data_request,
    // 发送数据有效标志
output	reg  		app_tx_data_valid  ,
    // 当前 UDP 包长度（字节）
output  reg  [15:0]	udp_data_length	 ,  //s
    // FIFO 写满标志
output  full_flag,
    // FIFO 写侧已用量（12 bit）
output [11:0 ] udp_wrusedw		
);
parameter  			 	DEVICE            = "EG4";//"PH1","EG4"
    // 读 FIFO 使能信号
reg         app_tx_data_read;
    // FIFO 读侧已用量（12 bit）
wire [11:0] udp_packet_fifo_data_cnt;//synthesis keep
    // 已读数据计数（字节）
reg  [15:0] fifo_read_data_cnt;
    // 接收长度打拍 1
reg  [15:0] udp_data_length_reg_ff1;
    // 接收长度打拍 2
reg  [15:0] udp_data_length_reg_ff2;
    // 从 FIFO 读出的 24 bit 数据
wire [23:0]  app_tx_data_reg;

    // 字节计数器线
wire  [15:0] fifo_read_data_cnt_wire;
assign fifo_read_data_cnt_wire =fifo_read_data_cnt ;
    // 按大端顺序把 24 bit 拆成 3 字节输出
assign app_tx_data = (fifo_read_data_cnt_wire == 3 )? app_tx_data_reg [7:0] : ((fifo_read_data_cnt_wire == 2 )? app_tx_data_reg [15:8] : ((fifo_read_data_cnt_wire == 1 )? app_tx_data_reg [23:16] : 0));

    // 状态机寄存器
reg [1:0]   STATE;
    // 状态编码
localparam  WAIT_UDP_DATA   = 2'd0;  // 等待UDP数据状态
localparam  WAIT_ACK        = 2'd1;  // 等待应答状态
localparam  SEND_UDP_DATA   = 2'd2;  // 发送UDP数据状态
localparam  DELAY           = 2'd3;  // 延时状态

// assign udp_packet_fifo_data_cnt = 1;

    // FIFO 空标志
wire empty_flag;//synthesis keep

    // 异步 FIFO：跨时钟域缓存 UDP 包
ram_fifo#
(
	.DEVICE       	(DEVICE       	),//"PH1","EG4","SF1","EF2","EF3","AL"
	.DATA_WIDTH_W 	(24				),//写数据位宽
	.ADDR_WIDTH_W 	(12 			),//写地址位宽
	.DATA_WIDTH_R 	(24 			),//读数据位宽
	.ADDR_WIDTH_R 	(12 			),//读地址位宽
	.SHOW_AHEAD_EN	(1				)//普通/SHOWAHEAD模式
)
udp_packet_fifo
(
	.rst			(reset				),  // 复位信号
	.di				(app_rx_data		),  // 写数据输入
	.clkw			(app_rx_clk			),  // 写时钟
	.we				(app_rx_data_valid	),  // 写使能
	.clkr			(app_tx_clk			),  // 读时钟
	.re				(app_tx_data_read	),  // 读使能
	.do				(app_tx_data_reg	),  // 读数据输出
	.empty_flag		(	empty_flag				),  // 空标志
	.full_flag		(full_flag					),  // 满标志
	.wrusedw		(	udp_wrusedw				),  // 写侧使用量
	.rdusedw		(udp_packet_fifo_data_cnt)// 读侧使用量
);

// 以下注释为原 FIFO 例化（已屏蔽）

// fifo_sdr_data_2 udp_packet_fifo(
//    .rst			   			(reset	)	,  //asynchronous port,active hight
//    .clkw		   			(app_rx_clk		),  //write clock
//    .clkr		   			(app_tx_clk		),  //read clock
//    .we			   			(app_rx_data_valid			),  //write enable,active hight
//    .di			   			(app_rx_data			),  //write data
//    .re			   			(app_tx_data_read			),  //ead enable,active hight
//    .	dout		    	(app_tx_data_reg		),  //read data
//    . 	valid		     	(app_tx_data_valid		),  //read data valid flag
//    .	full_flag	    	(full_flag	),  //fifo full flag
//    .	empty_flag	    	(empty_flag	),  //fifo empty flag
//    .	afull		    	(		),  //fifo almost full flag
//    .	aempty		    	(		),  //fifo almost empty flag
//    .	wrusedw	  	    	(	)	,  	//	stored data number in fifo
//    .	rdusedw 	    	( 	)//available data number for read
// );

    // 接收长度打拍：跨时钟域同步
always@(posedge app_tx_clk or posedge reset)
begin
	if(reset) begin  // 复位时清零
		udp_data_length_reg_ff1 <= 16'd0;
		udp_data_length_reg_ff2 <= 16'd0;
	end	
	else if(app_rx_data_valid)  // 接收数据有效时同步长度
	begin 
		udp_data_length_reg_ff1 <= app_rx_data_length;  // 第一级打拍
		udp_data_length_reg_ff2 <= udp_data_length_reg_ff1;  // 第二级打拍
	end
end

    // 发送字节计数器（调试用）
reg [19:0]tx_cnt ;//synthesis keep
always@(posedge app_tx_clk or posedge reset)
begin
	if(reset) begin  // 复位清零
		tx_cnt <= 20'd0;
	end	
	else if(app_tx_data_valid)  // 发送数据有效时计数
	begin 
    tx_cnt<=tx_cnt+1;  // 发送字节计数
	end
end

    // 状态机：控制 UDP 回环发送流程
reg [15:0]cnt;  // 延时计数器
always@(posedge app_tx_clk or posedge reset)
begin
	if(reset) begin  // 复位初始化
		app_tx_data_request <= 1'b0;
		app_tx_data_read 	<= 1'b0;
		app_tx_data_valid 	<= 1'b0;
		fifo_read_data_cnt 	<= 16'd0;
		udp_data_length 	<= 16'd0;
        cnt <=16'b0;
		STATE 				<= WAIT_UDP_DATA;  // 初始状态
	end
	else begin
	   case(STATE)
			WAIT_UDP_DATA: // 0 等待 FIFO 有数据且接收完成
				begin
                    cnt<=16'b0;  // 清零延时计数器
					if((udp_packet_fifo_data_cnt > 12'd0)  && (~app_rx_data_valid) && udp_tx_ready) begin  // FIFO有数据、不在接收中、发送端就绪
                  //if(!empty_flag && (~app_rx_data_valid) && udp_tx_ready) begin
                   // if( (~app_rx_data_valid) && udp_tx_ready) begin
						app_tx_data_request <= 1'b1;  // 请求发送
						STATE 				<= WAIT_ACK;  // 转到等待应答状态
					end
					else begin
						app_tx_data_request <= 1'b0;  // 取消发送请求
						STATE 				<= WAIT_UDP_DATA;  // 保持等待状态
					end
				end
			WAIT_ACK: // 1 等待发送端应答
				begin
				   if(app_tx_ack) begin  // 收到应答信号
						app_tx_data_request <= 1'b0;  // 取消发送请求
						app_tx_data_read 	<= 1'b1;  // 开始读FIFO
						app_tx_data_valid 	<= 1'b0;  // 数据暂时无效
						udp_data_length 	<= udp_data_length_reg_ff2;// 锁存包长
						STATE 				<= SEND_UDP_DATA;  // 转到发送状态
					end
					else begin
						app_tx_data_request <= 1'b1;  // 保持发送请求
						app_tx_data_read	<= 1'b0;  // 不读FIFO
						app_tx_data_valid 	<= 1'b0;  // 数据无效
						udp_data_length 	<= 16'd0;  // 清零包长
						STATE 				<= WAIT_ACK;  // 保持等待应答状态
					end
				end
			SEND_UDP_DATA: // 2 逐字节发送
				begin
					if(fifo_read_data_cnt == (udp_data_length_reg_ff2 )) begin  // 发送完成
						fifo_read_data_cnt 	<= 16'd0;  // 清零字节计数器
						app_tx_data_valid 	<= 1'b0;  // 数据无效
						app_tx_data_read 	<= 1'b0;  // 停止读FIFO
						STATE 				<= DELAY;  // 转到延时状态
					end
					else  if (fifo_read_data_cnt == 0 )begin  // 第一个字节
						fifo_read_data_cnt 	<= fifo_read_data_cnt + 1'b1;  // 递增字节计数器
						app_tx_data_valid  	<= 1'b1;  // 数据有效
						app_tx_data_read 	<= 1'b0;  // 不读FIFO（SHOWAHEAD模式提前输出）
						STATE 				<= SEND_UDP_DATA;  // 保持发送状态
					end		
					else begin  // 后续字节
						fifo_read_data_cnt 	<= fifo_read_data_cnt + 1'b1;  // 递增字节计数器
						app_tx_data_valid  	<= 1'b1;  // 数据有效
						app_tx_data_read 	<= 1'b0;  // 不读FIFO（SHOWAHEAD模式提前输出）
						STATE 				<= SEND_UDP_DATA;  // 保持发送状态
					end				
				end
			DELAY: // 3 包间延时
				begin
					if(cnt<16'h00000fff)begin  // 延时计数
                    	cnt<=cnt+1'b1;  // 递增延时计数器
						STATE 	<= DELAY;  // 保持延时状态
                        end
					else
						STATE 	<= WAIT_UDP_DATA;  // 延时结束，回到等待状态
				end
			default: STATE 		<= WAIT_UDP_DATA;  // 默认回到等待状态
		endcase
	end
end

endmodule