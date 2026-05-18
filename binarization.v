
module binarization(
    input               clk             ,   // 时钟信号
    input               rst_n           ,   // 复位信号（低有效）

	input				per_frame_vsync,    //输入帧的场同步信号
	input				per_frame_href ,	//输入帧的行同步信号
	input				per_frame_clken,    //输入帧的像素时钟使能信号
	input		[7:0]	per_img_Y,		    //输入的灰度图像像素数据（Y，0~255）

	output	reg 		post_frame_vsync,	
	output	reg 		post_frame_href ,	
	output	reg 		post_frame_clken,	
	output	reg 		post_img_Bit,		//二值化后的像素数据

	input		[7:0]	Binary_Threshold    //二值化阈值0~255
);


//二值化（像素转换，post_img_Bit=1表示白，0表示黑）
always @(posedge clk or negedge rst_n) begin
    if(!rst_n)
        post_img_Bit <= 1'b0;
    else begin
		if(per_img_Y > Binary_Threshold)  //阈值比较
			post_img_Bit <= 1'b1;
		else
			post_img_Bit <= 1'b0;
	end
end

//同步信号传递（时序对齐）
always@(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        post_frame_vsync <= 1'd0;
        post_frame_href  <= 1'd0;
        post_frame_clken <= 1'd0;
    end
    else begin
        post_frame_vsync <= per_frame_vsync;
        post_frame_href  <= per_frame_href ;
        post_frame_clken <= per_frame_clken;
    end
end

endmodule
