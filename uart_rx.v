module uart_rx
#(
    parameter   UART_BPS = 'd9600,        // 串口波特率，默认9600
    parameter   CLK_FREQ = 'd50_000_000   // 系统时钟频率，默认50MHz
)
(   
    // 输入输出端口声明
    input   wire        sys_clk     ,      // 系统时钟输入
    input   wire        sys_rst_n   ,      // 系统复位信号，低电平有效
    input   wire        rx          ,      // 串口接收数据线

    output  reg  [7:0]  po_data     ,      // 并行数据输出，接收到的8位数据
    output  reg         po_flag            // 数据有效标志信号，高电平表示数据有效
);

    // 波特率计数器最大值计算：系统时钟频率 / 波特率
    parameter   BAUD_CNT_MAX = CLK_FREQ / UART_BPS ;
    
    // 中间变量声明
    reg         rx_reg1     ;  // 第一级同步寄存器
    reg         rx_reg2     ;  // 第二级同步寄存器
    reg         rx_reg3     ;  // 第三级同步寄存器，用于边沿检测
    reg         start_flag  ;  // 起始位检测标志
    reg         word_en     ;  // 字节接收使能信号
    reg  [15:0] baud_cnt    ;  // 波特率计数器
    reg         bit_flag    ;  // 比特采样标志
    reg  [3:0]  bit_cnt     ;  // 比特计数器
    reg  [7:0]  rx_data     ;  // 接收数据移位寄存器
    reg         rx_flag     ;  // 接收完成标志
    
    // 时序逻辑
    // 打两拍同步，相当于加了两个触发器，用于消除亚稳态
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            rx_reg1 <= 1'b1;        // 复位时置高电平（空闲状态）
        else 
            rx_reg1 <= rx;          // 第一级同步
            
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            rx_reg2 <= 1'b1;        // 复位时置高电平
        else 
            rx_reg2 <= rx_reg1;     // 第二级同步
    
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            rx_reg3 <= 1'b1;        // 复位时置高电平
        else 
            rx_reg3 <= rx_reg2;     // 第三级同步，用于边沿检测
    
    // 起始位检测逻辑：检测下降沿（从空闲位1到起始位0的跳变）
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)  
            start_flag <= 1'b0;     // 复位时清除起始标志
        else if((rx_reg3 == 1'b1) && (rx_reg2 == 1'b0) && word_en ==1'b0)
            start_flag <= 1'b1;     // 检测到下降沿且不在接收过程中
        else
            start_flag <= 1'b0;     // 其他情况清除起始标志
    
    // 字节接收使能控制
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)     
            word_en <= 1'b0;        // 复位时禁用接收
        else if(start_flag == 1'b1)
            word_en <= 1'b1;        // 检测到起始位，开始接收
        else if((bit_cnt ==4'd8) && (bit_flag ==1'b1))
            word_en <= 1'b0;        // 接收完8位数据，停止接收
        else
            word_en <= word_en;     // 保持当前状态
    
    // 波特率计数器：用于生成正确的采样时序
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)    
            baud_cnt <= 16'd0;      // 复位时计数器清零
         else if((baud_cnt == BAUD_CNT_MAX - 1'b1 ) || (word_en == 1'b0))
            baud_cnt <= 16'd0;      // 计数到最大值或接收结束时清零
         else if(word_en == 1'b1)
            baud_cnt <= baud_cnt + 1'b1;  // 接收过程中计数器递增
    
    // 比特采样标志生成：在比特中间位置采样
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)      
            bit_flag <= 1'b0;       // 复位时清除采样标志
        else if(baud_cnt == BAUD_CNT_MAX /2 - 1'b1)  
            bit_flag <= 1'b1;       // 在比特中间位置产生采样脉冲
        else
            bit_flag <= 1'b0;       // 其他情况清除采样标志
    
    // 比特计数器：计数已接收的比特数
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)    
            bit_cnt <= 4'd0;        // 复位时计数器清零
        else if((bit_cnt == 4'd8) && (bit_flag == 1'b1))
            bit_cnt <= 4'd0;        // 接收完8位后清零
        else if(bit_flag == 1'b1)
            bit_cnt <= bit_cnt + 1'b1;  // 每采样一个比特计数器加1
    
    // 数据移位拼接：从低位到高位依次移位接收
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)
            rx_data <= 8'd0;        // 复位时数据寄存器清零
        else if((bit_cnt >= 4'd1) && (bit_cnt<= 4'd8) && (bit_flag == 1'b1))
            rx_data <= {rx_reg3 , rx_data[7:1]};  // 右移拼接新数据
    
    // 接收完成标志生成
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)      
            rx_flag <= 1'b0;        // 复位时清除接收标志
        else if((bit_cnt == 4'd8) && (bit_flag == 1'b1))
            rx_flag <= 1'b1;        // 接收完8位数据后置位标志
        else
            rx_flag <= 1'b0;        // 其他情况清除标志
    
    // 输出数据赋值：将接收到的数据输出
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)        
            po_data <= 8'd0;        // 复位时输出数据清零
        else if(rx_flag == 1'b1)
            po_data <= rx_data;     // 接收完成后输出数据
    
    // 输出标志信号：指示数据有效
    always@(posedge sys_clk or negedge sys_rst_n)
        if(!sys_rst_n)         
            po_flag <= 1'b0;        // 复位时输出标志清零
        else
            po_flag <= rx_flag;     // 输出接收完成标志
         
endmodule