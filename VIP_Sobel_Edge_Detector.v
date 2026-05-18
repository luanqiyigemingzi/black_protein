//8位灰度图像处理的Sobel边缘检测模块
module VIP_Sobel_Edge_Detector
#(
	parameter	[9:0]	IMG_HDISP = 10'd640,	//640*480
	parameter	[9:0]	IMG_VDISP = 10'd480
)
(
	//global clock
	input				clk,  				//cmos video pixel clock
	input				rst_n,				//global reset

	//Image data prepred to be processd
	input				per_frame_vsync,	//Prepared Image data vsync valid signal
	input				per_frame_href,		//Prepared Image data href vaild  signal
	input				per_frame_clken,	//Prepared Image data output/capture enable clock
	input		[7:0]	per_img_Y,			//Prepared Image brightness input
	
	//Image data has been processd
	output				post_frame_vsync,	//Processed Image data vsync valid signal
	output				post_frame_href,	//Processed Image data href vaild  signal
	output				post_frame_clken,	//Processed Image data output/capture enable clock
	output				post_img_Bit,		//Processed Image Bit flag outout(1: Value, 0:inValid)
	
	//user interface
	input		[7:0]	Sobel_Threshold		//Sobel Threshold for image edge detect
);

//------------------------------------------------------------------------
//模块流程：串行灰度像素输入 → 3×3邻域矩阵生成 → 水平梯度（Gx）计算 
//→ 垂直梯度（Gy）计算 → 梯度模值（√(Gx²+Gy²)）求解 → 阈值判断 → 二值边缘输出
//------------------------------------------------------------------------
//lab 1 Generate 8Bit 3X3 Matrix for Video Image Processor.
	//Image data has been processd
wire				matrix_frame_vsync;	//Prepared Image data vsync valid signal
wire				matrix_frame_href;	//Prepared Image data href vaild  signal
wire				matrix_frame_clken;	//Prepared Image data output/capture enable clock	
wire		[7:0]	matrix_p11, matrix_p12, matrix_p13;	//3X3 Matrix output
wire		[7:0]	matrix_p21, matrix_p22, matrix_p23;
wire		[7:0]	matrix_p31, matrix_p32, matrix_p33;
VIP_Matrix_Generate_3X3_8Bit	
#(
	.IMG_HDISP	(IMG_HDISP),	//640*480
	.IMG_VDISP	(IMG_VDISP)
)
u_VIP_Matrix_Generate_3X3_8Bit
(
	//global clock
	.clk					(clk),  				//cmos video pixel clock
	.rst_n					(rst_n),				//global reset

	//Image data prepred to be processd
	.per_frame_vsync		(per_frame_vsync),		//Prepared Image data vsync valid signal
	.per_frame_href			(per_frame_href),		//Prepared Image data href vaild  signal
	.per_frame_clken		(per_frame_clken),		//Prepared Image data output/capture enable clock
	.per_img_Y				(per_img_Y),			//Prepared Image brightness input

	//Image data has been processd
	.matrix_frame_vsync		(matrix_frame_vsync),	//Processed Image data vsync valid signal
	.matrix_frame_href		(matrix_frame_href),	//Processed Image data href vaild  signal
	.matrix_frame_clken		(matrix_frame_clken),	//Processed Image data output/capture enable clock	
	.matrix_p11(matrix_p11),	.matrix_p12(matrix_p12), 	.matrix_p13(matrix_p13),	//3X3 Matrix output
	.matrix_p21(matrix_p21), 	.matrix_p22(matrix_p22), 	.matrix_p23(matrix_p23),
	.matrix_p31(matrix_p31), 	.matrix_p32(matrix_p32), 	.matrix_p33(matrix_p33)
);

//Sobel Parameter
//         Gx                  Gy				  Pixel
// [   -1  0   +1  ]   [   +1  +2   +1 ]     [   P11  P12   P13 ]
// [   -2  0   +2  ]   [   0   0    0  ]     [   P21  P22   P23 ]
// [   -1  0   +1  ]   [   -1  -2   -1 ]     [   P31  P32   P33 ]

