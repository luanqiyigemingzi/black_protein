module top(
	input                       clk,        // 系统主时钟输入
	input                       rst_n,      // 系统复位信号，低电平有效
 
    output			vga_out_hs,    // VGA行同步信号输出
    output			vga_out_vs,    // VGA场同步信号输出
//    output			vga_out_de,    // VGA数据使能信号输出（注释掉）
    output	[11:0]	vga_data,      // VGA显示数据输出 [11:0]
    //hdmi接口                         
	//HDMI
	output			HDMI_CLK_P,    // HDMI时钟差分信号正端
	output			HDMI_D2_P,     // HDMI数据2差分信号正端
	output			HDMI_D1_P,     // HDMI数据1差分信号正端
	output			HDMI_D0_P,     // HDMI数据0差分信号正端
	//摄像头接口                       
    input                 cam_pclk     ,  // 摄像头数据像素时钟输入
    input                 cam_vsync    ,  // 摄像头场同步信号输入
    input                 cam_href     ,  // 摄像头行同步信号输入
    input   [7:0]         cam_data     ,  // 摄像头数据输入 [7:0]
    output                cam_rst_n    ,  // 摄像头复位信号输出，低电平有效
    output                cam_pwdn     ,  // 摄像头电源模式控制：0-正常模式，1-休眠模式
    output                cam_scl      ,  // 摄像头SCCB串行时钟线
    inout                 cam_sda        // 摄像头SCCB串行数据线（双向）
);

// 参数定义
parameter MEM_DATA_BITS         = 32  ;            // 外部存储器用户接口数据位宽
parameter ADDR_BITS             = 21  ;            // 外部存储器用户接口地址位宽
parameter BUSRT_BITS            = 10  ;            // 外部存储器用户接口突发传输位宽
                               
parameter  V_CMOS_DISP = 11'd768;                  // CMOS垂直显示分辨率（行数）
parameter  H_CMOS_DISP = 11'd1024;                 // CMOS水平显示分辨率（列数）	
parameter  TOTAL_H_PIXEL = H_CMOS_DISP + 12'd1216; // CMOS总水平像素（显示+消隐）
parameter  TOTAL_V_PIXEL = V_CMOS_DISP + 12'd504;  // CMOS总垂直像素（显示+消隐）										   
							   

// SDRAM控制信号
wire Sdr_init_done;        // SDRAM初始化完成标志
wire Sdr_init_ref_vld;     // SDRAM初始化刷新有效
wire Sdr_busy;             // SDRAM忙信号

// VGA显示信号
wire    vga_out_de;        // VGA数据使能信号
wire                            read_req;           // 读请求信号
wire                            read_req_ack;       // 读请求应答信号
wire                            read_en;            // 读使能信号
wire                            write_en;           // 写使能信号
wire                            write_req;          // 写请求信号
wire                            write_req_ack;      // 写请求应答信号
wire                            sd_card_clk;        // SD卡控制器时钟（未使用）
wire                            ext_mem_clk;        // 外部存储器时钟
wire                            ext_mem_clk_sft;    // 外部存储器移相时钟

// 视频时序信号
wire                            video_clk;          // 视频像素时钟
wire							hdmi_5x_clk;        // HDMI 5倍频时钟
wire                            hs;                 // 行同步信号
wire                            vs;                 // 场同步信号
wire 							de;                 // 数据使能信号
wire[23:0]                      vout_data;          // 视频输出数据 [23:0]
//wire[3:0]                       state_code;        // 状态码（注释掉）
//wire[6:0]                       seg_data_0;        // 七段数码管数据（注释掉）

// 读写时钟信号
wire									  write_clk;    // 写时钟
wire									  read_clk;     // 读时钟

// 视频读取控制信号
wire                            video_read_req;       // 视频读请求
wire                            video_read_req_ack;   // 视频读请求应答
wire                            video_read_en;        // 视频读使能
wire[31:0]                      video_read_data;      // 视频读取数据 [31:0]

