module Line_Shift_RAM_8Bit
#(
    parameter   RAM_Length = 10'd640  // 图像水平分辨率（每行像素数）
)
(
    input                   clock           ,  // 工作时钟（与像素时钟同步）
    input                   rst_n           ,
    input                   clken           ,  // 像素使能时钟（有效像素期间高）
    input       [7:0]       shiftin         ,  // 当前行像素输入（垂直方向第3行）
    output      [7:0]       taps0x          ,  // 延迟1行输出（垂直方向第2行）
    output      [7:0]       taps1x          ,  // 延迟2行输出（垂直方向第1行）
    output                  shiftout           // 未使用，悬空
);


//lag 3 像素坐标计数（定位像素位置）
//对输入的像素进行“行/场”方向计数，得到其纵横坐标
reg [9:0]  	x_cnt;
reg [9:0]   y_cnt;

always@(posedge clock or negedge rst_n)
begin
	if(!rst_n)
		begin
			x_cnt <= 10'd0;
			y_cnt <= 10'd0;
		end
	else if(clken) begin	//像素使能有效时计数
		if(x_cnt < RAM_Length - 1) begin
			x_cnt <= x_cnt + 1'b1;
			y_cnt <= y_cnt;
		end
		else begin
			x_cnt <= 10'd0;
			y_cnt <= y_cnt + 1'b1;
		end
	end
    else begin
        x_cnt  <= x_cnt;
        y_cnt <= y_cnt;
    end
end

//--------------------------------------------------------
reg clock_r;
always @(posedge clock or negedge rst_n)begin
    if(!rst_n)begin
        clock_r <= 1'b0;
    end
    else begin
        clock_r <= clock;
    end
end

//wire [7:0] taps0x;
//wire [7:0] taps1x;
ram_8bit u1_ram_8bit(
    .dia                               (shiftin                   ),
    .addra                             (x_cnt                   ),
    .cea                               (clken                   ),
    .clka                              (clock                   ),
   
    .dob                               (taps0x                  ),
    .addrb                             (x_cnt                   ),
    .ceb                               (1'b1                 	),
    .oceb                              (1'b1                 	),
    .clkb                              (clock                	),
    .rstb                              (~rst_n                 	) 
);

ram_8bit u2_ram_8bit(
    .dia                               (taps0x                  ),
    .addra                             (x_cnt                   ),
    .cea                               (clken                   ),
    .clka                              (clock                   ),
   
    .dob                               (taps1x                  ),
    .addrb                             (x_cnt                   ),
    .ceb                               (1'b1                    ),
    .oceb                              (1'b1                    ),
    .clkb                              (clock                   ),
    .rstb                              (~rst_n                   ) 
);

assign shiftout = 8'b0;

endmodule
