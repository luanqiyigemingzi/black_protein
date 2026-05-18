`timescale 1ns / 1ps
`define UDP_LOOP_BACK        // 定义UDP回环模式
module udp_data(
        input               key1,           // 按键1输入
        input               key2,           // 按键2输入
        input               key3,
        input               clk_50,         // 50MHz时钟输入
                input                chuankou_rx          ,
        input               phy1_rgmii_rx_clk,    // PHY1 RGMII接收时钟
        input               phy1_rgmii_rx_ctl,    // PHY1 RGMII接收控制
        input [3:0]         phy1_rgmii_rx_data,   // PHY1 RGMII接收数据
                                
        output wire         phy1_rgmii_tx_clk,    // PHY1 RGMII发送时钟
        output wire         phy1_rgmii_tx_ctl,    // PHY1 RGMII发送控制
        output wire [3:0]   phy1_rgmii_tx_data,   // PHY1 RGMII发送数据
        output            [3:0] led_data ,        // LED数据输出
        output            [15:0] dled,       // 数码管显示输出  

	//摄像头接口                       
    input                 cam_pclk     ,  //cmos 数据像素时钟
    input                 cam_vsync    ,  //cmos 场同步信号
    input                 cam_href     ,  //cmos 行同步信号
    input   [7:0]         cam_data     ,  //cmos 数据
    output                cam_rst_n    ,  //cmos 复位信号，低电平有效
    output                cam_pwdn     ,  //电源休眠模式选择 0：正常模式 1：电源休眠模式
    output                cam_scl      ,  //cmos SCCB_SCL线
    inout                 cam_sda      ,  //cmos SCCB_SDA线  
          // SD卡接口
      input  sd_miso,                   // SD卡SPI主输入从输出
      output sd_clk,                    // SD卡SPI时钟
      output sd_cs,                     // SD卡SPI片选
      output sd_mosi,                   // SD卡SPI主输出从输入
      
              // HDMI输出接口
        output          HDMI_CLK_P,                  // HDMI时钟正极
        output          HDMI_D2_P,                   // HDMI数据2正极
        output          HDMI_D1_P,                   // HDMI数据1正极
        output          HDMI_D0_P                    // HDMI数据0正极
);
wire key_flag;
wire key_state;
//按键消抖
key_filter key_filter(
	.clk(clk_50),
	.reset_n(key1),
	.key_in(key3),
	.key_flag(key_flag),
	.key_state(key_state)
);
assign key_down=(key_flag&&!key_state);
//串口
reg [7:0]current_mode;       // 当前模式寄存器
wire [7:0]po_data;
//串口通信
uart_rx uart_rx
(   //输入输出端口声明
 .sys_clk (clk_50)   ,
 .sys_rst_n (key1)  ,//低电平有效
 .rx(chuankou_rx)          ,
 .po_data(po_data)     ,
 .po_flag(po_flag)     
);
always@(posedge clk_50 or negedge key1)
if (!key1)
current_mode<=MODE_IDLE_LEDS;
else if(po_flag==1) current_mode<=po_data;
else 
current_mode<=current_mode;
// --- 模式定义 ---
parameter MODE_IDLE_LEDS  = 8'd1;
parameter MODE_HDMI_RX    = 8'd2;
parameter MODE_SDCARD_TX  = 8'd3;
parameter MODE_CAMERA_TX  = 8'd4; // 预留给摄像头
//
//模式切换
// --- 模式定义 ---
/*
parameter MODE_IDLE_LEDS  = 2'b00;
parameter MODE_HDMI_RX    = 2'b01;
parameter MODE_SDCARD_TX  = 2'b10;
parameter MODE_CAMERA_TX  = 2'b11; // 预留给摄像头

reg [1:0] current_mode;       // 当前模式寄存器
always @(posedge clk_50 or negedge key1) begin
    if (~key1) begin
        current_mode <= MODE_IDLE_LEDS; // 复位到空闲模式
    end else if (key_down) begin
        // 当检测到按键，切换到下一个模式
        case (current_mode)
            MODE_IDLE_LEDS: current_mode <= MODE_HDMI_RX;
            MODE_HDMI_RX:   current_mode <= MODE_SDCARD_TX;
            MODE_SDCARD_TX: current_mode <= MODE_CAMERA_TX;
            MODE_CAMERA_TX: current_mode <= MODE_IDLE_LEDS;
            default:        current_mode <= MODE_IDLE_LEDS;
        endcase
    end
end
*/
//发送数据逻辑控制
// --- 根据当前模式生成控制信号 ---
wire hdmi_app_enable;
wire sd_system_enable;
wire camera_system_enable; 

assign hdmi_app_enable      = (current_mode == MODE_HDMI_RX);
assign sd_system_enable     = (current_mode == MODE_SDCARD_TX);
assign camera_system_enable = (current_mode == MODE_CAMERA_TX);

// --- 控制数据发送路径 (使用多路选择器 MUX) ---
// 因为SD卡和摄像头都想往UDP协议栈里发送数据，它们共享一个接口，必须用MUX选择其一。
reg         app_tx_data_valid_mux;
reg  [7:0]  app_tx_data_mux;
reg  [15:0] udp_data_length_mux;
//sd卡信号声明
wire app_tx_request_sd;
wire app_tx_data_valid_sd; 
wire [7:0]app_tx_data_sd;       
wire [15:0]udp_data_length_sd;   
//摄像头信号声明
wire app_tx_request_cam;
wire app_tx_data_valid_cam;
wire [7:0]app_tx_data_cam;      
wire [15:0]udp_data_length_cam;  

// (假设 udp_loopback 和 camera_streamer 的输出信号有 _sd 和 _cam 后缀)
always @(*) begin
    case(current_mode)
        MODE_SDCARD_TX: begin
            app_tx_data_valid_mux = app_tx_data_valid_sd;
            app_tx_data_mux       = app_tx_data_sd;
            udp_data_length_mux   = udp_data_length_sd;
            app_tx_request =app_tx_request_sd;
        end
        MODE_CAMERA_TX: begin
            app_tx_data_valid_mux = app_tx_data_valid_cam;
            app_tx_data_mux       = app_tx_data_cam;
            udp_data_length_mux   = udp_data_length_cam;
            app_tx_request=app_tx_request_cam;
        end
        default: begin // 在其他模式下，发送路径为无效
            app_tx_data_valid_mux = 1'b0;
            app_tx_data_mux       = 8'd0;
            udp_data_length_mux   = 16'd0;
            app_tx_request=1'b0;
        end
    endcase