// 摄像头写入控制信号
wire                            cam_write_en;         // 摄像头写使能
wire[31:0]                      cam_write_data;       // 摄像头写入数据 [31:0]
wire                            cam_write_req;        // 摄像头写请求
wire                            cam_write_req_ack;    // 摄像头写请求应答

// SDRAM应用层接口信号
wire App_rd_en;                          // 应用层读使能
wire [ADDR_BITS-1:0] App_rd_addr;        // 应用层读地址
wire Sdr_rd_en;                          // SDRAM读使能
wire [MEM_DATA_BITS - 1 : 0]Sdr_rd_dout; // SDRAM读数据输出

wire App_wr_en;                          // 应用层写使能
wire [ADDR_BITS-1:0] App_wr_addr;        // 应用层写地址
wire [MEM_DATA_BITS - 1 : 0]App_wr_din;  // 应用层写数据输入
wire [3:0] App_wr_dm;                    // 应用层数据掩码

// 摄像头帧信号
wire cmos_frame_vsync;       // CMOS帧场同步
wire cmos_frame_href;        // CMOS帧行同步
wire cmos_frame_valid;       // CMOS帧数据有效
wire [15:0] cmos_wr_data;    // CMOS写入数据 [15:0]

// VGA信号分配
assign vga_out_hs = hs;      // 行同步信号输出
assign vga_out_vs = vs;      // 场同步信号输出
assign vga_out_de = de;      // 数据使能信号输出
// VGA数据格式转换：从24位RGB转换为12位RGB（取每个颜色分量的高4位）
assign vga_data = {vout_data[23:20],vout_data[15:12],vout_data[7:4]};

//assign vga_out_r  = vout_data[15:11];  // VGA红色分量（注释掉）
//assign vga_out_g  = vout_data[10:5];   // VGA绿色分量（注释掉）
//assign vga_out_b  = vout_data[4:0];    // VGA蓝色分量（注释掉）
assign sdram_clk = ext_mem_clk;          // SDRAM时钟分配

