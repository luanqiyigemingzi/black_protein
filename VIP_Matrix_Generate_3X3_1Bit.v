//将串行输入的像素流转换成“当前像素+8个邻域像素”的3x3矩阵
//1位二值图像的3x3邻域矩阵生成模块
module VIP_Matrix_Generate_3X3_1Bit
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
	input				per_img_Bit,		//Processed Image Bit flag outout(1: Value, 0:inValid)

	//Image data has been processd
	output				matrix_frame_vsync,	//Prepared Image data vsync valid signal
	output				matrix_frame_href,	//Prepared Image data href vaild  signal
	output				matrix_frame_clken,	//Prepared Image data output/capture enable clock	
	output	reg			matrix_p11, matrix_p12, matrix_p13,	//3X3 Matrix output
	output	reg			matrix_p21, matrix_p22, matrix_p23,
	output	reg			matrix_p31, matrix_p32, matrix_p33
);


//Generate 3*3 matrix 
//sync row3_data with per_frame_clken & row1_data & raw2_data
wire	row1_data;	//frame data of the 1th row
wire	row2_data;	//frame data of the 2th row
reg		row3_data;	//frame data of the 3th row	当前行
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		row3_data <= 0;
	else 
		begin
		if(per_frame_clken)
			row3_data <= per_img_Bit;
		else
			row3_data <= row3_data;
		end	
end

//---------------------------------------
//module of shift ram for raw data
wire	shift_clk_en = per_frame_clken;
wire    rst_n_r = rst_n;
Line_Shift_RAM_1Bit 
#(
	.RAM_Length	(IMG_HDISP)
)
u_Line_Shift_RAM_1Bit
(
	.clock		(clk),
    .rst_n      (rst_n_r),
	.clken		(shift_clk_en),	//pixel enable clock
//	.aclr		(1'b0),

	.shiftin	(row3_data),	//Current data input	当前列的当前行，垂直方向第3行
	.taps0x		(row2_data),	//Last row data	当前列的前1行，垂直方向第2行
	.taps1x		(row1_data),	//Up a row data	当前列的前2行，垂直方向第1行
	.shiftout	()
);

//------------------------------------------
//lag 2 clocks signal sync  
reg	[1:0]	per_frame_vsync_r;
reg	[1:0]	per_frame_href_r;	
reg	[1:0]	per_frame_clken_r;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		per_frame_vsync_r <= 0;
		per_frame_href_r <= 0;
		per_frame_clken_r <= 0;
		end
	else
		begin
		per_frame_vsync_r 	<= 	{per_frame_vsync_r[0], 	per_frame_vsync};
		per_frame_href_r 	<= 	{per_frame_href_r[0], 	per_frame_href};
		per_frame_clken_r 	<= 	{per_frame_clken_r[0], 	per_frame_clken};
		end
end
//Give up the 1th and 2th row edge data caculate for simple process
//Give up the 1th and 2th point of 1 line for simple process
wire	read_frame_href		=	per_frame_href_r[0];	//RAM read href sync signal
wire	read_frame_clken	=	per_frame_clken_r[0];	//RAM read enable
assign	matrix_frame_vsync 	= 	per_frame_vsync_r[1];
assign	matrix_frame_href 	= 	per_frame_href_r[1];
assign	matrix_frame_clken 	= 	per_frame_clken_r[1];


//----------------------------------------------------------------------------
//----------------------------------------------------------------------------
/******************************************************************************
					----------	Convert Matrix	----------
				[ P31 -> P32 -> P33 -> ]	--->	[ P11 P12 P13 ]	
				[ P21 -> P22 -> P23 -> ]	--->	[ P21 P22 P23 ]
				[ P11 -> P12 -> P11 -> ]	--->	[ P31 P32 P33 ]
******************************************************************************/
//---------------------------------------------------------------------------
//---------------------------------------------------
/***********************************************
	(1)	Read data from Shift_RAM
	(2) Caculate the Sobel
	(3) Steady data after Sobel generate
************************************************/
//wire	[2:0]	matrix_row1 = {matrix_p11, matrix_p12, matrix_p13};	//Just for test
//wire	[2:0]	matrix_row2 = {matrix_p21, matrix_p22, matrix_p23};
//wire	[2:0]	matrix_row3 = {matrix_p31, matrix_p32, matrix_p33};
//列计数器
reg [9:0] x_cnt;
always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        x_cnt <= 10'd0;
    else if(per_frame_clken) begin
        if(x_cnt < IMG_HDISP - 1)
            x_cnt <= x_cnt + 1'b1;
        else
            x_cnt <= 10'd0;
    end
end

//行计数器
reg [9:0] row_cnt;
always@(posedge clk or negedge rst_n)begin
    if(!rst_n)
        row_cnt <= 10'd0;
    else if (per_frame_clken)begin
        if((row_cnt == IMG_VDISP-1)&&(x_cnt==IMG_HDISP-1))
            row_cnt <= 10'd0;
        else if(x_cnt == IMG_HDISP-1'd1)
            row_cnt <= row_cnt + 1'b1;
    end
    else
        row_cnt <= row_cnt;
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		begin
		{matrix_p11, matrix_p12, matrix_p13} <= 3'b0;
		{matrix_p21, matrix_p22, matrix_p23} <= 3'b0;
		{matrix_p31, matrix_p32, matrix_p33} <= 3'b0;
		end
	else if(read_frame_href)
		begin
		if(read_frame_clken)	//Shift_RAM data read clock enable
			begin
                if(row_cnt < 2)begin
                    {matrix_p11, matrix_p12, matrix_p13} <= 3'd0;
                    {matrix_p21, matrix_p22, matrix_p23} <= 3'd0;
                    {matrix_p31, matrix_p32, matrix_p33} <= {matrix_p32, matrix_p33, row3_data};
                end
                else begin
                    {matrix_p11, matrix_p12, matrix_p13} <= {matrix_p12, matrix_p13, row1_data};	//1th shift input
			        {matrix_p21, matrix_p22, matrix_p23} <= {matrix_p22, matrix_p23, row2_data};	//2th shift input
			        {matrix_p31, matrix_p32, matrix_p33} <= {matrix_p32, matrix_p33, row3_data};	//3th shift input
                end
			end
		else
			begin
			{matrix_p11, matrix_p12, matrix_p13} <= {matrix_p11, matrix_p12, matrix_p13};
			{matrix_p21, matrix_p22, matrix_p23} <= {matrix_p21, matrix_p22, matrix_p23};
			{matrix_p31, matrix_p32, matrix_p33} <= {matrix_p31, matrix_p32, matrix_p33};
			end	
		end
	else
		begin
		{matrix_p11, matrix_p12, matrix_p13} <= 3'b0;
		{matrix_p21, matrix_p22, matrix_p23} <= 3'b0;
		{matrix_p31, matrix_p32, matrix_p33} <= 3'b0;
		end
end

endmodule
