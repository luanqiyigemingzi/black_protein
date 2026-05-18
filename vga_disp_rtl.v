module vga_disp_rtl	
(
	input					clk25M,        // 25MHz时钟输入
	input					reset_n,       // 复位信号，低电平有效
    output                 VGA_EN,        // VGA使能信号
	output 				VGA_HSYNC,      // VGA水平同步信号
	output 				VGA_VSYNC,      // VGA垂直同步信号
	input[23:0]  rgb,           // 24位RGB输入数据
	output [14:0]addr ,         // 显示地址输出

	output reg [11:0] VGA_D     // 12位VGA数据输出
);		
wire dis_en;                    // 显示使能信号
reg  [9:0]		hcnt	;       // 水平计数器
reg  [9:0]		vcnt	;       // 垂直计数器		
reg				hs		;       // 水平同步寄存器	
reg   			vs		;       // 垂直同步寄存器


wire [9:0] 		x     ;          // 当前水平坐标
wire [9:0] 		y     ;          // 当前垂直坐标
wire [9:0] 		x_reg     ;      // 调整后的水平坐标
wire [9:0] 		y_reg     ;      // 调整后的垂直坐标

// 坐标调整：减去前沿空白区域
assign x_reg = x>16? (x-16) : 0;  // 水平坐标调整（减去16像素前沿）
assign y_reg = y>10? (y-10) : 0;  // 垂直坐标调整（减去10像素前沿）

assign x = hcnt;                 // 水平坐标等于水平计数器
assign y = vcnt;                 // 垂直坐标等于垂直计数器