end
//
  wire Go;   //initial enable
  reg [20:0] delay_cnt;

  //上电并复位完成20ms后再配置摄像头，所以从上电到开始配置应该是1.0034 + 20 = 21.0034ms
  //这里为了优化逻辑，简化比较器逻辑，直接使延迟比较值为24'h100800，是21.0125ms
always@(posedge clk_50 or negedge key1)
  if(!key1) // 1. 保持全局异步复位 (好习惯)
    delay_cnt <= 21'd0;
  
  else if(current_mode != MODE_CAMERA_TX) // 2. 将模式检查作为同步复位
    delay_cnt <= 21'd0;
  
  else if (delay_cnt == 21'h100800) // 3. 仅在摄像头模式下才开始计数
    delay_cnt <= 21'h100800;        // 计数到顶后保持
  
  else
    delay_cnt <= delay_cnt + 1'd1;  // 开始计数

  //当延时时间到，开始使能初始化模块对OV5640的寄存器进行写入  
  assign Go = (delay_cnt == 21'h1007ff) ? 1'b1 : 1'b0;
//摄像头初始化
parameter  V_CMOS_DISP = 11'd480;                  //CMOS分辨率--行
parameter  H_CMOS_DISP = 11'd640;                 //CMOS分辨率--列	
parameter  TOTAL_H_PIXEL = H_CMOS_DISP + 12'd800; //CMOS分辨率--行
parameter  TOTAL_V_PIXEL = V_CMOS_DISP + 12'd525;   
wire cam_init_done;
wire cmos_frame_vsync;
ov5640_dri u_ov5640_dri(
    .clk               (clk_50),
    .rst_n             ((current_mode==MODE_CAMERA_TX)),//低电平复位有效

    .cam_pclk          (cam_pclk ),
    .cam_vsync         (cam_vsync),
    .cam_href          (cam_href ),
    .cam_data          (cam_data ),
    .cam_rst_n         (cam_rst_n),
    .cam_pwdn          (cam_pwdn ),
    .cam_scl           (cam_scl  ),
    .cam_sda           (cam_sda  ),
    .capture_start(Go),
    .cam_init_done     (cam_init_done),
    .cmos_h_pixel      (H_CMOS_DISP),
    .cmos_v_pixel      (V_CMOS_DISP),
    .total_h_pixel     (TOTAL_H_PIXEL),
    .total_v_pixel     (TOTAL_V_PIXEL),
    .cmos_frame_vsync   (cmos_frame_vsync), // 帧开始脉冲
    .cmos_frame_href    (cmos_frame_href ), // 行开始脉冲
    .cmos_frame_valid   (cmos_frame_valid), // 像素有效
    .cmos_frame_data    (cmos_wr_data)  // 16 位 RGB565 数据    
);
//
wire [15:0]cmos_wr_data;
//图像处理
wire per_frame_vsync = cmos_frame_vsync;    
wire per_frame_href = cmos_frame_href;
wire per_frame_clken = cmos_frame_valid;


//--------------------------------------
//灰度转换

wire 			post0_frame_vsync;   
wire 			post0_frame_href ;   
wire 			post0_frame_clken;    
wire [7:0]	post0_img_Y      ;   
wire [7:0]	post0_img_Cb     ;   
wire [7:0]	post0_img_Cr     ;   

wire [7:0] per_img_red;
wire [7:0] per_img_green;
wire [7:0] per_img_blue;

assign per_img_blue = {cmos_wr_data[15:11],{3{cmos_wr_data[11]}}};
assign per_img_green = {cmos_wr_data[10:5],{2{cmos_wr_data[5]}}};
assign per_img_red = {cmos_wr_data[4:0],{3{cmos_wr_data[0]}}};

VIP_RGB888_YCbCr444	u_VIP_RGB888_YCbCr444
(
	//global clock
	.clk					(cam_pclk),					
	.rst_n				(rst_n),				

	//Image data prepred to be processd
	.per_frame_vsync	(per_frame_vsync),		
	.per_frame_href	    (per_frame_href),		
	.per_frame_clken	(per_frame_clken),		
	.per_img_red		(per_img_red),			
	.per_img_green		(per_img_green),		
	.per_img_blue		(per_img_blue),			
	
	//Image data has been processd
	.post_frame_vsync	(post0_frame_vsync),	
	.post_frame_href	(post0_frame_href),		
	.post_frame_clken	(post0_frame_clken),	
	.post_img_Y			(post0_img_Y ),			
	.post_img_Cb		(post0_img_Cb),			
	.post_img_Cr		(post0_img_Cr)			
);

//输出参数定义
wire [15:0] y_data;
assign y_data = {post0_img_Y[7:3],post0_img_Y[7:2],post0_img_Y[7:3]};

//----------------------------------------------------
//灰度图像中值滤波

wire 			post1_frame_vsync;   
wire 			post1_frame_href ;   
wire 			post1_frame_clken;    
wire [7:0]	post1_img_Y      ;   
wire [7:0]	post1_img_Cb     ;   
wire [7:0]	post1_img_Cr     ; 

VIP_Gray_Median_Filter
#(
    .IMG_HDISP (H_CMOS_DISP)        ,//640*480
    .IMG_VDISP (V_CMOS_DISP)       
)
(
    .clk                  (cam_pclk)     ,//100MHz
    .rst_n                (rst_n)     ,//global reset
                          
    .per_frame_vsync      (post0_frame_vsync)     ,//Prepared Image data vsync valid signal
    .per_frame_href       (post0_frame_href)     ,//Prepared Image data href vaild  signal
    .per_frame_clken      (post0_frame_clken)     ,//Prepared Image data output/capture enable clock
    .per_img_Y            (post0_img_Cb)     ,//Prepared Image brightness input
                          
    .post_frame_vsync     (post1_frame_vsync)     ,//Processed Image data vsync valid signal
    .post_frame_href      (post1_frame_href)     ,//Processed Image data href vaild  signal
    .post_frame_clken     (post1_frame_clken)     ,//Processed Image data output/capture enable clock
    .post_img_Y           (post1_img_Cb)      //Processed Image brightness input
);
//输出参数定义
wire [15:0] f_data;
assign f_data = {post1_img_Y[7:3],post1_img_Y[7:2],post1_img_Y[7:3]};//灰度中值滤波，
//显示几种效果：1灰度处理2高斯滤波3腐蚀效果4边缘检测5膨胀效果6车牌展示

//--------------------------------------
//二值化

wire			post2_frame_vsync;
wire			post2_frame_href ;
wire			post2_frame_clken;
wire	     	post2_img_Bit    ;

binarization u_binarization (
	.clk						(cam_pclk),  				
	.rst_n					(rst_n),				

	//Image data prepred to be processd
	.per_frame_vsync		(post1_frame_vsync),	
	.per_frame_href		    (post1_frame_href),		
	.per_frame_clken		(post1_frame_clken),	
	.per_img_Y				(post1_img_Cb),			
    
	//Image data has been processd
	.post_frame_vsync		(post2_frame_vsync),	
	.post_frame_href		(post2_frame_href),		
	.post_frame_clken		(post2_frame_clken),	
	.post_img_Bit			(post2_img_Bit),		
	
	//二值化阈值 
	.Binary_Threshold		(150)				
);
//输出参数定义
wire [15:0] b_data;
assign b_data = post2_img_Bit ? 16'hFFFF : 16'h0000;

//--------------------------------------
//腐蚀

wire			post3_frame_vsync;	
wire			post3_frame_href;	
wire			post3_frame_clken;	
wire			post3_img_Bit;		

VIP_Bit_Erosion_Detector
#(
	.IMG_HDISP	(H_CMOS_DISP),	//640*480
	.IMG_VDISP	(V_CMOS_DISP)
)
u_VIP_Bit_Erosion_Detector
(
	//global clock
	.clk						(cam_pclk),  				
	.rst_n					    (rst_n),				

	//Image data prepred to be processd
	.per_frame_vsync		(post2_frame_vsync),	
	.per_frame_href		    (post2_frame_href),		
	.per_frame_clken		(post2_frame_clken),	
	.per_img_Bit			(post2_img_Bit),		

	//Image data has been processd
	.post_frame_vsync		(post3_frame_vsync),	
	.post_frame_href		(post3_frame_href),		
	.post_frame_clken		(post3_frame_clken),	
	.post_img_Bit			(post3_img_Bit)			
);
//输出参数定义
wire [15:0] e_data;
assign e_data = post3_img_Bit ? 16'hFFFF : 16'h0000;

