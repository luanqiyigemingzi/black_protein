module mux_total( 
     input  clk,
     input reset,
     input wire [39:0]data,
     output      [7:0] seg_sel,                // 数码管位选输出
     output      [7:0] seg_data     // 数码管段选输出
);
//wire seg_sel;
//wire seg_data;
wire  [39:0]data;
wire[7:0]seg_data_0;
wire[7:0]seg_data_1;
wire[7:0]seg_data_2;
wire[7:0]seg_data_3;
wire[7:0]seg_data_4;
wire[7:0]seg_data_5;
wire[7:0]seg_data_6;
wire[7:0]seg_data_7;
wire [7:0] index ;
assign index=data[39:32];
// 实例化七段码译码器
seg_decoder seg_decoder_m0(
    .bin_data  (data[31:28]),  // 输入数据
    .seg_data  (seg_data_0)       // 七段码输出
);
// 实例化七段码译码器（高4位）
seg_decoder seg_decoder_m1(
    .bin_data  (data[27:24]),  // 二进制输入数据（高4位）
    .seg_data  (seg_data_1)       // 七段码输出
);
// 实例化七段码译码器（高4位）
seg_decoder seg_decoder_m2(
    .bin_data  (data[23:20]),  // 二进制输入数据（高4位）
    .seg_data  (seg_data_2)       // 七段码输出
);
// 实例化七段码译码器（高4位）
seg_decoder seg_decoder_m3(
    .bin_data  (data[19:16]),  // 二进制输入数据（高4位）
    .seg_data  (seg_data_3)       // 七段码输出
);
// 实例化七段码译码器
seg_decoder seg_decoder_m4(
    .bin_data  (data[15:12]),  // 二进制输入数据（低4位）
    .seg_data  (seg_data_4)       // 七段码输出
);
// 实例化七段码译码器（高4位）
seg_decoder seg_decoder_m5(
    .bin_data  (data[11:8]),  // 二进制输入数据（高4位）
    .seg_data  (seg_data_5)       // 七段码输出
);
// 实例化七段码译码器（高4位）
seg_decoder seg_decoder_m6(
    .bin_data  (data[7:4]),  // 二进制输入数据（高4位）
    .seg_data  (seg_data_6)       // 七段码输出
);
// 实例化七段码译码器（高4位）
seg_decoder seg_decoder_m7(
    .bin_data  (data[3:0]),  // 二进制输入数据（高4位）
    .seg_data  (seg_data_7)       // 七段码输出
);

// 实例化数码管扫描模块
seg_scan seg_scan_m0(
    .clk        (clk),                    // 时钟输入
    .rst_n      (reset),                  // 复位输入
    .seg_sel    (seg_sel),                // 数码管位选输出
    .seg_data   (seg_data),               // 数码管段选输出
    .rx_seg_sel (index),
    .seg_data_0 (seg_data_0),     // 第0位数码管
    .seg_data_1 (seg_data_1),     // 第1位数码管
    .seg_data_2 (seg_data_2),     // 第2位数码管
    .seg_data_3 (seg_data_3),     // 第3位数码管
    .seg_data_4 (seg_data_4),      // 第4位数码管
    .seg_data_5 (seg_data_5),      // 第5位数码管
    .seg_data_6 (seg_data_6),     // 第6位数码管
    .seg_data_7 (seg_data_7)     // 第7位数码管

);
endmodule