// 地址生成：将64x64显示区域映射到地址空间
assign addr = {3'b000,y_reg[5:0],x_reg[5:0]};  // 地址 = {3位0, 6位Y坐标, 6位X坐标}

assign VGA_VSYNC = vs;           // 输出垂直同步信号
assign VGA_HSYNC = hs;           // 输出水平同步信号

// 显示使能：在64x64像素区域内使能显示
assign dis_en = (y_reg<10'd64 && x_reg<10'd64);

// VGA使能：在有效显示区域内使能（640x480区域）
assign VGA_EN  = (((hcnt >= 8+8) && (hcnt < 8+8+640))
                 &&((vcnt >= 8+2) && (vcnt < 8+2+480)))
                 ?  1'b1 : 1'b0;

// 水平扫描计数器（800像素/行：640显示 + 160消隐）
always @(posedge clk25M or negedge reset_n) begin
	if(!reset_n)
		hcnt <= 1'b0;           // 复位时清零
	else begin
		if (hcnt < 800)         // 每行800个像素
			hcnt <= hcnt + 1'b1;  // 递增水平计数器
		else
			hcnt <= 1'b1;         // 行结束，回到起始
	end
end

// 垂直扫描计数器（525行/帧：480显示 + 45消隐）
always @(posedge clk25M or negedge reset_n) begin
	if(!reset_n)
		vcnt <= 1'b0;           // 复位时清零
	else begin
		if (hcnt == 800) begin   // 水平扫描结束时
			if (vcnt < 10'd525)    // 每帧525行
				vcnt <= vcnt +1'b1;  // 递增垂直计数器
			else
				vcnt <= 1'b1;       // 帧结束，回到起始
		end
	end
end

// 水平同步信号发生
always @(posedge clk25M or negedge reset_n) begin
	if(!reset_n)
		hs	<=	1'b1;           // 复位时置高
	else begin
		// 水平同步脉冲：在行消隐期间产生低电平脉冲
		if((hcnt >= 640+8+8) & (hcnt < 640+8+8+96))
			hs <= 1'b0;         // 同步脉冲期间输出低电平
		else
			hs <= 1'b1;         // 其他时间输出高电平
	end
end

// 垂直同步信号发生（组合逻辑）
always @(vcnt or reset_n) begin
	if(!reset_n)
		vs	<=	1'b1;           // 复位时置高
	else begin
		// 垂直同步脉冲：在场消隐期间产生低电平脉冲
		if((vcnt >= 480+8+2) && (vcnt < 480+8+2+2))
			vs	<=	1'b0;       // 同步脉冲期间输出低电平
		else
			vs	<=	1'b1;       // 其他时间输出高电平
	end
end

// VGA数据输出
always @(posedge clk25M or negedge reset_n) begin
	if(!reset_n)
		VGA_D <= 1'b0;          // 复位时清零
	else begin
		if (VGA_EN && dis_en)	begin	// 在有效显示区域内
			// 将24位RGB数据转换为12位RGB444格式
			VGA_D[11:8] <=  rgb[23:20];  // R分量高4位
			VGA_D[ 7:4] <=  rgb[15:12];  // G分量高4位
			VGA_D[ 3:0] <= rgb[7:4];     // B分量高4位
		end
		else begin
			VGA_D <= 0;         // 非显示区域输出黑色
		end
	end
end

// 以下为注释掉的测试代码，用于生成彩色条纹测试图案
/*
// reg  [9:0]		hcnt	;
// reg  [9:0]		vcnt	;		
// reg				hs		;	
// reg   			vs		;


// wire [2:0]  	rgb	;
// wire [9:0] 		x     ;
// wire [9:0] 		y     ;
// wire 				dis_en;

// assign x = hcnt;
// assign y = vcnt;
// assign VGA_VSYNC = vs;
// assign VGA_HSYNC = hs;
// assign dis_en = (x<10'd640 && y<10'd480);
// assign rgb = x[8:6]^y[8:6];  // 通过异或操作生成彩色条纹
// assign VGA_EN  = (((hcnt >= 8+8) && (hcnt < 8+8+640))
//                  &&((vcnt >= 8+2) && (vcnt < 8+2+480)))
//                  ?  1'b1 : 1'b0;


			
// always @(posedge clk25M or negedge reset_n) begin			//水平扫描计数器
// 	if(!reset_n)
// 		hcnt <= 1'b0;
// 	else begin
// 		if (hcnt < 800)
// 			hcnt <= hcnt + 1'b1;
// 		else
// 			hcnt <= 1'b1;
// 	end
// end
			
// always @(posedge clk25M or negedge reset_n) begin			//垂直扫描计数器
// 	if(!reset_n)
// 		vcnt <= 1'b0;
// 	else begin
// 		if (hcnt == 800) begin
// 			if (vcnt < 10'd525)
// 				vcnt <= vcnt +1'b1;
// 			else
// 				vcnt <= 1'b1;
// 		end
// 	end
// end
			
// always @(posedge clk25M or negedge reset_n) begin			//场同步信号发生
// 	if(!reset_n)
// 		hs	<=	1'b1;
// 	else begin
// 		if((hcnt >= 640+8+8) & (hcnt < 640+8+8+96))
// 			hs <= 1'b0;
// 		else
// 			hs <= 1'b1;
// 	end
// end
			
// always @(vcnt or reset_n) begin							//行同步信号发生
// 	if(!reset_n)
// 		vs	<=	1'b1;
// 	else begin
// 		if((vcnt >= 480+8+2) && (vcnt < 480+8+2+2))
// 			vs	<=	1'b0;
// 		else
// 			vs	<=	1'b1;
// 	end
// end
			
// always @(posedge clk25M or negedge reset_n) begin
// 	if(!reset_n)
// 		VGA_D <= 1'b0;
// 	else begin
// 		if (hcnt < 10'd640 & vcnt < 10'd480 && dis_en)	begin	//扫描终止
// 			VGA_D[11:8] <= 1111;  // 红色全亮
// 			VGA_D[ 7:4] <= 0;     // 绿色关闭
// 			VGA_D[ 3:0] <= 1111;  // 蓝色全亮
// 		end
// 		else begin
// 			VGA_D <= 0;
// 		end
// 	end
// end
*/
endmodule 