// localparam	P11 = 8'd15,	P12 = 8'd94,	P13 = 8'd136;
// localparam	P21 = 8'd31,	P22 = 8'd127,	P23 = 8'd231;
// localparam	P31 = 8'd44,	P32 = 8'd181,	P33 = 8'd249;
//Caculate horizontal Grade with |abs|
//Step 1-2：Gx值越大，说明当前像素左右亮度差异越明显，对应垂直边缘
reg	[9:0]	Gx_temp1;	//postive result 正权重：1xp13+2xp23+1xp33
reg	[9:0]	Gx_temp2;	//negetive result 负权重：1xp11+2xp21+1xp31
reg	[9:0]	Gx_data;	//Horizontal grade data Gx绝对值（水平梯度）
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		Gx_temp1 <= 0;
		Gx_temp2 <= 0;
		Gx_data <= 0;
		end
	else
		begin
		Gx_temp1 <= matrix_p13 + (matrix_p23 << 1) + matrix_p33;	//postive result
		Gx_temp2 <= matrix_p11 + (matrix_p21 << 1) + matrix_p31;	//negetive result
		Gx_data <= (Gx_temp1 >= Gx_temp2) ? Gx_temp1 - Gx_temp2 : Gx_temp2 - Gx_temp1;
		end
end

//---------------------------------------
//Caculate vertical Grade with |abs|
//Step 1-2
reg	[9:0]	Gy_temp1;	//postive result:1xp11+2xp12+1xp13
reg	[9:0]	Gy_temp2;	//negetive result:1xp31+2xp32+1xp33
reg	[9:0]	Gy_data;	//Vertical grade data
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		Gy_temp1 <= 0;
		Gy_temp2 <= 0;
		Gy_data <= 0;
		end
	else
		begin
		Gy_temp1 <= matrix_p11 + (matrix_p12 << 1) + matrix_p13;	//postive result
		Gy_temp2 <= matrix_p31 + (matrix_p32 << 1) + matrix_p33;	//negetive result
		Gy_data <= (Gy_temp1 >= Gy_temp2) ? Gy_temp1 - Gy_temp2 : Gy_temp2 - Gy_temp1;
		end
end

//---------------------------------------
//Caculate the square of distance = (Gx^2 + Gy^2)
//Step 3
reg	[20:0]	Gxy_square;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		Gxy_square <= 0;
	else
		Gxy_square <= Gx_data * Gx_data + Gy_data * Gy_data;
end

//---------------------------------------
//Caculate the distance of P5 = (Gx^2 + Gy^2)^0.5
//Step 4
wire	[10:0]	Dim;
SQRT	u_SQRT
(
	.radical	(Gxy_square),
	.q			(Dim),
	.remainder	()
);
//Dim越大，边缘越强
//---------------------------------------
//Compare and get the Sobel_data
//Step 5
reg	post_img_Bit_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		post_img_Bit_r <= 1'b0;	//Default None
	else if(Dim >= Sobel_Threshold)
		post_img_Bit_r <= 1'b1;	//Edge Flag
	else
		post_img_Bit_r <= 1'b0;	//Not Edge
end


//------------------------------------------
//lag 5 clocks signal sync  
reg	[4:0]	per_frame_vsync_r;
reg	[4:0]	per_frame_href_r;	
reg	[4:0]	per_frame_clken_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		per_frame_vsync_r <= 0;
		per_frame_href_r <= 0;
		per_frame_clken_r <= 0;
		end
	else
	//每拍写入新信号，旧信号右移，延时5拍
		begin
		per_frame_vsync_r 	<= 	{per_frame_vsync_r[3:0], 	matrix_frame_vsync};
		per_frame_href_r 	<= 	{per_frame_href_r[3:0], 	matrix_frame_href};
		per_frame_clken_r 	<= 	{per_frame_clken_r[3:0], 	matrix_frame_clken};
		end
end
assign	post_frame_vsync 	= 	per_frame_vsync_r[4];
assign	post_frame_href 	= 	per_frame_href_r[4];
assign	post_frame_clken 	= 	per_frame_clken_r[4];
assign	post_img_Bit		=	post_frame_href ? post_img_Bit_r : 1'b0;

endmodule
