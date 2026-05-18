// SD卡控制器顶层模块
// 功能：集成SD卡初始化、读取功能，提供用户接口
module sd_ctrl_top(
    input                clk_ref       ,  // 参考时钟信号
    input                clk_ref_180deg,  // 参考时钟信号，与clk_ref相位相差180度
    input                rst_n         ,  // 复位信号，低电平有效
    // SD卡接口
    input                sd_miso       ,  // SD卡SPI主入从出数据信号
    output               sd_clk        ,  // SD卡SPI时钟信号    
    output  reg          sd_cs         ,  // SD卡SPI片选信号
    output  reg          sd_mosi       ,  // SD卡SPI主出从入数据信号
    // 用户写SD卡接口（已注释掉）
    // input                wr_start_en   ,  // 开始写SD卡信号
    // input        [31:0]  wr_sec_addr   ,  // 写扇区地址
    // input        [15:0]  wr_data       ,  // 写数据                  
     output               wr_busy       ,  // 写操作忙信号
    // output               wr_req        ,  // 写数据请求信号    
    // 用户读SD卡接口
    input                rd_start_en   ,  // 开始读SD卡信号
    input        [31:0]  rd_sec_addr   ,  // 读扇区地址
    output               rd_busy       ,  // 读操作忙信号
    output               rd_val_en     ,  // 读数据有效信号
    output       [15:0]  rd_val_data   ,  // 读数据    
    
    output               sd_init_done     // SD卡初始化完成信号
    );

// 线网定义
wire                init_sd_clk   ;       // 初始化SD卡时的低速时钟
wire                init_sd_cs    ;       // 初始化模块SD片选信号
wire                init_sd_mosi  ;       // 初始化模块SD主出从入信号
wire                wr_sd_cs      ;       // 写操作模块SD片选信号     
wire                wr_sd_mosi    ;       // 写操作模块SD主出从入信号 
wire                rd_sd_cs      ;       // 读操作模块SD片选信号     
wire                rd_sd_mosi    ;       // 读操作模块SD主出从入信号 

//*****************************************************
//**                    主代码
//*****************************************************

// SD卡SPI_CLK时钟选择  
// 初始化期间使用低速时钟，初始化完成后使用参考时钟的180度相位时钟
assign  sd_clk = (sd_init_done==1'b0)  ?  init_sd_clk  :  clk_ref_180deg;

// SD卡接口信号选择
// 根据当前操作状态选择对应的控制信号
always @(*) begin
    // SD卡初始化完成之前，端口信号和初始化模块信号相连
    if(sd_init_done == 1'b0) begin     
        sd_cs = init_sd_cs;
        sd_mosi = init_sd_mosi;
    end    
    // 写操作忙期间，使用写操作模块信号
    else if(wr_busy) begin
        sd_cs = wr_sd_cs;
        sd_mosi = wr_sd_mosi;   
    end    
    // 读操作忙期间，使用读操作模块信号
    else if(rd_busy) begin
        sd_cs = rd_sd_cs;
        sd_mosi = rd_sd_mosi;       
    end    
    // 空闲状态，SD片选拉高，MOSI置高
    else begin
        sd_cs = 1'b1;
        sd_mosi = 1'b1;
    end    
end    

// SD卡初始化模块实例化
sd_init u_sd_init(
    .clk_ref            (clk_ref),        // 参考时钟
    .rst_n              (rst_n),          // 复位信号
    
    .sd_miso            (sd_miso),        // SD卡SPI输入
    .sd_clk             (init_sd_clk),    // 初始化时钟输出
    .sd_cs              (init_sd_cs),     // 初始化片选输出
    .sd_mosi            (init_sd_mosi),   // 初始化数据输出
    
    .sd_init_done       (sd_init_done)    // 初始化完成标志
    );

// // SD卡写操作模块（已注释掉）
// sd_write u_sd_write(
//     .clk_ref            (clk_ref),
//     .clk_ref_180deg     (clk_ref_180deg),
//     .rst_n              (rst_n),
    
//     .sd_miso            (sd_miso),
//     .sd_cs              (wr_sd_cs),
//     .sd_mosi            (wr_sd_mosi),
//     // SD卡初始化完成后响应写操作    
//     .wr_start_en        (wr_start_en & sd_init_done),  
//     .wr_sec_addr        (wr_sec_addr),
//     .wr_data            (wr_data),
//     .wr_busy            (wr_busy),
//     .wr_req             (wr_req)
//     );

// SD卡读操作模块实例化
sd_read u_sd_read(
    .clk_ref            (clk_ref),           // 参考时钟
    .clk_ref_180deg     (clk_ref_180deg),    // 180度相位参考时钟
    .rst_n              (rst_n),             // 复位信号
    
    .sd_miso            (sd_miso),           // SD卡SPI输入
    .sd_cs              (rd_sd_cs),          // 读操作片选输出
    .sd_mosi            (rd_sd_mosi),        // 读操作数据输出
    // SD卡初始化完成后响应读操作
    .rd_start_en        (rd_start_en & sd_init_done),  // 与初始化完成信号相与
    .rd_sec_addr        (rd_sec_addr),       // 读扇区地址
    .rd_busy            (rd_busy),           // 读忙标志
    .rd_val_en          (rd_val_en),         // 读数据有效
    .rd_val_data        (rd_val_data)        // 读数据输出
    );

endmodule