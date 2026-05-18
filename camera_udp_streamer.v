/*
 * 模块: camera_udp_streamer (1024x768 巨型帧版)
 * 功能: 从FIFO读取2050字节的行数据, 打包为1个UDP巨型帧发送
 *
 * 假设:
 * 1. 摄像头数据格式: [行号L(2B)], [像素(2048B)] = 2050 字节/行
 * 2. 网络支持巨型帧 (Jumbo Frames), MTU > 2050
 */
module camera_udp_streamer(
    // UDP 协议栈发送接口
    input   wire		app_tx_clk,
    input   wire		reset,
    input   wire		udp_tx_ready,
    input   wire		app_tx_ack,
    output  reg  [7:0]  app_tx_data,
    output	reg  		app_tx_data_request,
    output	reg  		app_tx_data_valid,
    output  reg  [15:0]	udp_data_length,

    // 摄像头数据 FIFO 读取接口
    input   wire [7:0]  fifo_rddata,
    input   wire        fifo_empty,
    input   wire [14:0] fifo_rdusedw, // 位宽与顶层 async_fifo 匹配 (15位)
    output  reg         fifo_rdreq
);

    // --- 参数定义 ---
    // 1024 * 2 (像素) + 2 (行号) = 2050 字节
  //  localparam PACKET_LENGTH = 16'd2050; 
localparam PACKET_LENGTH = 16'd1282; 
    // 状态机
    reg [2:0]   STATE;
    localparam  WAIT_UDP_DATA   = 3'd0; // 等待数据和发送器就绪
    localparam  WAIT_ACK        = 3'd1; // 等待发送应答
    localparam  READ_FIFO_DELAY = 3'd2; // 为 ShowAhead FIFO 增加的读延迟
    localparam  SEND_UDP_DATA   = 3'd3; // 逐字节发送数据
    localparam  DELAY           = 3'd4; // 包间延时

    // 内部寄存器
    reg [15:0]  sent_data_cnt;      // 字节计数器
    reg [15:0]  delay_cnt;          // 延时计数器

    // 状态机
    always@(posedge app_tx_clk or posedge reset)
    begin
        if(reset) begin
            app_tx_data_request <= 1'b0;
            app_tx_data_valid   <= 1'b0;
            udp_data_length     <= 16'd0;
            app_tx_data         <= 8'd0;
            fifo_rdreq          <= 1'b0;
            sent_data_cnt       <= 16'd0;
            delay_cnt           <= 16'b0;
            STATE               <= WAIT_UDP_DATA;
        end
        else begin
           case(STATE)
                // 0: 等待一整行数据 (2050 字节) 并且 UDP 就绪
                WAIT_UDP_DATA:
                begin
                    fifo_rdreq          <= 1'b0;
                    app_tx_data_valid   <= 1'b0;
                    app_tx_data_request <= 1'b0;
                    
                    if((fifo_rdusedw >= PACKET_LENGTH) && udp_tx_ready) begin
                        app_tx_data_request <= 1'b1; // 请求发送
                        udp_data_length     <= PACKET_LENGTH; // 锁定包长
                        STATE               <= WAIT_ACK;
                    end
                end

                // 1: 等待发送端应答
                WAIT_ACK:
                begin
                   if(app_tx_ack) begin
                        // 收到应答, 准备开始发送数据
                        app_tx_data_request <= 1'b0;
                        fifo_rdreq          <= 1'b1; // 启动FIFO读 (发出第一个读请求)
                        app_tx_data_valid   <= 1'b0; // 第一个数据还未出来
                        sent_data_cnt       <= 16'd0;
                        STATE               <= READ_FIFO_DELAY; // 进入读延迟状态
                    end
                    else begin
                        app_tx_data_request <= 1'b1; // 保持请求
                    end
                end

                // 2: 为 ShowAhead FIFO 提供一个周期的读延迟
                READ_FIFO_DELAY: 
                begin
                    // (ShowAhead FIFO 在 rdreq=1 后, 下一个周期数据才有效)
                    fifo_rdreq        <= 1'b1; // 保持读请求
                    app_tx_data_valid <= 1'b1; // 数据有效标志拉高
                    app_tx_data       <= fifo_rddata; // 发送第一个字节 (来自FIFO的数据)
                    sent_data_cnt     <= 16'd1;
                    STATE             <= SEND_UDP_DATA;
                end
                
                // 3: 逐字节发送
                SEND_UDP_DATA: 
                begin
                    if(sent_data_cnt == (PACKET_LENGTH - 1)) begin
                        // 这是倒数第二个字节, 发送它, 并准备发送最后一个字节
                        sent_data_cnt     <= sent_data_cnt + 1'b1;
                        app_tx_data_valid <= 1'b1;
                        app_tx_data       <= fifo_rddata; 
                        fifo_rdreq        <= 1'b1; 
                        STATE             <= SEND_UDP_DATA;
                    end
                    else if(sent_data_cnt == PACKET_LENGTH) begin
    						sent_data_cnt       <= 16'd0;           // 清零计数器，为下一包做准备
    						app_tx_data_valid   <= 1'b1;           // 拉高有效标志，发送数据
    						app_tx_data         <= fifo_rddata;     // 发送最后一个字节
    						fifo_rdreq          <= 1'b0;           // 确认停止读
    						STATE               <= DELAY;           // 跳转到包间延时
                    end
                    else begin
                        // 发送中间字节
                        sent_data_cnt     <= sent_data_cnt + 1'b1;
                        app_tx_data_valid <= 1'b1;
                        app_tx_data       <= fifo_rddata; // 发送当前字节
                        fifo_rdreq        <= 1'b1; // 保持读请求
                        STATE             <= SEND_UDP_DATA;
                    end				
                end

                // 4: 包间延时
                DELAY: 
                begin
                    app_tx_data_valid <= 1'b0;
                    if(delay_cnt < 16'h0FFF) begin
                        delay_cnt <= delay_cnt + 1'b1;
                        STATE     <= DELAY;
                    end
                    else begin
                        delay_cnt <= 16'd0;
                        STATE     <= WAIT_UDP_DATA; // 返回等待状态
                    end
                end

                default: STATE <= WAIT_UDP_DATA;
            endcase
        end
    end

endmodule