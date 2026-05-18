// 数码管扫描显示模块
module seg_scan(
    input           clk,         // 系统时钟输入
    input           rst_n,       // 异步复位信号，低电平有效
    output reg [7:0] seg_sel,     // 数码管位选信号，控制8个数码管的使能
    output reg  [7:0]    seg_data,    // 数码管段选信号，8位包含小数点(MSB)
    input [7:0]     rx_seg_sel,  // 接收到的位选信号
    input [7:0]     seg_data_0,  // 第0个数码管要显示的数据
    input [7:0]     seg_data_1,  // 第1个数码管要显示的数据
    input [7:0]     seg_data_2,  // 第2个数码管要显示的数据
    input [7:0]     seg_data_3,  // 第3个数码管要显示的数据
    input [7:0]     seg_data_4,  // 第4个数码管要显示的数据
    input [7:0]     seg_data_5,  // 第5个数码管要显示的数据
    input [7:0]     seg_data_6,  // 第6个数码管要显示的数据
    input [7:0]     seg_data_7   // 第7个数码管要显示的数据
);

// 参数定义
parameter SCAN_FREQ = 200;      // 数码管扫描频率，单位Hz
parameter CLK_FREQ = 125000000;  // 系统时钟频率，50MHz

// 计算每个数码管的显示时间计数周期
// 总扫描频率 = 每个数码管的扫描频率 × 数码管数量
parameter SCAN_COUNT = 78124;

// 内部寄存器定义
reg [31:0] scan_timer;  // 扫描定时计数器，用于控制每个数码管的显示时间
reg [3:0]  scan_sel;    // 扫描选择计数器，用于循环选择8个数码管

// 扫描定时器和选择计数器控制逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin  // 复位时初始化
        scan_timer <= 32'd0;  // 定时器清零
        scan_sel <= 4'd0;     // 选择计数器清零，指向第0个数码管
    end
    else if (scan_timer >= SCAN_COUNT) begin  // 达到扫描时间周期
        scan_timer <= 32'd0;  // 定时器重新开始计数
        if (scan_sel == 4'd7)  // 如果当前是最后一个数码管(第7个)
            scan_sel <= 4'd0; // 回到第0个数码管，实现循环扫描
        else
            scan_sel <= scan_sel + 4'd1;  // 否则选择下一个数码管
    end
    else begin  // 未达到扫描时间周期，继续计数
        scan_timer <= scan_timer + 32'd1;  // 定时器递增
    end
end

// 数码管位选和段选数据输出逻辑
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin  // 复位时关闭所有数码管显示
        seg_sel <= 8'hff;  // 所有位选置高，数码管不显示
        seg_data <= 8'hff;        // 所有段选置高，段全部熄灭
    end
    else begin  // 正常工作状态
        case (scan_sel)  // 根据扫描选择计数器选择对应的数码管
            // 第0个数码管
            4'd0: begin
                seg_sel <= rx_seg_sel[0] ? 8'b1111_1111 : 8'b1111_1110;  // 使用rx_seg_sel控制位选
                seg_data <= seg_data_0;  // 输出第0个数码管的段选数据

            end
            // 第1个数码管
            4'd1: begin
                seg_sel <= rx_seg_sel[1] ? 8'b1111_1111 : 8'b1111_1101;  // 使用rx_seg_sel控制位选
                seg_data <= seg_data_1;  // 输出第1个数码管的段选数据

            end
            // 第2个数码管
            4'd2: begin
                seg_sel <= rx_seg_sel[2] ? 8'b1111_1111 : 8'b1111_1011;  // 使用rx_seg_sel控制位选
                seg_data <= seg_data_2;  // 输出第2个数码管的段选数据

            end
            // 第3个数码管
            4'd3: begin
                seg_sel <= rx_seg_sel[3] ? 8'b1111_1111 : 8'b1111_0111;  // 使用rx_seg_sel控制位选
                seg_data <= seg_data_3;  // 输出第3个数码管的段选数据

            end
            // 第4个数码管
            4'd4: begin
                seg_sel <= rx_seg_sel[4] ? 8'b1111_1111 : 8'b1110_1111;  // 使用rx_seg_sel控制位选
                seg_data <= seg_data_4;  // 输出第4个数码管的段选数据

            end
            // 第5个数码管
            4'd5: begin
                seg_sel <= rx_seg_sel[5] ? 8'b1111_1111 : 8'b1101_1111;  // 使用rx_seg_sel控制位选
                seg_data <= seg_data_5;  // 输出第5个数码管的段选数据

            end
            // 第6个数码管
            4'd6: begin
                seg_sel <= rx_seg_sel[6] ? 8'b1111_1111 : 8'b1011_1111;  // 使用rx_seg_sel控制位选
                seg_data <= seg_data_6;  // 输出第6个数码管的段选数据

            end
            // 第7个数码管
            4'd7: begin
                seg_sel <= rx_seg_sel[7] ? 8'b1111_1111 : 8'b0111_1111;  // 使用rx_seg_sel控制位选
                seg_data <= seg_data_7;  // 输出第7个数码管的段选数据

            end
            // 默认情况
            default: begin
                seg_sel <= 8'b1111_1111;  // 关闭所有数码管
                seg_data <= 8'hff;        // 段选全部熄灭

            end
        endcase
    end
end
endmodule