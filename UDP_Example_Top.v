// 时间单位和精度定义
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
//        / /      \ \ ----- `
//       / /_ _ _   \ \ --- 
//      /_ _ _ _ _\  \_\ -
//*********************************************************************** 
// 作者: suluyang 
// 邮箱: luyang.su@anlogic.com 
// 日期: 2020/11/17 
// 描述: UDP示例顶层模块
// 2022/03/10:  修改时钟结构
//              简化约束
//              添加 soft fifo 
//              添加 debug 功能
// 2023/02/16 : 添加 dynamic_local_ip_address 端口
// 
// 网站: www.anlogic.com 
//------------------------------------------------------------------- 
//*********************************************************************/

// UDP环回模式定义
`define UDP_LOOP_BACK
// UDP调试模式定义（注释掉）
//  `define DEBUG_UDP

module UDP_Example_Top(
      // 系统时钟和复位
      input  clk_50,                    // 50MHz系统时钟
      input  key1,                 // 系统复位，低电平有效
      input  key2,               // SD卡读复位信号
      
      // SD卡接口
      input  sd_miso,                   // SD卡SPI主输入从输出
      output sd_clk,                    // SD卡SPI时钟
      output sd_cs,                     // SD卡SPI片选
      output sd_mosi,                   // SD卡SPI主输出从输入
      
      // 以太网PHY1 RGMII接口
      input               phy1_rgmii_rx_clk,   // PHY1接收时钟
      input               phy1_rgmii_rx_ctl,   // PHY1接收控制
      input [3:0]         phy1_rgmii_rx_data,  // PHY1接收数据
      output wire         phy1_rgmii_tx_clk,   // PHY1发送时钟
      output wire         phy1_rgmii_tx_ctl,   // PHY1发送控制
      output wire [3:0]   phy1_rgmii_tx_data  // PHY1发送数据
      
);

// 参数定义
parameter  DEVICE             = "EG4";              // 设备类型："PH1","EG4"
parameter  LOCAL_UDP_PORT_NUM = 16'd5000;           // 本地UDP端口号
parameter  LOCAL_IP_ADDRESS   = 32'hc0a80002;       // 本地IP地址
parameter  LOCAL_MAC_ADDRESS  = 48'h0123456789ab;   // 本地MAC地址
parameter  DST_UDP_PORT_NUM   = 16'd6102;           // 目标UDP端口号
parameter  DST_IP_ADDRESS     = 32'hc0a80003;       // 目标IP地址

/*------------------------------*/
/*------------------------------*/

// 信号定义
wire         app_rx_data_valid;                     // 应用层接收数据有效信号
wire [7:0]   app_rx_data;                           // 应用层接收数据
wire [15:0]  app_rx_data_length;                    // 应用层接收数据长度
wire [15:0]  app_rx_port_num;                       // 应用层接收端口号

wire         udp_tx_ready;                          // UDP发送就绪信号
wire         app_tx_ack;                            // 应用层发送应答
wire         app_tx_data_request;                   // 应用层发送数据请求
wire         app_tx_data_valid;                     // 应用层发送数据有效
wire [7:0]   app_tx_data;                           // 应用层发送数据
wire  [15:0] udp_data_length;                       // UDP数据长度

// 测试模式生成器信号
wire  [7:0]  tpg_data;                              // 测试模式数据
wire         tpg_data_valid;                        // 测试模式数据有效
wire  [15:0] tpg_data_udp_length;                   // 测试模式UDP数据长度

// TEMAC信号
wire        tx_stop;                                // 发送停止
wire [7:0]  tx_ifg_val;                             // 发送帧间隔值
wire        pause_req;                              // 暂停请求
wire [15:0] pause_val;                              // 暂停值
wire [47:0] pause_source_addr;                      // 暂停源地址
wire [47:0] unicast_address;                        // 单播地址
wire [19:0] mac_cfg_vector;                         // MAC配置向量

wire        temac_tx_ready;                         // TEMAC发送就绪
wire        temac_tx_valid;                         // TEMAC发送有效
wire [7:0]  temac_tx_data;                          // TEMAC发送数据
wire        temac_tx_sof;                           // TEMAC发送帧起始
wire        temac_tx_eof;                           // TEMAC发送帧结束

