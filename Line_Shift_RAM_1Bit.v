// 安路TD软件适配版：1位行移位RAM（实现1行/2行延迟）
module Line_Shift_RAM_1Bit
#(
    parameter   RAM_Length = 10'd640  // 图像水平分辨率（每行像素数）
)
(
    input               clock           ,  // 工作时钟（与像素时钟同步）
    input               rst_n           ,
    input               clken           ,  // 像素使能时钟（有效像素期间高）
    input               shiftin         ,  // 当前行像素输入（垂直方向第3行）
    output reg          taps0x          ,  // 延迟1行输出（垂直方向第2行）
    output reg          taps1x          ,  // 延迟2行输出（垂直方向第1行）
    output              shiftout           // 未使用，悬空
);

// ------------- 内部信号定义 -------------
reg [9:0]  x_cnt;                          // 列计数器（0~RAM_Length-1）：跟踪当前列位置
reg [9:0]  y_cnt;                          // 行计数器：跟踪当前行数（用于判断延迟有效性）

// 双端口RAM：存储2行1位像素数据（实现1行、2行延迟）
// RAM深度=RAM_Length（每行像素数），宽度=1位，共2行
reg [0:0]  ram_row1 [0:RAM_Length-1];      // 存储第1行（最早输入的行）
reg [0:0]  ram_row2 [0:RAM_Length-1];      // 存储第2行（中间行）

// ------------- 列计数器：0~RAM_Length-1循环计数 -------------
always @(posedge clock or negedge rst_n) begin
    if (!rst_n) begin
        x_cnt <= 10'd0;
    end else if(clken) begin
        if (x_cnt == RAM_Length - 1'd1) // 计数到每行最后一列，复位为0
            x_cnt <= 10'd0;
        else 
            x_cnt <= x_cnt + 1'd1;
    end
end

// ------------- 行计数器：统计当前输入行数 -------------
always @(posedge clock or negedge rst_n) begin
    if (!rst_n) begin
        y_cnt <= 10'd0;
    end else if(clken) begin
        if ((x_cnt == RAM_Length - 1'd1)&&(y_cnt == 10'd480 - 1'd1)) // 计数到每行最后一列，复位为0
           y_cnt <= 1'd0;
        else if(x_cnt==RAM_Length - 1'd1)
            y_cnt <= y_cnt + 1'd1;
    end
end

// ------------- 双端口RAM写操作：存储当前行、更新历史行 -------------
always @(posedge clock) begin
    if (clken) begin
        // 1. 先将第2行数据写入第1行（更新历史行：第2行→第1行，实现延迟累加）
        ram_row1[x_cnt] <= ram_row2[x_cnt];
        // 2. 将当前输入数据写入第2行（存储当前行：shiftin→第2行）
        ram_row2[x_cnt] <= {shiftin};
    end
end

// ------------- RAM读操作：输出延迟1行、2行数据 -------------
always @(posedge clock) begin
    if (clken) begin
        // taps0x：延迟1行 = 第2行数据（当前行的上1行）
        taps0x <= ram_row2[x_cnt][0];
        // taps1x：延迟2行 = 第1行数据（当前行的上2行）
        taps1x <= ram_row1[x_cnt][0];
    end else begin
        // 使能无效时，保持原有输出（避免数据抖动）
        taps0x <= taps0x;
        taps1x <= taps1x;
    end
end

// ------------- 未使用端口悬空 -------------
assign shiftout = 1'b0;

endmodule




//module Line_Shift_RAM_1Bit#(
//    parameter                           RAM_Length = 10'd640        
//)
//(
//    input                               clock                      ,
//    input                               clken                      ,
//    input                               shiftin                    ,
    
//    output reg                          taps0x                     ,//延迟1行输出
//    output reg                          taps1x                     ,//延迟2行输出
//    output                              shiftout                    
//);
////列计数器：跟踪当前列位置
//reg [9:0]x_cnt;
//always @(posedge clock or negedge clken)begin
//    if (!clken) 
//        x_cnt <= 10'd0;
//    else if(x_cnt == RAM_Length - 1'd1)
//        x_cnt <= 10'd0;
//    else 
//        x_cnt <=  x_cnt + 1'd1;
//end

////生成读写地址
//wire [9:0] addr_wr = x_cnt;
//wire [9:0] addr_rd1 = (x_cnt >= RAM_Length )?(x_cnt - RAM_Length):10'd0;//延时1行读地址

//wire taps0x_raw;
//wire taps1x_raw;
//Line_Shift_RAM_1Bit_Anlogic ram_1x(
//    .doa(taps0x_raw), 
//    .dia(shiftin), 
//    .addra(addr_wr), 
//    .cea(clken), 
//    .ocea(1'b1), 
//    .clka(clock), 
//    .wea(clken), 
//    .rsta(1'b1)
//    );

//Line_Shift_RAM_1Bit_Anlogic ram_2x(
//    .doa(taps1x_raw), 
//    .dia(taps0x_raw), 
//    .addra(addr_wr), 
//    .cea(clken), 
//    .ocea(1'b1), 
//    .clka(clock), 
//    .wea(clken), 
//    .rsta(1'b1)
//    );

////-----------------------------------------
////边界条件处理，过滤前2行无效数据
//always @(posedge clock or negedge clken) begin
//    if(!clken)begin
//        taps0x <= 1'b0;
//        taps1x <= 1'b0;
//    end else begin
//        taps0x <= (x_cnt >= RAM_Length) ? taps0x_raw : 1'b0;
//        taps1x <= (x_cnt >= 2*RAM_Length) ? taps1x_raw : 1'b0;
//    end
//end
//assign shiftout = 1'b0;

//endmodule
