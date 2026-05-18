`timescale 1ns / 1ps

`define UDP_LOOP_BACK        // 定义UDP回环模式

module UDP_Example_Top(
        input               key1,           // 按键1输入
        input               key2,           // 按键2输入
        input               clk_50,         // 50MHz时钟输入
        
        input               phy1_rgmii_rx_clk,    // PHY1 RGMII接收时钟
        input               phy1_rgmii_rx_ctl,    // PHY1 RGMII接收控制
        input [3:0]         phy1_rgmii_rx_data,   // PHY1 RGMII接收数据
                                
        output wire         phy1_rgmii_tx_clk,    // PHY1 RGMII发送时钟
        output wire         phy1_rgmii_tx_ctl,    // PHY1 RGMII发送控制
        output wire [3:0]   phy1_rgmii_tx_data,   // PHY1 RGMII发送数据
        output            [3:0] led_data ,        // LED数据输出
        
        output            [15:0] dled       // 数码管显示输出
);

// 参数定义
parameter  DEVICE             = "EG4";              // 设备类型："PH1","EG4"
parameter  LOCAL_UDP_PORT_NUM = 16'h0001;           // 本地UDP端口号
parameter  LOCAL_IP_ADDRESS   = 32'hc0a8f001;       // 本地IP地址 (192.168.240.1)
parameter  LOCAL_MAC_ADDRESS  = 48'h0123456789ab;   // 本地MAC地址
parameter  DST_UDP_PORT_NUM   = 16'h0002;           // 目标UDP端口号
parameter  DST_IP_ADDRESS     = 32'hc0a8f002;       // 目标IP地址 (192.168.240.2)

// 应用层接收信号
wire [3:0]   led;
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

// 测试模式生成信号
wire  [7:0]  tpg_data;                 // 测试模式数据
wire         tpg_data_valid;           // 测试模式数据有效
wire  [15:0] tpg_data_udp_length;      // 测试模式UDP数据长度

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
wire        reset,reset_reg;           // 复位信号
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

// LED显示静态IP地址的低4位
assign led = ~static_local_ip_address[3:0];

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
       .reset                      (key1                  ),   // 复位信号
       .app_rx_data_valid          (app_rx_data_valid      ),  // 应用层接收数据有效
       .app_rx_data                (app_rx_data            ),  // 应用层接收数据
       .app_rx_data_length         (app_rx_data_length     ),  // 应用层接收数据长度
       .dled                       (dled)       ,              // 数码管显示
       .led_data_1                 (led_data)                 // LED数据
 );

// UDP数据测试模式生成器
udp_data_tpg u1_udp_data_tpg(
    .clk                (udp_clk            ),  // 时钟输入
    .reset              (~key2              ),  // 复位输入

    .tpg_data           (tpg_data           ),  // 测试模式数据输出
    .tpg_data_valid     (tpg_data_valid     ),  // 测试模式数据有效
    .tpg_data_udp_length(tpg_data_udp_length),  // 测试模式UDP数据长度
    .tpg_data_done      (tpg_data_done      ),  // 测试模式数据完成
    
    .tpg_data_enable    (phy_reset          ),  // 测试模式使能
    .tpg_data_header0   (16'haabb           ),  // 帧头0
    .tpg_data_header1   (16'hccdd           ),  // 帧头1
    .tpg_data_type      (16'ha8b8           ),  // 数据帧类型
    .tpg_data_length    (16'h00ff           ),  // 数据长度500
    .tpg_data_num       (16'h000a           ),  // 产生的帧个数10
    .tpg_data_ifg       (8'd130             )   // 帧间隔
);

//------------------------------------------------------------
// UDP回环模块
//------------------------------------------------------------
udp_loopback#(
    .DEVICE(DEVICE)  // 设备类型参数
)
 u2_udp_loopback
 (
    .app_rx_clk                 (udp_clk                ),  // 应用层接收时钟
    .app_tx_clk                 (udp_clk                ),  // 应用层发送时钟
    .reset                      (reset                  ),  // 复位信号
    
    `ifdef UDP_LOOP_BACK        // UDP回环模式
    .app_rx_data                (app_rx_data            ),  // 应用层接收数据
    .app_rx_data_valid          (app_rx_data_valid      ),  // 应用层接收数据有效
    .app_rx_data_length         (app_rx_data_length     ),  // 应用层接收数据长度
    `else                       // 测试模式
    .app_rx_data                (tpg_data               ),  // 测试模式数据
    .app_rx_data_valid          (tpg_data_valid         ),  // 测试模式数据有效
    .app_rx_data_length         (tpg_data_udp_length    ),  // 测试模式UDP数据长度
    `endif              
    
    .udp_tx_ready               (udp_tx_ready           ),  // UDP发送就绪
    .app_tx_ack                 (app_tx_ack             ),  // 应用层发送应答
    .app_tx_data                (app_tx_data            ),  // 应用层发送数据
    .app_tx_data_request        (app_tx_data_request    ),  // 应用层发送数据请求
    .app_tx_data_valid          (app_tx_data_valid      ),  // 应用层发送数据有效
    .udp_data_length            (udp_data_length        )    // UDP数据长度
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
    .reset                      (reset                  ),  // 复位信号
    .udp2app_tx_ready           (udp_tx_ready           ),  // UDP到应用层发送就绪
    .udp2app_tx_ack             (app_tx_ack             ),  // UDP到应用层发送应答
    .app_tx_request             (app_tx_data_request    ),  // 应用层发送请求
    .app_tx_data_valid          (app_tx_data_valid      ),  // 应用层发送数据有效
    .app_tx_data                (app_tx_data            ),  // 应用层发送数据
    .app_tx_data_length         (udp_data_length        ),  // 应用层发送数据长度
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