wire        temac_rx_ready;                         // TEMAC接收就绪
wire        temac_rx_valid;                         // TEMAC接收有效
wire [7:0]  temac_rx_data;                          // TEMAC接收数据
wire        temac_rx_sof;                           // TEMAC接收帧起始
wire        temac_rx_eof;                           // TEMAC接收帧结束

wire        rx_correct_frame;                       // 接收正确帧
wire        rx_error_frame;                         // 接收错误帧
wire [1:0]  TRI_speed;                              // 三速以太网速度设置

// 速度设置：千兆2'b10 百兆2'b01 十兆2'b00
assign TRI_speed = 2'b10;

// 时钟信号
wire        rx_clk_int;                             // 接收时钟
wire        rx_clk_en_int;                          // 接收时钟使能
wire        tx_clk_int;                             // 发送时钟
wire        tx_clk_en_int;                          // 发送时钟使能

wire        temac_clk;                              // TEMAC时钟
wire        udp_clk;                                // UDP时钟
wire        temac_clk90;                            // TEMAC 90度相位时钟
wire        clk_125_out;                            // 125MHz时钟输出
wire        clk_12_5_out;                           // 12.5MHz时钟输出
wire        clk_1_25_out;                           // 1.25MHz时钟输出
wire        rx_valid;                               // 接收有效
wire [7:0]  rx_data;                                // 接收数据
wire [7:0]  tx_data;                                // 发送数据
wire        tx_valid;                               // 发送有效
wire        tx_rdy;                                 // 发送就绪
wire        tx_collision;                           // 发送冲突
wire        tx_retransmit;                          // 发送重传

