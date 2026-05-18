//****************************************Copyright (c)***********************************//
//ԭ�Ӹ����߽�ѧƽ̨��www.yuanzige.com
//����֧�֣�www.openedv.com
//�Ա����̣�http://openedv.taobao.com 
//��ע΢�Ź���ƽ̨΢�źţ�"����ԭ��"�����ѻ�ȡZYNQ & FPGA & STM32 & LINUX���ϡ�
//��Ȩ���У������ؾ���
//Copyright(C) ����ԭ�� 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           ov5640_dri
// Last modified Date:  2020/05/04 9:19:08
// Last Version:        V1.0
// Descriptions:        OV5640����ͷ����
//                      
//----------------------------------------------------------------------------------------
// Created by:          ����ԭ��
// Created date:        2019/05/04 9:19:08
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module ov5640_dri (
    input           clk             ,  // 系统主时钟
    input           rst_n           ,  // 系统低电平复位
    // 摄像头物理接口 
    input           cam_pclk        ,  // CMOS 像素时钟（像素同步）
    input           cam_vsync       ,  // CMOS 帧同步信号（场同步）
    input           cam_href        ,  // CMOS 行同步信号（行有效）
    input    [7:0]  cam_data        ,  // CMOS 8 位像素数据
    output          cam_rst_n       ,  // CMOS 复位输出，低电平有效
    output          cam_pwdn        ,  // CMOS 电源/休眠模式选择，0 为工作
    output          cam_scl         ,  // CMOS SCCB 串行时钟（I2C 兼容）
    inout           cam_sda         ,  // CMOS SCCB 串行数据（I2C 兼容）
    
    // 分辨率参数输入接口
    input    [12:0] cmos_h_pixel    ,  // 实际有效水平像素个数（列）
    input    [12:0] cmos_v_pixel    ,  // 实际有效垂直像素个数（行）
    input    [12:0] total_h_pixel   ,  // 总行像素（含消隐）
    input    [12:0] total_v_pixel   ,  // 总场像素（含消隐）
    input           capture_start   ,  // 图像采集开始使能（高有效）
    output          cam_init_done   ,  // 摄像头初始化完成标志
    output                cmos_frame_vsync ,  //帧有效信号    
    output                cmos_frame_href  ,  //行有效信号
    output                cmos_frame_valid ,  //数据有效使能信号
    output       [15:0]   cmos_frame_data     //有效数据    
    
);

//parameter define
parameter SLAVE_ADDR = 7'h3c          ; // OV5640 的 7 位 I2C 地址
parameter BIT_CTRL   = 1'b1           ; // 1=16 位寄存器地址，0=8 位
parameter CLK_FREQ   = 27'd50_000_000 ; // 驱动模块参考时钟 50 MHz
parameter I2C_FREQ   = 18'd250_000    ; // I2C 时钟 250 kHz（低于 400 kHz）

//wire difine
wire        i2c_exec       ;  // 触发一次 I2C 写寄存器
wire [23:0] i2c_data       ;  // {16'h寄存器地址, 8'h写入值}
wire        i2c_done       ;  // I2C 单字节写入完成
wire        i2c_dri_clk    ;  // I2C 驱动时钟（由 i2c_dri 产生）
wire [ 7:0] i2c_data_r     ;  // I2C 读出的数据（本设计未使用）
wire        i2c_rh_wl      ;  // 1=读，0=写（本设计仅写）

//*****************************************************
//**                    main code                      
//*****************************************************

// 摄像头电源/休眠控制：0 为正常工作，1 为休眠
assign  cam_pwdn  = 1'b0;
// 摄像头复位：1 为退出复位（高电平有效复位内部已反相）
assign  cam_rst_n = 1'b1;
    
// I2C 配置序列生成器：产生上电初始化寄存器表
i2c_ov5640_rgb565_cfg u_i2c_cfg(
    .clk                (i2c_dri_clk),
    .rst_n              (rst_n),
            
    .i2c_exec           (i2c_exec),
    .i2c_data           (i2c_data),
    .i2c_rh_wl          (i2c_rh_wl),        // 固定为 0，只写
    .i2c_done           (i2c_done), 
    .i2c_data_r         (i2c_data_r),   
                
    .cmos_h_pixel       (cmos_h_pixel),     // 实际水平像素
    .cmos_v_pixel       (cmos_v_pixel) ,    // 实际垂直像素
    .total_h_pixel      (total_h_pixel),    // 总行像素
    .total_v_pixel      (total_v_pixel),    // 总场像素
        
    .init_done          (cam_init_done)     // 初始化完成标志
    );    

// I2C 底层驱动：完成 SCCB/I2C 时序
i2c_dri #(
    .SLAVE_ADDR         (SLAVE_ADDR),       // 从机地址
    .CLK_FREQ           (CLK_FREQ  ),       // 模块时钟
    .I2C_FREQ           (I2C_FREQ  )        // 目标 SCL 频率
    )
u_i2c_dr(
    .clk                (clk),
    .rst_n              (rst_n     ),

    .i2c_exec           (i2c_exec  ),   
    .bit_ctrl           (BIT_CTRL  ),       // 寄存器地址 16 位
    .i2c_rh_wl          (i2c_rh_wl),        // 固定写
    .i2c_addr           (i2c_data[23:8]),   // 寄存器地址
    .i2c_data_w         (i2c_data[7:0]),    // 写入值
    .i2c_data_r         (i2c_data_r),   
    .i2c_done           (i2c_done  ),
    
    .scl                (cam_scl   ),       // 输出到摄像头的 SCL
    .sda                (cam_sda   ),       // 双向 SDA

    .dri_clk            (i2c_dri_clk)       // 返回给配置模块的时钟
    );
wire cmos_frame_vsync;   // 帧开始脉冲
wire cmos_frame_href;    // 行开始脉冲
wire cmos_frame_valid;   // 像素有效
wire cmos_frame_data;     
// 像素采集与打包：将 8 位 RAW → 16 位 RGB565，并产生行/帧同步
cmos_capture_data u_cmos_capture_data(      // 等待系统初始化完成后再采集
    .rst_n              (rst_n & capture_start),
    
    .cam_pclk           (cam_pclk),
    .cam_vsync          (cam_vsync),
    .cam_href           (cam_href),
    .cam_data           (cam_data),         
    
    .cmos_frame_vsync   (cmos_frame_vsync), // 帧开始脉冲
    .cmos_frame_href    (cmos_frame_href ), // 行开始脉冲
    .cmos_frame_valid   (cmos_frame_valid), // 像素有效
    .cmos_frame_data    (cmos_frame_data)  // 16 位 RGB565 数据
    );
endmodule