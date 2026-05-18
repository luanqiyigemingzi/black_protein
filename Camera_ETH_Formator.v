/*============================================================================
*
*  LOGIC CORE:          对摄像头行数据进行编号 (时序修复版)
*  MODULE NAME:         Camera_ETH_Formator()
*  ... (header unchanged) ...
*  REVISION HISTORY:  
*
*    Revision 1.0  04/10/2019     Description: Initial Release.
* Revision 2.0  (User)         Description: Fixed critical timing violations
* by registering all inputs (HREF, DATA)
* before use in logic.
*
*  FUNCTIONAL DESCRIPTION:
===========================================================================*/

module Camera_ETH_Formator(
	PCLK,					// 像素时钟输入
	Rst_n,					// 低电平复位
    Init_Done,				// 摄像头初始化完成标志
	HREF,					// 行有效信号（高电平表示有效行数据）
	VSYNC,					// 帧同步信号（高电平表示帧开始）
	DATA,					// 8位像素数据输入

	fifo_aclr,				// 输出：FIFO异步清零信号（高有效）
	wrdata,					// 输出：24位拼接后的数据（高8位有效）
	wrreq					// 输出：FIFO写请求信号
);

	input PCLK;
	input Rst_n;
	input Init_Done;
	input HREF;
	input VSYNC;
	input [7:0]DATA;
	output reg fifo_aclr;	
	output [7:0]wrdata;
	output reg wrreq;
	
	reg [23:0]data_tmp;		// 24位移位寄存器，用于拼接行号+像素数据
	reg [15:0]Vcnt;			// 行计数器（对行进行编号）
		
	reg href_r1;			// HREF打拍1
	reg href_r2;			// HREF打拍2
	reg [7:0] data_r1;		// DATA 打拍1 (用于匹配HREF的延迟)
	
	// --- 新增：使用已寄存信号的干净的边沿检测 ---
	wire href_posedge;		// 已寄存的上升沿
	wire href_negedge;		// 已寄存的下降沿
	
	// 输出高8位给FIFO（先送行号高字节）
	assign wrdata = data_tmp[23:16];
	
	// 1. 同步所有输入
	// (Vsync 假设是慢速信号, 这里暂不双重寄存)
	always@(posedge PCLK)begin
		href_r1 <= HREF;
		href_r2 <= href_r1;	
		data_r1 <= DATA; // 同步DATA,使其与href_r1/r2对齐
	end
	
	// 2. 基于“已同步”的信号进行边沿检测
	//    这提供了稳定、无毛刺的单周期触发脉冲
	assign href_posedge = (href_r1 == 1'b1) && (href_r2 == 1'b0); // {href_r2, href_r1} == 2'b01
	assign href_negedge = (href_r1 == 1'b0) && (href_r2 == 1'b1); // {href_r2, href_r1} == 2'b10
	
    // FIFO异步清零控制：(此逻辑不变)
    always @ (posedge PCLK or negedge Rst_n)
	if (!Rst_n)
		fifo_aclr <= #1 1'b1;
	else if (Init_Done && VSYNC ) //等到初始化摄像完成且头场同步信号出现，释放清零信号，开始写入数据
		fifo_aclr <= #1 1'b0;
	else
		fifo_aclr <= #1 fifo_aclr;
	
	// 3. 数据拼接逻辑：使用“已同步”的边沿和数据
	always@(posedge PCLK or negedge Rst_n)
	if(!Rst_n)
		data_tmp <= 0;
	else if(href_posedge) // <-- MODIFIED: 使用干净的上升沿
		data_tmp <= {Vcnt[7:0],Vcnt[15:8], data_r1}; // <-- MODIFIED: 使用同步后的data_r1
	else 
		data_tmp <= {data_tmp[15:0], data_r1}; // <-- MODIFIED: 持续移入同步后的data_r1
	
	// 4. 写请求生成：使用“已同步”的信号
	//    (我们必须拉长wrreq以匹配2级移位寄存器data_tmp的延迟)
	reg wrreq_r1, wrreq_r2;
	wire wrreq_base = href_posedge | href_r1 | href_r2; // 基础有效信号
	
	always@(posedge PCLK or negedge Rst_n)
	if(!Rst_n) begin
		wrreq <= 1'b0;
		wrreq_r1 <= 1'b0;
		wrreq_r2 <= 1'b0;
	end
	else begin
		// wrreq_base 在 href_r2 变低后就变低了
		// 但此时最后两个像素 (data_tmp[15:8], data_tmp[7:0]) 仍在流水线中
		// 我们通过将 wrreq 延迟2拍来保持其有效, 覆盖最后两个字节
		wrreq <= wrreq_base | wrreq_r1 | wrreq_r2;
		wrreq_r1 <= wrreq_base;
		wrreq_r2 <= wrreq_r1;
	end

	// 5. 行计数器：使用“已同步”的下降沿
	always@(posedge PCLK or negedge Rst_n)
	if(!Rst_n)
		Vcnt <= 0;
	else if(VSYNC)	// 帧同步期间清零
		Vcnt <= 0;
	else if(href_negedge) // <-- MODIFIED: 使用干净的下降沿
		Vcnt <= Vcnt + 1'd1;

endmodule