// 复位和时钟信号
wire        reset, reset_reg;                       // 复位信号
wire        clk_50_out;                             // 50MHz时钟输出
reg [7:0]   phy_reset_cnt = 'd0;                    // PHY复位计数器
reg [7:0]   soft_reset_cnt = 8'hff;                 // 软复位计数器
reg key1_1, key1_2;                       // 系统复位同步寄存器
wire  key2_2;                                         // 按键2
assign key2_2= key1_2;                          // 按键2赋值
wire locked;                                        // PLL锁定信号
wire clk_50m, clk_50m_180deg;                       // 50MHz时钟和180度相位时钟
assign  reset = ~key1 || reset_reg || (soft_reset_cnt != 'd0);  // 复位信号组合逻辑


wire clk_sample;                                    // 采样时钟

// PLL实例化
pll_50 u_pll_50(
  .refclk (clk_50),           // 参考时钟输入
  .reset  (!key1_2),     // 复位输入
  .extlock(locked),           // 锁定输出
  .clk0_out  (clk_50m),       // 50MHz时钟输出
  .clk1_out  (clk_50m_180deg), // 50MHz 180度相位时钟输出
  .clk2_out  (clk_sample)     // 采样时钟输出
);

// 系统复位同步逻辑
always @(posedge clk_50 or negedge key1) begin
    if(!key1) begin
        key1_1 <= 1'b0;
        key1_2 <= 1'b0;
    end
    else begin
        key1_1 <= key1;
        key1_2 <= key1_1;
    end
end

wire rst_n;                                         // 同步后的复位信号
assign  rst_n = key1_2;                        // 复位信号赋值

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
    .rst_n                  (rst_n),                // 复位信号
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

// 读取SD卡图片模块实例化
sd_read_photo t2_sd_read_photo(
    .clk                   (clk_50m),               // 时钟
    .rst_n                 (rst_n & Sdr_init_done & sd_init_done & key2_flag), // 复位
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
    .rst_n                 (rst_n & key2_flag), // 复位
    .sdr_clk               (sdr_clk),               // SDRAM时钟
    .Sdr_rd_en             (Sdr_rd_en),             // SDRAM读使能
    .Sdr_rd_dout           (Sdr_rd_dout),           // SDRAM读数据输出
    .Sdr_init_done         (Sdr_init_done),         // SDRAM初始化完成
    .full_flag             (full_flag),             // 满标志
    .full_flag_sdr         (full_flag_sdr),         // SDRAM满标志
    .udp_wrusedw           (udp_wrusedw)            // UDP写使用字数
);

// PHY复位计数器逻辑
always @(posedge clk_50_out or negedge key1) begin
    if(~key1)
        phy_reset_cnt <= 'd0;
    else if(phy_reset_cnt < 255)
        phy_reset_cnt <= phy_reset_cnt + 1;
    else
        phy_reset_cnt <= phy_reset_cnt;
end

wire phy_reset;                                     // PHY复位信号
assign  phy_reset = phy_reset_cnt[7];               // PHY复位赋值

// 软复位计数器逻辑
always @(posedge udp_clk or negedge key1) begin
    if(~key1)
        soft_reset_cnt <= 8'hff;
    else if(soft_reset_cnt > 0)
        soft_reset_cnt <= soft_reset_cnt - 1;
    else
        soft_reset_cnt <= soft_reset_cnt;
end

//============================================================
// 参数配置逻辑
//============================================================
// 需配置的客户端接口（初始默认值）
assign  tx_stop    = 1'b0;                          // 发送停止
assign  tx_ifg_val = 8'h00;                         // 发送帧间隔值
assign  pause_req  = 1'b0;                          // 暂停请求
assign  pause_val  = 16'h0;                         // 暂停值
assign  pause_source_addr = 48'h5af1f2f3f4f5;       // 暂停源地址
assign  unicast_address   = {                       // 单播地址（字节序转换）
    LOCAL_MAC_ADDRESS[7:0],
    LOCAL_MAC_ADDRESS[15:8],
    LOCAL_MAC_ADDRESS[23:16],
    LOCAL_MAC_ADDRESS[31:24],
    LOCAL_MAC_ADDRESS[39:32],
    LOCAL_MAC_ADDRESS[47:40]
};

// MAC配置向量：地址过滤模式、流控配置、速度配置、接收器配置、发送器配置
assign  mac_cfg_vector = {1'b0, 2'b00, TRI_speed, 8'b00000010, 7'b0000010};

//-----------------------------------------------------
// 测试动态本地IP地址
//-----------------------------------------------------

// 参数定义
reg [32:0] cnt0;                                    // 计数器0
wire      end_cnt0;                                 // 计数器0结束
wire      add_cnt0;                                 // 计数器0增加
reg [7:0] cnt1;                                     // 计数器1
wire      end_cnt1;                                 // 计数器1结束
wire      add_cnt1;                                 // 计数器1增加

// 计数器0逻辑
always @(posedge udp_clk or negedge key1_2) begin
    if(!key1_2) begin
        cnt0 <= 0;
    end
    else if(add_cnt0) begin
        if(end_cnt0)
            cnt0 <= 0;
        else
            cnt0 <= cnt0 + 1;
    end
end

assign add_cnt0 = 1;                                // 计数器0始终增加
assign end_cnt0 = add_cnt0 && 0;                    // 计数器0结束条件

// 计数器1逻辑
always @(posedge udp_clk or negedge key1_2) begin
    if(!key1_2) begin
        cnt1 <= 0;
    end
    else if(add_cnt1) begin
        if(end_cnt1)
            cnt1 <= 0;
        else
            cnt1 <= cnt1 + 1;
    end
end

assign add_cnt1 = end_cnt0;                         // 计数器1在计数器0结束时增加
assign end_cnt1 = add_cnt1 && cnt1 == 15;           // 计数器1结束条件

// 动态本地IP地址配置
reg [31:0]  input_local_ip_address;                 // 输入本地IP地址
reg         input_local_ip_address_valid;           // 输入本地IP地址有效

always @(posedge udp_clk or posedge reset) begin
    if(reset) begin
        input_local_ip_address      <= LOCAL_IP_ADDRESS;
        input_local_ip_address_valid <= 1'b0;
    end
    else if(end_cnt0 == 1'b1) begin
        input_local_ip_address      <= {LOCAL_IP_ADDRESS[31:8], cnt1};
        input_local_ip_address_valid <= 1'b1;
    end
    else begin
        input_local_ip_address      <= input_local_ip_address;
        input_local_ip_address_valid <= 1'b1;
    end
end


// 动态本地UDP端口号配置
reg [15:0] input_local_udp_port_num;                // 输入本地UDP端口号
reg        input_local_udp_port_num_valid;          // 输入本地UDP端口号有效

always @(posedge udp_clk or posedge reset) begin
    if(reset) begin
        input_local_udp_port_num      <= LOCAL_UDP_PORT_NUM;
        input_local_udp_port_num_valid <= 1'b0;
    end
    else begin
        input_local_udp_port_num      <= input_local_ip_address[3:0] + 3;
        input_local_udp_port_num_valid <= 1'b1;
    end
end

//-----------------------------------------------------

// 时钟生成和复位生成模块实例化
clk_gen_rst_gen #(
    .DEVICE         (DEVICE)                        // 设备类型
) u_clk_gen (
    .reset          (~key1),                        // 复位输入
    .clk_in         (clk_50),                       // 时钟输入
    .rst_out        (reset_reg),                    // 复位输出
    .clk_125_out0   (temac_clk),                    // 125MHz时钟输出0
    .clk_125_out1   (clk_125_out),                  // 125MHz时钟输出1
    .clk_125_out2   (temac_clk90),                  // 125MHz 90度相位时钟输出
    .clk_12_5_out   (clk_12_5_out),                 // 12.5MHz时钟输出
    .clk_1_25_out   (clk_1_25_out),                 // 1.25MHz时钟输出
    .clk_25_out     (clk_50_out)                    // 50MHz时钟输出
);


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
    .reset               (reset),                   // 复位
    .udp_wrusedw         (udp_wrusedw),             // UDP写使用字数
`ifdef UDP_LOOP_BACK
    .app_rx_data         (image_data),              // 应用层接收数据（图像数据）
    .app_rx_data_valid   (Sdr_rd_en),               // 应用层接收数据有效（SDRAM读使能）
    .app_rx_data_length  (16'd3),                   // 应用层接收数据长度（3字节）
`else
    .app_rx_data         (tpg_data),                // 应用层接收数据（测试模式数据）
    .app_rx_data_valid   (tpg_data_valid),          // 应用层接收数据有效（测试模式有效）
    .app_rx_data_length  (tpg_data_udp_length),     // 应用层接收数据长度（测试模式长度）
`endif
    .full_flag           (full_flag),               // 满标志
    .udp_tx_ready        (udp_tx_ready),            // UDP发送就绪
    .app_tx_ack          (app_tx_ack),              // 应用层发送应答
    .app_tx_data         (app_tx_data),              // 应用层发送数据
    .app_tx_data_request (app_tx_data_request),     // 应用层发送数据请求
    .app_tx_data_valid   (app_tx_data_valid),       // 应用层发送数据有效
    .udp_data_length     (udp_data_length)          // UDP数据长度
);

//------------------------------------------------------------  
// UDP/IP协议栈
//------------------------------------------------------------       
udp_ip_protocol_stack #(
    .DEVICE                     (DEVICE),                   // 设备类型
    .LOCAL_UDP_PORT_NUM         (LOCAL_UDP_PORT_NUM),       // 本地UDP端口号
    .LOCAL_IP_ADDRESS           (LOCAL_IP_ADDRESS),         // 本地IP地址
    .LOCAL_MAC_ADDRESS          (LOCAL_MAC_ADDRESS)         // 本地MAC地址
) u3_udp_ip_protocol_stack (
    .udp_rx_clk                 (udp_clk),                  // UDP接收时钟
    .udp_tx_clk                 (udp_clk),                  // UDP发送时钟
    .reset                      (reset),                    // 复位
    .udp2app_tx_ready           (udp_tx_ready),             // UDP到应用层发送就绪
    .udp2app_tx_ack             (app_tx_ack),               // UDP到应用层发送应答
    .app_tx_request             (app_tx_data_request),      // 应用层发送请求
    .app_tx_data_valid          (app_tx_data_valid),        // 应用层发送数据有效
    .app_tx_data                (app_tx_data),              // 应用层发送数据
    .app_tx_data_length         (udp_data_length),          // 应用层发送数据长度
    .app_tx_dst_port            (DST_UDP_PORT_NUM),         // 应用层发送目标端口
    .ip_tx_dst_address          (DST_IP_ADDRESS),           // IP发送目标地址
    .input_local_udp_port_num   (input_local_udp_port_num), // 输入本地UDP端口号
    .input_local_udp_port_num_valid(input_local_udp_port_num_valid), // 输入本地UDP端口号有效
    .input_local_ip_address     (input_local_ip_address),   // 输入本地IP地址
    .input_local_ip_address_valid(input_local_ip_address_valid), // 输入本地IP地址有效
    .app_rx_data_valid          (app_rx_data_valid),        // 应用层接收数据有效
    .app_rx_data                (app_rx_data),              // 应用层接收数据
    .app_rx_data_length         (app_rx_data_length),       // 应用层接收数据长度
    .app_rx_port_num            (app_rx_port_num),          // 应用层接收端口号
    .temac_rx_ready             (temac_rx_ready),           // TEMAC接收就绪
    .temac_rx_valid             (!temac_rx_valid),          // TEMAC接收有效（取反）
    .temac_rx_data              (temac_rx_data),            // TEMAC接收数据
    .temac_rx_sof               (temac_rx_sof),             // TEMAC接收帧起始
    .temac_rx_eof               (temac_rx_eof),             // TEMAC接收帧结束
    .temac_tx_ready             (temac_tx_ready),           // TEMAC发送就绪
    .temac_tx_valid             (temac_tx_valid),           // TEMAC发送有效
    .temac_tx_data              (temac_tx_data),            // TEMAC发送数据
    .temac_tx_sof               (temac_tx_sof),             // TEMAC发送帧起始
    .temac_tx_eof               (temac_tx_eof),             // TEMAC发送帧结束
`ifdef DEBUG_UDP
    .udp_debug_out              (udp_debug_out),            // UDP调试输出
`endif
    .ip_rx_error                (),                         // IP接收错误
    .arp_request_no_reply_error ()                          // ARP请求无应答错误
);

// 接收时钟PLL
wire phy1_rgmii_rx_clk_0;                            // PHY1接收时钟0相位
wire phy1_rgmii_rx_clk_90;                           // PHY1接收时钟90度相位


//------------------------------------------------------------  
// TEMAC模块
//------------------------------------------------------------  
temac_block #(
    .DEVICE               (DEVICE)                   // 设备类型
) u4_trimac_block (
    .reset                (reset),                   // 复位
    .gtx_clk              (clk_125_out),             // GTX时钟（125MHz）
    .gtx_clk_90           (temac_clk90),             // GTX 90度相位时钟
    .rx_clk               (rx_clk_int),              // 接收时钟
    .rx_clk_en            (rx_clk_en_int),           // 接收时钟使能
    .rx_data              (rx_data),                 // 接收数据
    .rx_data_valid        (rx_valid),                // 接收数据有效
    .rx_correct_frame     (rx_correct_frame),        // 接收正确帧
    .rx_error_frame       (rx_error_frame),          // 接收错误帧
    .rx_status_vector     (),                        // 接收状态向量
    .rx_status_vld        (),                        // 接收状态有效
    .tx_clk               (tx_clk_int),              // 发送时钟
    .tx_clk_en            (tx_clk_en_int),           // 发送时钟使能
    .tx_data              (tx_data),                 // 发送数据
    .tx_data_en           (tx_valid),                // 发送数据使能
    .tx_rdy               (tx_rdy),                  // 发送就绪
    .tx_stop              (tx_stop),                 // 发送停止
    .tx_collision         (tx_collision),            // 发送冲突
    .tx_retransmit        (tx_retransmit),           // 发送重传
    .tx_ifg_val           (tx_ifg_val),              // 发送帧间隔值
    .tx_status_vector     (),                        // 发送状态向量
    .tx_status_vld        (),                        // 发送状态有效
    .pause_req            (pause_req),               // 暂停请求
    .pause_val            (pause_val),               // 暂停值
    .pause_source_addr    (pause_source_addr),       // 暂停源地址
    .unicast_address      (unicast_address),         // 单播地址
    .mac_cfg_vector       (mac_cfg_vector),          // MAC配置向量
    .rgmii_txd            (phy1_rgmii_tx_data),      // RGMII发送数据
    .rgmii_tx_ctl         (phy1_rgmii_tx_ctl),       // RGMII发送控制
    .rgmii_txc            (phy1_rgmii_tx_clk),       // RGMII发送时钟
    .rgmii_rxd            (phy1_rgmii_rx_data),      // RGMII接收数据
    .rgmii_rx_ctl         (phy1_rgmii_rx_ctl),       // RGMII接收控制
    .rgmii_rxc            (phy1_rgmii_rx_clk),    // RGMII接收时钟（90度相位）
    .inband_link_status   (),                        // 带内链路状态
    .inband_clock_speed   (),                        // 带内时钟速度
    .inband_duplex_status ()                         // 带内双工状态
);

// UDP时钟生成模块
udp_clk_gen #(
    .DEVICE               (DEVICE)                   // 设备类型
) u5_temac_clk_gen (
    .reset                (~key1),                   // 复位
    .tri_speed            (TRI_speed),               // 三速以太网速度
    .clk_125_in           (clk_125_out),             // 125MHz时钟输入
    .clk_12_5_in          (clk_12_5_out),            // 12.5MHz时钟输入
    .clk_1_25_in          (clk_1_25_out),            // 1.25MHz时钟输入
    .udp_clk_out          (udp_clk)                  // UDP时钟输出
);

// 发送客户端FIFO
tx_client_fifo #(
    .DEVICE               (DEVICE)                   // 设备类型
) u6_tx_fifo (
    .rd_clk               (tx_clk_int),              // 读时钟
    .rd_sreset            (reset),                   // 读同步复位
    .rd_enable            (tx_clk_en_int),           // 读使能
    .tx_data              (tx_data),                 // 发送数据
    .tx_data_valid        (tx_valid),                // 发送数据有效
    .tx_ack               (tx_rdy),                  // 发送应答
    .tx_collision         (tx_collision),            // 发送冲突
    .tx_retransmit        (tx_retransmit),           // 发送重传
    .overflow             (),                        // 溢出
    .wr_clk               (udp_clk),                 // 写时钟
    .wr_sreset            (reset),                   // 写同步复位
    .wr_data              (temac_tx_data),           // 写数据
    .wr_sof_n             (temac_tx_sof),            // 写帧起始（低有效）
    .wr_eof_n             (temac_tx_eof),            // 写帧结束（低有效）
    .wr_src_rdy_n         (temac_tx_valid),          // 写源就绪（低有效）
    .wr_dst_rdy_n         (temac_tx_ready),          // 写目标就绪（低有效）
    .wr_fifo_status       ()                         // 写FIFO状态
);

// 接收客户端FIFO
rx_client_fifo #(
    .DEVICE               (DEVICE)                   // 设备类型
) u7_rx_fifo (
    .wr_clk               (rx_clk_int),              // 写时钟
    .wr_enable            (rx_clk_en_int),           // 写使能
    .wr_sreset            (reset),                   // 写同步复位
    .rx_data              (rx_data),                 // 接收数据
    .rx_data_valid        (rx_valid),                // 接收数据有效
    .rx_good_frame        (rx_correct_frame),        // 接收正确帧
    .rx_bad_frame         (rx_error_frame),          // 接收错误帧
    .overflow             (),                        // 溢出
    .rd_clk               (udp_clk),                 // 读时钟
    .rd_sreset            (reset),                   // 读同步复位
    .rd_data_out          (temac_rx_data),           // 读数据输出
    .rd_sof_n             (temac_rx_sof),            // 读帧起始（低有效）
    .rd_eof_n             (temac_rx_eof),            // 读帧结束（低有效）
    .rd_src_rdy_n         (temac_rx_valid),          // 读源就绪（低有效）
    .rd_dst_rdy_n         (temac_rx_ready),          // 读目标就绪（低有效）
    .rx_fifo_status       ()                         // 接收FIFO状态
);

endmodule