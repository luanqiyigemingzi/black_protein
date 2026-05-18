`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 武汉芯路恒科技有限公司
// Engineer: www.corecourse.cn
// 
// Create Date: 2021/09/20 00:00:00
// Design Name: key_filter
// Module Name: key_filter
// Project Name: key_filter
// Target Devices: xc7z020clg400-2
// Tool Versions: Vivado 2018.3
// Description: 按键消抖状态机
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module key_filter(
	clk,
	reset_n,
	key_in,
	key_flag,
	key_state
);
    wire reset;
	assign reset=~reset_n;
	input clk; //模块全局时钟输入，50M
	input reset_n; //复位信号输入，低有效
	input key_in; //按键输入

	output key_flag ; //按键标志信号
	output key_state; //按键状态信号

	reg key_flag ;
	reg key_state;
	
	// 定义状态机的四个状态
	localparam
		IDLE= 4'b0001,     // 空闲状态，等待按键按下
		FILTER0= 4'b0010,  // 按下消抖状态
		DOWN= 4'b0100,     // 按键稳定按下状态
		FILTER1= 4'b1000;  // 释放消抖状态

	reg [3:0]state;  //状态机状态寄存器
	reg [19:0]cnt;   //20位计数器，用于消抖计时
	reg en_cnt;      //计数器使能信号
	reg cnt_full;	   //计数器满标志信号

	// 同步寄存器，用于同步外部异步输入信号
	reg  key_in_sync1;
	reg  key_in_sync2;
	// 延迟寄存器，用于检测边沿
	reg  key_in_reg1;
	reg  key_in_reg2;
	// 边沿检测信号
	wire key_in_pedge;  //上升沿检测
	wire key_in_nedge;  //下降沿检测

//对外部输入的异步信号进行同步处理（两级同步器，降低亚稳态风险）
	always@(posedge clk or posedge reset)
	if(reset)begin
		key_in_sync1 <= 1'b0;
		key_in_sync2 <= 1'b0;
	end
	else begin
		key_in_sync1 <= key_in;
		key_in_sync2 <= key_in_sync1;	
	end
	
//使用D触发器存储两个相邻时钟上升沿时外部输入信号（已经同步到系统时钟域中）的电平状态
	always@(posedge clk or posedge reset)
	if(reset)begin
		key_in_reg1 <= 1'b0;
		key_in_reg2 <= 1'b0;
	end
	else begin
		key_in_reg1 <= key_in_sync2;
		key_in_reg2 <= key_in_reg1;	
	end

//产生跳变沿信号	
	assign key_in_nedge = !key_in_reg1 & key_in_reg2;  //检测下降沿：前一时刻为高，当前时刻为低
	assign key_in_pedge = key_in_reg1 & (!key_in_reg2); //检测上升沿：前一时刻为低，当前时刻为高

//按键消抖状态机	
	always@(posedge clk or posedge reset)
	if(reset)begin  //复位处理
		en_cnt <= 1'b0;
		state <= IDLE;
		key_flag <= 1'b0;
		key_state <= 1'b1;
	end
	else begin
		case(state)
			IDLE :begin  //空闲状态
				key_flag <= 1'b0;  //清除按键标志
				if(key_in_nedge)begin  //检测到下降沿，可能按键按下
					state <= FILTER0;  //转移到按下消抖状态
					en_cnt <= 1'b1;    //使能计数器开始消抖计时
				end
				else
					state <= IDLE;  //保持空闲状态
			end

			FILTER0:begin  //按下消抖状态
				if(cnt_full)begin  //计数器满，消抖完成
					key_flag <= 1'b1;   //产生按键有效标志
					key_state <= 1'b0;  //按键状态为按下(低电平有效)
					en_cnt <= 1'b0;     //关闭计数器
					state <= DOWN;      //转移到按键稳定按下状态
				end
				else if(key_in_pedge)begin  //在消抖期间检测到上升沿，说明是抖动
					state <= IDLE;   //返回空闲状态
					en_cnt <= 1'b0;  //关闭计数器
				end
				else
					state <= FILTER0;  //保持消抖状态
			end

			DOWN:begin  //按键稳定按下状态
					key_flag <= 1'b0;  //清除按键标志
					if(key_in_pedge)begin  //检测到上升沿，可能按键释放
						state <= FILTER1;  //转移到释放消抖状态
						en_cnt <= 1'b1;    //使能计数器开始消抖计时
					end
					else
						state <= DOWN;  //保持按下状态
			end

			FILTER1:begin  //释放消抖状态
				if(cnt_full)begin  //计数器满，消抖完成
					key_flag <= 1'b1;   //产生按键有效标志
					key_state <= 1'b1;  //按键状态为释放(高电平)
					state <= IDLE;      //返回空闲状态
					en_cnt <= 1'b0;     //关闭计数器
				end
				else if(key_in_nedge)begin  //在消抖期间检测到下降沿，说明是抖动
					en_cnt <= 1'b0;  //关闭计数器
					state <= DOWN;   //返回按键按下状态
				end
				else
					state <= FILTER1;  //保持消抖状态
			end

			default:begin  //默认状态，防止进入未知状态
				state <= IDLE;      //返回空闲状态
				en_cnt <= 1'b0;     //关闭计数器		
				key_flag <= 1'b0;   //清除按键标志
				key_state <= 1'b1;  //按键状态为释放
			end
				
		endcase	
	end
	
	// 计数器逻辑：当en_cnt为1时计数，否则清零
	always@(posedge clk or posedge reset)
	if(reset)
		cnt <= 20'd0;
	else if(en_cnt)
		cnt <= cnt + 1'b1;
	else
		cnt <= 20'd0;
	
	// 计数器满标志生成逻辑：计数到999999时产生满标志
	always@(posedge clk or posedge reset)
	if(reset)
		cnt_full <= 1'b0;
	else if(cnt == 20'd999_999)  //对应20ms消抖时间(50MHz时钟)
		cnt_full <= 1'b1;
	else
		cnt_full <= 1'b0;	

endmodule