//--------------------------------------
//算法--Sobel边缘检测

wire			post4_frame_vsync;	 
wire			post4_frame_href;	 
wire			post4_frame_clken;	 
wire			post4_img_Bit;		 

VIP_Sobel_Edge_Detector #(
	.IMG_HDISP	(H_CMOS_DISP),	 
	.IMG_VDISP	(V_CMOS_DISP)
) u_VIP_Sobel_Edge_Detector (
    .clk                               (cam_pclk                       ),
    .rst_n                             (rst_n                     ),

	//Image data prepred to be processd
    .per_frame_vsync                   (post3_frame_vsync         ),
    .per_frame_href                    (post3_frame_href          ),
    .per_frame_clken                   (post3_frame_clken         ),
    .per_img_Y                         ({8{post3_img_Bit}}        ),

	//Image data has been processd
    .post_frame_vsync                  (post4_frame_vsync         ),
    .post_frame_href                   (post4_frame_href          ),
    .post_frame_clken                  (post4_frame_clken         ),
    .post_img_Bit                      (post4_img_Bit             ),
	
	//User interface
    .Sobel_Threshold                   (128                      ) 
);
//输出参数定义
wire [15:0] s_data;
assign s_data = post4_img_Bit ? 16'hFFFF : 16'h0000;

//-----------------------------------------------------------------
//--------------------------------------
//投影前先进行线条的膨胀，防止角度偏移1到2个像素

wire			post5_frame_vsync;	
wire			post5_frame_href;	
wire			post5_frame_clken;	
wire			post5_img_Bit;	
	
VIP_Bit_Dilation_Detector
#(
	.IMG_HDISP	(H_CMOS_DISP),	//640*480
	.IMG_VDISP	(V_CMOS_DISP)
)
u_VIP_Bit_Dilation_Detector
(
	//global clock
    .clk                               (cam_pclk                       ),
    .rst_n                             (rst_n                     ),

	//Image data prepred to be processd
    .per_frame_vsync                   (post4_frame_vsync         ),
    .per_frame_href                    (post4_frame_href          ),
    .per_frame_clken                   (post4_frame_clken         ),
    .per_img_Bit                       (post4_img_Bit             ),

	//Image data has been processd
    .post_frame_vsync                  (post5_frame_vsync         ),
    .post_frame_href                   (post5_frame_href          ),
    .post_frame_clken                  (post5_frame_clken         ),
    .post_img_Bit                      (post5_img_Bit             ) 
);