// 系统锁相环实例：生成SD卡控制器时钟和SDRAM控制器时钟
sys_pll sys_pll_m0(
	.refclk                     (clk),              // 参考时钟输入
	.clk0_out                   (ext_mem_clk),      // 输出时钟0：外部存储器时钟
	.clk1_out                   (ext_mem_clk_sft),  // 输出时钟1：外部存储器移相时钟
    .reset						(1'b0)              // 复位信号（固定为0）
    );

// 视频锁相环实例：生成视频像素时钟
video_pll video_pll_m0(
	.refclk                     (clk),              // 参考时钟输入
	.clk0_out                   (video_clk),        // 输出时钟0：视频像素时钟
    .clk1_out					(hdmi_5x_clk),      // 输出时钟1：HDMI 5倍频时钟
    .reset						(1'b0)              // 复位信号（固定为0）
	);

// OV5640摄像头驱动模块实例
ov5640_dri u_ov5640_dri(
    .clk               (clk),              // 系统时钟
    .rst_n             (rst_n),            // 系统复位，低电平有效

    .cam_pclk          (cam_pclk ),        // 摄像头像素时钟
    .cam_vsync         (cam_vsync),        // 摄像头场同步
    .cam_href          (cam_href ),        // 摄像头行同步
    .cam_data          (cam_data ),        // 摄像头数据
    .cam_rst_n         (cam_rst_n),        // 摄像头复位输出
    .cam_pwdn          (cam_pwdn ),        // 摄像头电源模式控制
    .cam_scl           (cam_scl  ),        // 摄像头SCCB时钟
    .cam_sda           (cam_sda  ),        // 摄像头SCCB数据
    
    .capture_start     (Sdr_init_done),    // 捕获开始信号（SDRAM初始化完成）
    .cmos_h_pixel      (H_CMOS_DISP),      // CMOS水平像素数
    .cmos_v_pixel      (V_CMOS_DISP),      // CMOS垂直像素数
    .total_h_pixel     (TOTAL_H_PIXEL),    // 总水平像素数
    .total_v_pixel     (TOTAL_V_PIXEL),    // 总垂直像素数
    .cmos_frame_vsync  (cmos_frame_vsync), // CMOS帧场同步输出
    .cmos_frame_href   (cmos_frame_href),  // CMOS帧行同步输出
    .cmos_frame_valid  (cmos_frame_valid), // CMOS帧数据有效输出
    .cmos_frame_data   (cmos_wr_data)      // CMOS帧数据输出
    );   

// OV5640数据延迟模块实例
ov5640_delay u_ov5640_delay(
    .clk               (cam_pclk),         // 摄像头像素时钟
    .rst_n             (rst_n),            // 系统复位，低电平有效
    .cmos_frame_vsync  (cmos_frame_vsync), // CMOS帧场同步输入
    .cmos_frame_href   (cmos_frame_href),  // CMOS帧行同步输入
    .cmos_frame_valid  (cmos_frame_valid), // CMOS帧数据有效输入
    .cmos_wr_data   (cmos_wr_data),        // CMOS写入数据输入
    
    .cam_write_req(cam_write_req),         // 摄像头写请求输出
    .cam_write_req_ack(cam_write_req_ack), // 摄像头写请求应答输入
    .cam_write_en(cam_write_en),           // 摄像头写使能输出
    .cam_write_data(cam_write_data)        // 摄像头写数据输出
);

// 中间视频时序信号
wire hs_0;      // 延迟前行同步
wire vs_0;      // 延迟前场同步
wire de_0;      // 延迟前数据使能

// 视频时序数据模块实例
video_timing_data video_timing_data_m0
(
	.video_clk                  (video_clk        ),  // 视频时钟
	.rst                        (~rst_n           ),  // 复位信号（高电平有效）
	.read_req                   (video_read_req   ),  // 读请求输入
	.read_req_ack               (video_read_req_ack), // 读请求应答输出
	//.read_en                    (video_read_en    ),  // 读使能（注释掉）
	//.read_data                  (video_read_data  ),  // 读数据（注释掉）
	.hs                         (hs_0             ),  // 行同步输出
	.vs                         (vs_0             ),  // 场同步输出
	.de                         (de_0             )   // 数据使能输出
    

	//.vout_data                  (vout_data        )  // 视频输出数据（注释掉）
);

// 视频延迟模块实例
video_delay video_delay_m0
(
    .video_clk                  (video_clk        ),  // 视频时钟
	.rst                        (~rst_n           ),  // 复位信号（高电平有效）
    .read_en					(video_read_en    ),  // 读使能输入
    .read_data					(video_read_data[31:8]), // 读数据输入（取高24位）
    .hs                         (hs_0             ),  // 行同步输入
	.vs                         (vs_0             ),  // 场同步输入
	.de                         (de_0             ),  // 数据使能输入
	.hs_r                       (hs               ),  // 延迟后行同步输出
	.vs_r                       (vs               ),  // 延迟后场同步输出
	.de_r                       (de               ),  // 延迟后数据使能输出
	.vout_data					(vout_data        )   // 视频输出数据
);

// HDMI发送器模块实例
hdmi_tx #(.FAMILY("EG4"))	// 器件系列参数：EG4
 u3_hdmi_tx
	(
		.PXLCLK_I(video_clk),      // 像素时钟输入
		.PXLCLK_5X_I(hdmi_5x_clk), // 5倍像素时钟输入

		.RST_N (rst_n),            // 复位信号，低电平有效
		
		//VGA输入信号
		.VGA_HS (hs ),             // VGA行同步
		.VGA_VS (vs ),             // VGA场同步
		.VGA_DE (de ),             // VGA数据使能
		.VGA_RGB(vout_data),       // VGA RGB数据

		//HDMI输出信号
		.HDMI_CLK_P(HDMI_CLK_P),   // HDMI时钟差分正端
		.HDMI_D2_P (HDMI_D2_P ),   // HDMI数据2差分正端
		.HDMI_D1_P (HDMI_D1_P ),   // HDMI数据1差分正端
		.HDMI_D0_P (HDMI_D0_P )	   // HDMI数据0差分正端
		
	);

// 视频帧数据读写控制模块实例
frame_read_write frame_read_write_m0(
    .mem_clk					(ext_mem_clk),        // 存储器时钟
    .rst						(~rst_n),             // 复位信号（高电平有效）
    .Sdr_init_done				(Sdr_init_done),      // SDRAM初始化完成
    .Sdr_init_ref_vld			(Sdr_init_ref_vld),   // SDRAM初始化刷新有效
    .Sdr_busy					(Sdr_busy),           // SDRAM忙信号
    
    // SDRAM读接口
    .App_rd_en					(App_rd_en),          // 应用层读使能
    .App_rd_addr				(App_rd_addr),        // 应用层读地址
    .Sdr_rd_en					(Sdr_rd_en),          // SDRAM读使能
    .Sdr_rd_dout				(Sdr_rd_dout),        // SDRAM读数据输出
    
    // 视频读接口
    .read_clk                   (video_clk),          // 读时钟
	.read_req                   (video_read_req),     // 读请求
	.read_req_ack               (video_read_req_ack), // 读请求应答
	.read_finish                (                   ), // 读完成（未连接）
	.read_addr_0                (24'd0              ), // 读地址0（首帧基地址为0）
	.read_addr_1                (24'd0         ), // 读地址1（未使用）
	.read_addr_2                (24'd0              ), // 读地址2（未使用）
	.read_addr_3                (24'd0              ), // 读地址3（未使用）
	.read_addr_index            (2'd0               ), // 读地址索引（仅使用read_addr_0）
	.read_len                   (24'd786432         ), // 读数据长度（帧大小：1024*768）
	.read_en                    (video_read_en),        // 读使能
	.read_data                  (video_read_data),      // 读数据
    
    // SDRAM写接口
    .App_wr_en					(App_wr_en),          // 应用层写使能
    .App_wr_addr				(App_wr_addr),        // 应用层写地址
    .App_wr_din					(App_wr_din),         // 应用层写数据输入
    .App_wr_dm					(App_wr_dm),          // 应用层数据掩码
    
    // 摄像头写接口
    .write_clk                  (cam_pclk),           // 写时钟（摄像头像素时钟）
	.write_req                  (cam_write_req),      // 写请求
	.write_req_ack              (cam_write_req_ack),  // 写请求应答
	.write_finish               (                 ),  // 写完成（未连接）
	.write_addr_0               (24'd0            ),  // 写地址0
	.write_addr_1               (24'd0       ),  // 写地址1（未使用）
	.write_addr_2               (24'd0            ),  // 写地址2（未使用）
	.write_addr_3               (24'd0            ),  // 写地址3（未使用）
	.write_addr_index           (2'd0             ),  // 写地址索引（仅使用write_addr_0）
	.write_len                  (24'd786432       ),  // 写数据长度（帧大小：1024*768）
	.write_en                   (cam_write_en),       // 写使能
	.write_data                 (cam_write_data)      // 写数据
);

// SDRAM控制器模块实例
sdram U3
(
.Clk				(ext_mem_clk),      // 时钟输入
.Clk_sft			(ext_mem_clk_sft),  // 移相时钟输入
.Rst				(~rst_n),           // 复位信号（高电平有效）
    
.Sdr_init_done		(Sdr_init_done),    // SDRAM初始化完成输出
.Sdr_init_ref_vld	(Sdr_init_ref_vld), // SDRAM初始化刷新有效输出
.Sdr_busy			(Sdr_busy),         // SDRAM忙信号输出
    
// 应用层写接口
.App_wr_en			(App_wr_en),        // 应用层写使能输入
.App_wr_addr		(App_wr_addr),      // 应用层写地址输入
.App_wr_dm			(App_wr_dm),        // 应用层数据掩码输入
.App_wr_din			(App_wr_din),       // 应用层写数据输入
    
// 应用层读接口
.App_rd_en			(App_rd_en),        // 应用层读使能输入（数据请求）
.App_rd_addr		(App_rd_addr),      // 应用层读地址输入
.Sdr_rd_en			(Sdr_rd_en),        // SDRAM读使能输出（数据有效）
.Sdr_rd_dout		(Sdr_rd_dout)       // SDRAM读数据输出
);

endmodule