//--------------------------------------
//动态切换
reg     [5:0]   ns_cnt =6'd0     ;
reg     [9:0]   us_cnt =10'd0    ;
reg     [9:0]   ms_cnt =10'd0    ;
reg     [9:0]   s_cnt  =10'd0    ;
reg     [2:0]   shift_en =5'd0         ;
always@(posedge clk_50 or negedge rst_n)begin
    if(!rst_n) begin
        ns_cnt <= 6'd0;
        us_cnt <= 10'd0;
        ms_cnt <= 10'd0;
        s_cnt  <= 10'd0;
        shift_en <= 3'd0;
    end else begin
        if(ns_cnt < 6'd49) 
            ns_cnt <= ns_cnt + 1'b1;
        else begin
            ns_cnt <= 6'd0;
            if(us_cnt < 10'd999)
                us_cnt <= us_cnt + 1'b1;
            else begin
                us_cnt <= 10'd0;
                if(ms_cnt < 10'd999)
                    ms_cnt <= ms_cnt + 1'b1;
                else begin
                    ms_cnt <= 10'd0;
                    if(s_cnt < 10'd4)
                        s_cnt <= s_cnt + 1'b1;
                    else begin
                        s_cnt <= 10'd0;
                        if(shift_en < 3'd4)
                            shift_en <= shift_en + 1'b1;
                        else
                            shift_en <= 3'd0;
                    end
                end
            end
        end
    end
end

reg     [15:0]      post_frame_data_rrr ;
reg                 post_frame_vsync_rrr;
reg                 post_frame_href_rrr ;
reg                 post_frame_clken_rrr;
wire 	post_frame_vsync;
wire 	post_frame_href	;
wire 	post_frame_clken;
wire [15:0]	post_frame_data	;


always@(posedge clk_50 or negedge rst_n ) begin
    if(!rst_n) begin 
        post_frame_data_rrr <= 24'd0;
        post_frame_vsync_rrr<= 1'd0;
        post_frame_href_rrr <= 1'd0;
        post_frame_clken_rrr<= 1'd0;
    end else begin
        post_frame_vsync_rrr<= post4_frame_vsync;
        post_frame_href_rrr <= post4_frame_href	;
        post_frame_clken_rrr<=post4_frame_clken	; 
        case (shift_en)
//            3'd0:  post_frame_data_rrr <= {post4_img_red,post4_img_green,post4_img_blue}; 
//            3'd1:  post_frame_data_rrr <= {24{gray_bit[0]}};
//            3'd2:  post_frame_data_rrr <= {24{gray_bit[1]}};
//assign f_data = {post1_img_Y[7:3],post1_img_Y[7:2],post1_img_Y[7:3]};//灰度中值滤波，

 default:   // post_frame_data_rrr <= {post4_img_red,post4_img_green,post4_img_blue}; 
                post_frame_data_rrr <= f_data;
        endcase
    end
end
/*assign	post_frame_vsync	=  post1_frame_vsync_rrr	;                                  
assign	post_frame_href	    =  post1_frame_href_rrr	;                                  
assign	post_frame_clken	=  post1_frame_clken_rrr	;                                  
assign	post_frame_data		=  post1_frame_data_rrr  ;   
*/





//
//打包
  	// FIFO 写信号
	wire fifo_wrreq;
	wire fifo_aclr;
	wire [7:0] fifo_wrdata;
    // FIFO 读信号
    wire cam_fifo_rdreq;
    wire [7:0]cam_fifo_rddata;
    wire cam_fifo_empty;
    wire [13:0] cam_fifo_rdusedw;
    reg     app_tx_request;
    //测试
wire        udp_tx_ready_signal;       // (来自 u3_udp_ip_protocol_stack)
wire [13:0] fifo_rdusedw_full_width; // (来自 async_fifo, 假设 ADDR_WIDTH=13)
wire        fifo_is_full_enough;
wire        cam_fifo_wrreq_signal;     // (来自 Camera_ETH_Formator)
wire        cam_href_signal;           // (来自摄像头物理引脚)
/*
assign fifo_is_full_enough = (cam_fifo_rdusedw >= 1282);
assign led_data[0] = 1'd0;   // (条件1) UDP 栈就绪? (应为 1)
assign led_data[1] = (current_mode==MODE_CAMERA_TX);   // (条件2) FIFO 是否存够一包? (应为 1)
assign led_data[2] = Go; // (FIFO入口) Formatter 是否在写? (应闪烁/常亮)
assign led_data[3] = cam_vsync;       // (数据源) 摄像头 Href 信号 (应闪烁/常亮)
*/
	// 以太网图像行号编号逻辑（把图像打包成 UDP 载荷）
	Camera_ETH_Formator Camera_ETH_Formator(
	  .PCLK(cam_pclk),
	  .Rst_n((current_mode==MODE_CAMERA_TX)),//低电平复位
	  .Init_Done(cam_init_done),
	  .HREF(cam_href),
	  .VSYNC(cam_vsync),
	  .DATA(cam_data),
	  .fifo_aclr(fifo_aclr),
	  .wrdata(fifo_wrdata),
	  .wrreq(fifo_wrreq)
	);
async_fifo #(
    .DATA_WIDTH(8),
    .ADDR_WIDTH(13),
    .SHOWAHEAD_EN(1)
) 
u_cam_fifo (
    .reset(fifo_aclr),
     .wrclk(cam_pclk),
    .wren(fifo_wrreq),
    .wrdata(fifo_wrdata),
    .full(), 
    // 读侧 (连接到 Streamer)
    .rdclk(udp_clk), // 即 udp_clk
    .rden(cam_fifo_rdreq),
    .rddata(cam_fifo_rddata),
    .empty(cam_fifo_empty),
    .rdusedw(cam_fifo_rdusedw) 
);
// --- 实例化摄像头数据发送模块 ---

// (替换掉原来的 u2_udp_loopback)
camera_udp_streamer u_cam_streamer (
    // UDP 协议栈发送接口
    .app_tx_clk         (udp_clk),
    .reset              (current_mode!=MODE_CAMERA_TX),//高电平复位
    .udp_tx_ready       (udp_tx_ready),
    .app_tx_ack         (app_tx_ack),
    .app_tx_data        (app_tx_data_cam),
    .app_tx_data_request(app_tx_request_cam),
    .app_tx_data_valid  (app_tx_data_valid_cam),
    .udp_data_length    (udp_data_length_cam),

    // 摄像头数据 FIFO 读取接口
    .fifo_rddata        (cam_fifo_rddata),
    .fifo_empty         (cam_fifo_empty),
    .fifo_rdusedw       (cam_fifo_rdusedw), // 注意这里的位宽
    .fifo_rdreq         (cam_fifo_rdreq)
);
//

// 参数定义
parameter  DEVICE             = "EG4";              // 设备类型："PH1","EG4"
parameter  LOCAL_UDP_PORT_NUM = 16'd5000;           // 本地UDP端口号
parameter  LOCAL_IP_ADDRESS   = 32'hc0a80002;       // 本地IP地址 (192.168.0.2)
parameter  LOCAL_MAC_ADDRESS  = 48'h0123456789ab;   // 本地MAC地址
parameter  DST_UDP_PORT_NUM   = 16'd6102;           // 目标UDP端口号
parameter  DST_IP_ADDRESS     = 32'hc0a80003;       // 目标IP地址 (192.168.0.3)

// 应用层接收信号
wire         app_rx_data_valid;        // 应用层接收数据有效
wire [7:0]   app_rx_data;              // 应用层接收数据
wire [15:0]  app_rx_data_length;       // 应用层接收数据长度
wire [15:0]  app_rx_port_num;          // 应用层接收端口号

// 应用层发送信号
wire         udp_tx_ready;             // UDP发送就绪
wire         app_tx_ack;               // 应用层发送应答
wire         app_tx_data_request;      // 应用层发送数据请求
wire         app_tx_data_valid;        // 应用层发送数据有效
wire [7:0]   app_tx_data;              // 应用层发送数据
wire  [15:0] udp_data_length;          // UDP数据长度



// TEMAC信号
wire        tx_stop;                   // 发送停止
wire [7:0]  tx_ifg_val;                // 发送帧间隔值
wire        pause_req;                 // 暂停请求
wire [15:0] pause_val;                 // 暂停值
wire [47:0] pause_source_addr;         // 暂停源地址
wire [47:0] unicast_address;           // 单播地址
wire [19:0] mac_cfg_vector;            // MAC配置向量

wire        temac_tx_ready;            // TEMAC发送就绪
wire        temac_tx_valid;            // TEMAC发送有效
wire [7:0]  temac_tx_data;             // TEMAC发送数据
wire        temac_tx_sof;              // TEMAC发送帧起始
wire        temac_tx_eof;              // TEMAC发送帧结束

wire        temac_rx_ready;            // TEMAC接收就绪
wire        temac_rx_valid;            // TEMAC接收有效
wire [7:0]  temac_rx_data;             // TEMAC接收数据
wire        temac_rx_sof;              // TEMAC接收帧起始
wire        temac_rx_eof;              // TEMAC接收帧结束

wire        rx_correct_frame;          // 接收正确帧
wire        rx_error_frame;            // 接收错误帧
wire [1:0]  TRI_speed;                 // 三速模式

assign TRI_speed = 2'b10;              // 速度设置：千兆2'b10 百兆2'b01 十兆2'b00

// 时钟信号
wire        rx_clk_int;                // 接收时钟
wire        rx_clk_en_int;             // 接收时钟使能
wire        tx_clk_int;                // 发送时钟
wire        tx_clk_en_int;             // 发送时钟使能

wire        temac_clk;                 // TEMAC时钟
wire        udp_clk;                   // UDP时钟
wire        temac_clk90;               // TEMAC 90度相移时钟
wire        clk_125_out;               // 125MHz时钟输出
wire        clk_12_5_out;              // 12.5MHz时钟输出
wire        clk_1_25_out;              // 1.25MHz时钟输出
wire        rx_valid;                  // 接收有效
wire [7:0]  rx_data;                   // 接收数据
wire [7:0]  tx_data;                   // 发送数据
wire        tx_valid;                  // 发送有效
wire        tx_rdy;                    // 发送就绪
wire        tx_collision;              // 发送冲突
wire        tx_retransmit;             // 发送重传

// 复位和时钟控制
wire        reset_reg;           // 复位信号
wire        clk_25_out;                // 25MHz时钟输出
reg [7:0]   phy_reset_cnt='d0;         // PHY复位计数器
reg [7:0]   soft_reset_cnt=8'hff;      // 软复位计数器

// PHY复位控制逻辑
always @(posedge clk_25_out or negedge key1)
begin
    if(~key1)
        phy_reset_cnt<='d0;           // 按键1按下时复位计数器
    else if(phy_reset_cnt < 255)
        phy_reset_cnt<= phy_reset_cnt+1;  // 计数器递增
    else
        phy_reset_cnt<=phy_reset_cnt;     // 保持最大值
end

// 复位信号分配
assign  reset = ~key1 || reset_reg || (soft_reset_cnt != 'd0);  // 组合复位信号
assign  phy_reset = phy_reset_cnt[7];                          // PHY复位信号

// 软复位控制逻辑
always @(posedge udp_clk or negedge key1)
begin
    if(~key1)
        soft_reset_cnt<=8'hff;           // 按键1按下时设置软复位计数器
    else if(soft_reset_cnt > 0)
        soft_reset_cnt<= soft_reset_cnt-1;  // 计数器递减
    else
        soft_reset_cnt<=soft_reset_cnt;     // 保持0
end

//============================================================
// 参数配置逻辑 - 使用静态配置
//============================================================
// 配置客户端接口（初始默认值）
assign  tx_stop    = 1'b0;                           // 发送停止信号
assign  tx_ifg_val = 8'h00;                          // 发送帧间隔值
assign  pause_req  = 1'b0;                           // 暂停请求
assign  pause_val  = 16'h0;                          // 暂停值
assign  pause_source_addr = 48'h5af1f2f3f4f5;        // 暂停源地址

// 静态MAC地址配置
assign  unicast_address   = {   LOCAL_MAC_ADDRESS[7:0],     // 重组MAC地址字节序
                                LOCAL_MAC_ADDRESS[15:8],
                                LOCAL_MAC_ADDRESS[23:16],
                                LOCAL_MAC_ADDRESS[31:24],
                                LOCAL_MAC_ADDRESS[39:32],
                                LOCAL_MAC_ADDRESS[47:40]
                            };

// 静态MAC配置向量：地址过滤模式、流控配置、速度配置、接收器配置、发送器配置
assign  mac_cfg_vector    = {1'b0,2'b00,TRI_speed,8'b00000010,7'b0000010};

// 静态IP和端口配置 - 直接使用参数值
wire [31:0]  static_local_ip_address = LOCAL_IP_ADDRESS;           // 静态本地IP地址
wire         static_local_ip_address_valid = 1'b1;                 // 静态IP地址始终有效
wire [15:0]  static_local_udp_port_num = LOCAL_UDP_PORT_NUM;       // 静态本地UDP端口号
wire         static_local_udp_port_num_valid = 1'b1;               // 静态端口号始终有效


//-----------------------------------------------------

// 时钟生成和复位生成模块
clk_gen_rst_gen#(
    .DEVICE         (DEVICE     )  // 设备类型参数
) u_clk_gen(
    .reset          (~key1      ),  // 复位输入
    .clk_in         (clk_50     ),  // 50MHz时钟输入
    .rst_out        (reset_reg  ),  // 复位输出
    .clk_125_out0   (temac_clk  ),  // 125MHz时钟输出0
    .clk_125_out1   (clk_125_out),  // 125MHz时钟输出1
    .clk_125_out2   (temac_clk90),  // 125MHz 90度相移时钟
    .clk_12_5_out   (clk_12_5_out), // 12.5MHz时钟输出
    .clk_1_25_out   (clk_1_25_out), // 1.25MHz时钟输出
    .clk_25_out     (clk_25_out )   // 25MHz时钟输出
);

// LED显示模块
led u0_led(
       .udp_rx_clk                 (udp_clk                ),  // UDP接收时钟
       .reset                      (current_mode==MODE_IDLE_LEDS                  ),   // 复位信号低电平有效
       .app_rx_data_valid          (app_rx_data_valid      ),  // 应用层接收数据有效
       .app_rx_data                (app_rx_data            ),  // 应用层接收数据
       .app_rx_data_length         (app_rx_data_length     ),  // 应用层接收数据长度
       .dled                       (dled)       ,              // 数码管显示
       .led_data_1                 (led_data)                 // LED数据
 );
 //SD部分
 wire        clk_50_out;                             // 50MHz时钟输出
//reg key1_1, key1_2;                       // 系统复位同步寄存器
//wire  key2_2;                                         // 按键2
//assign key2_2= key1_2;                          // 按键2赋值
wire locked;                                        // PLL锁定信号
wire clk_50m, clk_50m_180deg;                       // 50MHz时钟和180度相位时钟


wire clk_sample;                                    // 采样时钟

// PLL实例化
pll_50 u_pll_50(
  .refclk (clk_50),           // 参考时钟输入
  .reset  (!key1),     // 复位输入
  .extlock(locked),           // 锁定输出
  .clk0_out  (clk_50m),       // 50MHz时钟输出
  .clk1_out  (clk_50m_180deg), // 50MHz 180度相位时钟输出
  .clk2_out  (clk_sample)     // 采样时钟输出
);
/*
// 系统复位同步逻辑
always @(posedge clk_50 or negedge key1) begin
    if(!key3) begin
        key3_1 <= 1'b0;
        key3_2 <= 1'b0;
    end
    else begin
        key3_1 <= key3;
        key3_2 <= key3_1;
    end
end
*/
wire rst_n;                                         // 同步后的复位信号
//assign  rst_n = key3_2;                        // 复位信号赋值

// SD卡控制信号
wire sd_rd_start_en;                                // SD卡读开始使能
wire [31:0] sd_rd_sec_addr;                         // SD卡读扇区地址
wire sd_rd_busy;                                    // SD卡读忙信号
wire sd_rd_val_en, sd_init_done;                    // SD卡读数据有效和初始化完成
wire [15:0] sd_rd_val_data;                         // SD卡读数据
wire sdr_wr_en;                                     // SDRAM写使能
wire [31:0] sdr_wr_data;                            // SDRAM写数据

// SD卡顶层控制模块实例化
sd_ctrl_top t1_sd_ctrl_top(
    .clk_ref                (clk_50m),              // 参考时钟
    .clk_ref_180deg         (clk_50m_180deg),       // 180度相位参考时钟
    .rst_n                  (current_mode==MODE_SDCARD_TX),                // 复位信号低电平有效
    // SD卡接口
    .sd_miso                (sd_miso),              // SD卡SPI输入
    .sd_clk                 (sd_clk),               // SD卡SPI时钟
    .sd_cs                  (sd_cs),                // SD卡SPI片选
    .sd_mosi                (sd_mosi),              // SD卡SPI输出
    // 用户读SD卡接口
    .rd_start_en            (sd_rd_start_en),       // 读开始使能
    .rd_sec_addr            (sd_rd_sec_addr),       // 读扇区地址
    .rd_busy                (sd_rd_busy),           // 读忙信号
    .rd_val_en              (sd_rd_val_en),         // 读数据有效
    .rd_val_data            (sd_rd_val_data),       // 读数据
    .sd_init_done           (sd_init_done)          // SD卡初始化完成
);

// SD卡读复位同步逻辑
reg key2_d0, key2_d1;
always @(posedge clk_50 or negedge rst_n) begin
    if(!rst_n) begin
        key2_d0 <= 1'b0;
        key2_d1 <= 1'b0;
    end
    else begin
        key2_d0 <= key2;
        key2_d1 <= key2_d0;
    end
end

wire key2_flag;                              // SD卡读复位标志
assign key2_flag = ({key2_d0, key2_d1} == 2'b10) ? 1'b0 : 1'b1;

// SDRAM信号
wire Sdr_init_done;                                 // SDRAM初始化完成
wire full_flag_sdr;                                 // SDRAM满标志

// 读取SD卡图片模块实例化(怎样复位存疑)
sd_read_photo t2_sd_read_photo(    //rst_n原始的系统复位 key2_flag
    .clk                   (clk_50m),               // 时钟
    .rst_n                 (key1 & Sdr_init_done & sd_init_done & (current_mode==MODE_SDCARD_TX)), // 复位低电平有效
    .ddr_max_addr          (24'd307200),            // DDR最大地址
    .sd_sec_num            (16'd1801),              // SD卡扇区数量
    .rd_busy               (sd_rd_busy),            // 读忙信号
    .sd_rd_val_en          (sd_rd_val_en),          // SD卡读数据有效
    .sd_rd_val_data        (sd_rd_val_data),        // SD卡读数据
    .rd_start_en           (sd_rd_start_en),        // 读开始使能
    .rd_sec_addr           (sd_rd_sec_addr),        // 读扇区地址
    .sdr_wr_en             (sdr_wr_en),             // SDRAM写使能
    .sdr_wr_data           (sdr_wr_data),           // SDRAM写数据
    .full_flag_sdr         (full_flag_sdr)          // SDRAM满标志
);

// SDRAM读信号
wire Sdr_rd_en;                                     // SDRAM读使能
wire [23:0] Sdr_rd_dout;                            // SDRAM读数据输出
wire sdr_clk;                                       // SDRAM时钟
wire full_flag;                                     // 满标志
wire [11:0] udp_wrusedw;                            // UDP写使用字数

// SDRAM顶层模块实例化
sdram_top t3_sdram (
    .SYS_CLK               (clk_50m),               // 系统时钟
    .sdr_data_valid        (sdr_wr_en),             // SDRAM数据有效
    .sdr_data              (sdr_wr_data),           // SDRAM数据
    .rst_n                 (key1 & (current_mode==MODE_SDCARD_TX)), // 复位低电平有效
    .sdr_clk               (sdr_clk),               // SDRAM时钟
    .Sdr_rd_en             (Sdr_rd_en),             // SDRAM读使能
    .Sdr_rd_dout           (Sdr_rd_dout),           // SDRAM读数据输出
    .Sdr_init_done         (Sdr_init_done),         // SDRAM初始化完成
    .full_flag             (full_flag),             // 满标志
    .full_flag_sdr         (full_flag_sdr),         // SDRAM满标志
    .udp_wrusedw           (udp_wrusedw)            // UDP写使用字数
);
 //HDMI显示图片
 // HDMI时钟生成
wire pixel_clk_5x;                                  // 5倍像素时钟
wire pixel_clk;                                     // 像素时钟

clk_wize u0_clk_wize (
  .refclk(clk_50),                                  // 参考时钟
  .reset(1'b0),                                     // 复位
  .clk0_out(pixel_clk_5x),                          // 5倍像素时钟输出
  .clk1_out(pixel_clk)                              // 像素时钟输出
);

// HDMI显示相关信号
wire VGA_EN;                                        // VGA使能
wire dis_en;                                        // 显示使能
wire [11:0] VGA_D;                                  // VGA数据
wire rd_en;                                         // 读使能

// 应用模块实例化
app u1_app (
    .sys_clk            (pixel_clk),                // 系统时钟
    .udp_rx_clk         (udp_clk),                  // UDP接收时钟
    .udp_tx_clk         (udp_clk),                  // UDP发送时钟
    .reset              ((current_mode==MODE_HDMI_RX)),// 复位低电平有效
    .app_rx_data_valid  (app_rx_data_valid),        // 应用层接收数据有效
    .app_rx_data        (app_rx_data),              // 应用层接收数据
    .app_rx_data_length (app_rx_data_length),       // 应用层接收数据长度
    .app_rx_port_num    (app_rx_port_num),          // 应用层接收端口号
    .VGA_HSYNC          (VGA_HSYNC),                // VGA行同步
    .VGA_VSYNC          (VGA_VSYNC),                // VGA场同步
    .VGA_D              (VGA_D),                    // VGA数据
    .rd_en              (rd_en),                    // 读使能
    .VGA_EN             (VGA_EN)                    // VGA使能
);

// VGA RGB信号
wire [7:0] VGA_R;                                   // VGA红色分量
wire [7:0] VGA_G;                                   // VGA绿色分量
wire [7:0] VGA_B;                                   // VGA蓝色分量

assign VGA_R = {VGA_D[11:8], 4'b0};                 // VGA红色分量赋值
assign VGA_G = {VGA_D[7:4], 4'b0};                  // VGA绿色分量赋值
assign VGA_B = {VGA_D[3:0], 4'b0};                  // VGA蓝色分量赋值

// HDMI发送模块实例化
hdmi_tx #(.FAMILY("EG4")) u2_hdmi_tx (              // 设备家族：EF2、EF3、EG4、AL3、PH1
    .PXLCLK_I      (pixel_clk),                     // 像素时钟输入
    .PXLCLK_5X_I   (pixel_clk_5x),                  // 5倍像素时钟输入
    .RST_N         (key2),                          // 复位（低有效）
    // VGA输入信号
    .VGA_HS        (VGA_HSYNC),                     // VGA行同步
    .VGA_VS        (VGA_VSYNC),                     // VGA场同步
    .VGA_DE        (VGA_EN),                        // VGA数据使能
    .VGA_RGB       ({VGA_R, VGA_G, VGA_B}),         // VGA RGB数据
    // HDMI输出信号
    .HDMI_CLK_P    (HDMI_CLK_P),                    // HDMI时钟正极
    .HDMI_D2_P     (HDMI_D2_P),                     // HDMI数据2正极
    .HDMI_D1_P     (HDMI_D1_P),                     // HDMI数据1正极
    .HDMI_D0_P     (HDMI_D0_P)                      // HDMI数据0正极
);
//------------------------------------------------------------
// UDP回环模块
// 图像数据处理
wire [23:0] image_data;                             // 图像数据
assign image_data = Sdr_rd_dout[23:0];              // 直接使用SDRAM读出的RGB数据

//------------------------------------------------------------
// UDP环回模块
//------------------------------------------------------------
udp_loopback #(
    .DEVICE(DEVICE)                                 // 设备类型
) u2_udp_loopback (
    .app_rx_clk          (sdr_clk),                 // 应用层接收时钟
    .app_tx_clk          (udp_clk),                 // 应用层发送时钟
    .reset               ((current_mode!=MODE_SDCARD_TX)),                   // 复位高电平有效
    .udp_wrusedw         (udp_wrusedw),             // UDP写使用字数
    .app_rx_data         (image_data),              // 应用层接收数据（图像数据）
    .app_rx_data_valid   (Sdr_rd_en),               // 应用层接收数据有效（SDRAM读使能）
    .app_rx_data_length  (16'd3),                   // 应用层接收数据长度（3字节）
    .full_flag           (full_flag),               // 满标志
    .udp_tx_ready        (udp_tx_ready),            // UDP发送就绪
    .app_tx_ack          (app_tx_ack),              // 应用层发送应答
    .app_tx_data         (app_tx_data_sd),              // 应用层发送数据
    .app_tx_data_request (app_tx_request_sd),     // 应用层发送数据请求
    .app_tx_data_valid   (app_tx_data_valid_sd),       // 应用层发送数据有效
    .udp_data_length     (udp_data_length_sd)          // UDP数据长度
);
//------------------------------------------------------------  
// UDP/IP协议栈 - 使用静态配置
//------------------------------------------------------------       
udp_ip_protocol_stack #
(
    .DEVICE                     (DEVICE                 ),  // 设备类型
    .LOCAL_UDP_PORT_NUM         (LOCAL_UDP_PORT_NUM     ),  // 本地UDP端口号
    .LOCAL_IP_ADDRESS           (LOCAL_IP_ADDRESS       ),  // 本地IP地址
    .LOCAL_MAC_ADDRESS          (LOCAL_MAC_ADDRESS      )   // 本地MAC地址
)   
u3_udp_ip_protocol_stack    
(   
    .udp_rx_clk                 (udp_clk                ),  // UDP接收时钟
    .udp_tx_clk                 (udp_clk                ),  // UDP发送时钟
    .reset                      (reset                  ),  // 复位信号高电平有效,使用第三个
    .udp2app_tx_ready           (udp_tx_ready           ),  // UDP到应用层发送就绪
    .udp2app_tx_ack             (app_tx_ack             ),  // UDP到应用层发送应答
    .app_tx_request             (app_tx_request    ),  // 应用层发送请求
    .app_tx_data_valid          (app_tx_data_valid_mux      ),  // 应用层发送数据有效
    .app_tx_data                (app_tx_data_mux            ),  // 应用层发送数据
    .app_tx_data_length         (udp_data_length_mux        ),  // 应用层发送数据长度
    .app_tx_dst_port            (DST_UDP_PORT_NUM       ),  // 应用层发送目标端口
    .ip_tx_dst_address          (DST_IP_ADDRESS         ),  // IP发送目标地址
    
    // 静态端口配置
    .input_local_udp_port_num      (static_local_udp_port_num      ),  // 输入本地UDP端口号
    .input_local_udp_port_num_valid(static_local_udp_port_num_valid),  // 输入本地UDP端口号有效
    
    // 静态IP配置
    .input_local_ip_address     (static_local_ip_address     ),  // 输入本地IP地址
    .input_local_ip_address_valid(static_local_ip_address_valid),  // 输入本地IP地址有效
    
    .app_rx_data_valid          (app_rx_data_valid      ),  // 应用层接收数据有效
    .app_rx_data                (app_rx_data            ),  // 应用层接收数据
    .app_rx_data_length         (app_rx_data_length     ),  // 应用层接收数据长度
    .app_rx_port_num            (app_rx_port_num        ),  // 应用层接收端口号
    .temac_rx_ready             (temac_rx_ready         ),  // TEMAC接收就绪
    .temac_rx_valid             (!temac_rx_valid        ),  // TEMAC接收有效（反相）
    .temac_rx_data              (temac_rx_data          ),  // TEMAC接收数据
    .temac_rx_sof               (temac_rx_sof           ),  // TEMAC接收帧起始
    .temac_rx_eof               (temac_rx_eof           ),  // TEMAC接收帧结束
    .temac_tx_ready             (temac_tx_ready         ),  // TEMAC发送就绪
    .temac_tx_valid             (temac_tx_valid         ),  // TEMAC发送有效
    .temac_tx_data              (temac_tx_data          ),  // TEMAC发送数据
    .temac_tx_sof               (temac_tx_sof           ),  // TEMAC发送帧起始
    .temac_tx_eof               (temac_tx_eof           ),  // TEMAC发送帧结束
    
    .ip_rx_error                (                       ),  // IP接收错误
    .arp_request_no_reply_error (                       )   // ARP请求无应答错误
);

//------------------------------------------------------------  
// TEMAC模块
//------------------------------------------------------------  
temac_block#(
    .DEVICE               (DEVICE                   )  // 设备类型参数
) u4_trimac_block(
    .reset                (reset                    ),  // 复位信号
    .gtx_clk              (temac_clk                ),  // GTX时钟输入 125MHz
    .gtx_clk_90           (temac_clk90              ),  // GTX 90度相移时钟 125MHz
    .rx_clk               (rx_clk_int               ),  // 接收时钟输出 125M/25M/2.5M
    .rx_clk_en            (rx_clk_en_int            ),  // 接收时钟使能输出 1/12.5M/1.25M
    .rx_data              (rx_data                  ),  // 接收数据
    .rx_data_valid        (rx_valid                 ),  // 接收数据有效
    .rx_correct_frame     (rx_correct_frame         ),  // 接收正确帧
    .rx_error_frame       (rx_error_frame           ),  // 接收错误帧
    .rx_status_vector     (                         ),  // 接收状态向量
    .rx_status_vld        (                         ),  // 接收状态有效
    .tx_clk               (tx_clk_int               ),  // 发送时钟输出 125MHz
    .tx_clk_en            (tx_clk_en_int            ),  // 发送时钟使能输出 1/12.5M/1.25M
    .tx_data              (tx_data                  ),  // 发送数据
    .tx_data_en           (tx_valid                 ),  // 发送数据使能
    .tx_rdy               (tx_rdy                   ),  // 发送就绪 (temac_tx_ready)
    .tx_stop              (tx_stop                  ),  // 发送停止输入
    .tx_collision         (tx_collision             ),  // 发送冲突
    .tx_retransmit        (tx_retransmit            ),  // 发送重传
    .tx_ifg_val           (tx_ifg_val               ),  // 发送帧间隔值输入
    .tx_status_vector     (                         ),  // 发送状态向量
    .tx_status_vld        (                         ),  // 发送状态有效
    .pause_req            (pause_req                ),  // 暂停请求输入
    .pause_val            (pause_val                ),  // 暂停值输入
    .pause_source_addr    (pause_source_addr        ),  // 暂停源地址输入
    .unicast_address      (unicast_address          ),  // 单播地址输入
    .mac_cfg_vector       (mac_cfg_vector           ),  // MAC配置向量输入
    .rgmii_txd            (phy1_rgmii_tx_data       ),  // RGMII发送数据
    .rgmii_tx_ctl         (phy1_rgmii_tx_ctl        ),  // RGMII发送控制
    .rgmii_txc            (phy1_rgmii_tx_clk        ),  // RGMII发送时钟
    .rgmii_rxd            (phy1_rgmii_rx_data       ),  // RGMII接收数据
    .rgmii_rx_ctl         (phy1_rgmii_rx_ctl        ),  // RGMII接收控制
    .rgmii_rxc            (phy1_rgmii_rx_clk        ),  // RGMII接收时钟
    .inband_link_status   (                         ),  // 带内链路状态
    .inband_clock_speed   (                         ),  // 带内时钟速度
    .inband_duplex_status (                         )   // 带内双工状态
);

// UDP时钟生成模块
udp_clk_gen#(
    .DEVICE               (DEVICE                   )  // 设备类型参数
)  u5_temac_clk_gen(           
    .reset                (~key1                    ),  // 复位信号
    .tri_speed            (TRI_speed                ),  // 三速模式
    .clk_125_in           (clk_125_out              ),  // 125MHz时钟输入
    .clk_12_5_in          (clk_12_5_out             ),  // 12.5MHz时钟输入
    .clk_1_25_in          (clk_1_25_out             ),  // 1.25MHz时钟输入
    .udp_clk_out          (udp_clk                  )   // UDP时钟输出
);

// 发送客户端FIFO
tx_client_fifo#
(
    .DEVICE               (DEVICE                   )  // 设备类型参数
)
u6_tx_fifo
(
    .rd_clk               (tx_clk_int               ),  // 读时钟
    .rd_sreset            (reset                    ),  // 读同步复位
    .rd_enable            (tx_clk_en_int            ),  // 读使能
    .tx_data              (tx_data                  ),  // 发送数据
    .tx_data_valid        (tx_valid                 ),  // 发送数据有效
    .tx_ack               (tx_rdy                   ),  // 发送应答
    .tx_collision         (tx_collision             ),  // 发送冲突
    .tx_retransmit        (tx_retransmit            ),  // 发送重传
    .overflow             (                         ),  // 溢出标志
                            
    .wr_clk               (udp_clk                  ),  // 写时钟
    .wr_sreset            (reset                    ),  // 写同步复位
    .wr_data              (temac_tx_data            ),  // 写数据
    .wr_sof_n             (temac_tx_sof             ),  // 写帧起始
    .wr_eof_n             (temac_tx_eof             ),  // 写帧结束
    .wr_src_rdy_n         (temac_tx_valid           ),  // 写源就绪
    .wr_dst_rdy_n         (temac_tx_ready           ),  // 写目标就绪 (temac_tx_ready)
    .wr_fifo_status       (                         )   // 写FIFO状态
);

// 接收客户端FIFO
rx_client_fifo#
(
    .DEVICE               (DEVICE                   )  // 设备类型参数
)
u7_rx_fifo                  
(                           
    .wr_clk               (rx_clk_int               ),  // 写时钟
    .wr_enable            (rx_clk_en_int            ),  // 写使能
    .wr_sreset            (reset                    ),  // 写同步复位
    .rx_data              (rx_data                  ),  // 接收数据
    .rx_data_valid        (rx_valid                 ),  // 接收数据有效
    .rx_good_frame        (rx_correct_frame         ),  // 接收正确帧
    .rx_bad_frame         (rx_error_frame           ),  // 接收错误帧
    .overflow             (                         ),  // 溢出标志
    .rd_clk               (udp_clk                  ),  // 读时钟
    .rd_sreset            (reset                    ),  // 读同步复位
    .rd_data_out          (temac_rx_data            ),  // 读数据输出
    .rd_sof_n             (temac_rx_sof             ),  // 读帧起始
    .rd_eof_n             (temac_rx_eof             ),  // 读帧结束
    .rd_src_rdy_n         (temac_rx_valid           ),  // 读源就绪
    .rd_dst_rdy_n         (temac_rx_ready           ),  // 读目标就绪
    .rx_fifo_status       (                         )   // 接收FIFO状态
);

endmodule