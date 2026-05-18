//****************************************Copyright (c)***********************************//
//原子哥在线教学平台：www.yuanzige.com
//技术支持：www.openedv.com
//淘宝店铺：http://openedv.taobao.com
//关注微信公众平台微信号："正点原子"，免费获取ZYNQ & FPGA & STM32 & LINUX资料。
//版权所有，盗版必究。
//Copyright(C) 正点原子 2018-2028
//All rights reserved
//----------------------------------------------------------------------------------------
// File name:           cmos_capture_data
// Last modified Date:  2020/05/04 9:19:08
// Last Version:        V1.0
// Descriptions:       摄像头数据采集模块
//                      
//----------------------------------------------------------------------------------------
// Created by:          正点原子
// Created date:        2019/05/04 9:19:08
// Version:             V1.0
// Descriptions:        The original version
//
//----------------------------------------------------------------------------------------
//****************************************************************************************//

module cmos_capture_data(
    input                 rst_n            ,  //复位信号    
    //摄像头接口                           
    input                 cam_pclk         ,  //cmos 数据像素时钟
    input                 cam_vsync        ,  //cmos 场同步信号
    input                 cam_href         ,  //cmos 行同步信号
    input  [7:0]          cam_data         ,  //cmos 数据                  
    //用户接口                              
    output                cmos_frame_vsync ,  //帧有效信号    
    output                cmos_frame_href  ,  //行有效信号
    output                cmos_frame_valid ,  //数据有效使能信号
    output       [15:0]   cmos_frame_data     //有效数据        
    );

//寄存器全局变量，等待摄像头稳定等10帧数据
//等待摄像头稳定后再开始采集图像
parameter  WAIT_FRAME = 4'd10    ;            //寄存器等待稳定等待帧数             
							     
//寄存器定义                     
reg             cam_vsync_d0     ;  //场同步信号打拍第0拍
reg             cam_vsync_d1     ;  //场同步信号打拍第1拍
reg             cam_href_d0      ;  //行同步信号打拍第0拍
reg             cam_href_d1      ;  //行同步信号打拍第1拍
reg    [3:0]    cmos_ps_cnt      ;  //等待帧稳定计数器
reg    [7:0]    cam_data_d0      ;  //摄像头数据打拍
reg    [15:0]   cmos_data_t      ;  //用于8位转16位数据的临时寄存器
reg             byte_flag        ;  //16位RGB数据转换过程的标志信号
reg             byte_flag_d0     ;  //byte_flag打拍
reg             frame_val_flag   ;  //帧有效的标志 

wire            pos_vsync        ;  //检测场同步信号的上升沿

//*****************************************************
//**                    main code
//*****************************************************

//检测场同步信号的上升沿
assign pos_vsync = (~cam_vsync_d1) & cam_vsync_d0; 

//输出帧有效信号
assign  cmos_frame_vsync = frame_val_flag  ?  cam_vsync_d1  :  1'b0; 

//输出行有效信号
assign  cmos_frame_href  = frame_val_flag  ?  cam_href_d1   :  1'b0; 

//输出数据使能有效信号
assign  cmos_frame_valid = frame_val_flag  ?  byte_flag_d0  :  1'b0; 

//输出数据
assign  cmos_frame_data  = frame_val_flag  ?  cmos_data_t   :  1'b0; 

//对输入信号进行打拍处理，同步时钟域并检测边沿
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n) begin
        cam_vsync_d0 <= 1'b0;
        cam_vsync_d1 <= 1'b0;
        cam_href_d0 <= 1'b0;
        cam_href_d1 <= 1'b0;
    end
    else begin
        cam_vsync_d0 <= cam_vsync;      //场同步打第0拍
        cam_vsync_d1 <= cam_vsync_d0;   //场同步打第1拍
        cam_href_d0 <= cam_href;        //行同步打第0拍
        cam_href_d1 <= cam_href_d0;     //行同步打第1拍
    end
end

//在帧开始时进行计数
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n)
        cmos_ps_cnt <= 4'd0;                                    //复位时计数器清零
    else if(pos_vsync && (cmos_ps_cnt < WAIT_FRAME))            //检测到场同步上升沿且未达到等待帧数
        cmos_ps_cnt <= cmos_ps_cnt + 4'd1;                      //计数器加1
end

//帧有效标志生成
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n)
        frame_val_flag <= 1'b0;                                 //复位时帧有效标志清零
    else if((cmos_ps_cnt == WAIT_FRAME) && pos_vsync)           //达到等待帧数且检测到场同步上升沿
        frame_val_flag <= 1'b1;                                 //设置帧有效标志
    else;                                                       //其他情况保持不变
end            

//8位数据转16位RGB565数据        
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n) begin                                            //复位时初始化所有寄存器
        cmos_data_t <= 16'd0;
        cam_data_d0 <= 8'd0;
        byte_flag <= 1'b0;
    end
    else if(cam_href) begin                                     //行有效期间进行数据转换
        byte_flag <= ~byte_flag;                                //字节标志取反，用于区分高低字节
        cam_data_d0 <= cam_data;                                //缓存当前字节数据
        if(byte_flag)                                           //当byte_flag为1时，表示已收到两个字节
            cmos_data_t <= {cam_data_d0,cam_data};              //将两个字节组合成16位数据
        else;                                                   //第一个字节时不做处理
    end
    else begin                                                  //行无效时清零相关寄存器
        byte_flag <= 1'b0;
        cam_data_d0 <= 8'b0;
    end    
end        

//生成最终的数据有效信号(cmos_frame_valid)
always @(posedge cam_pclk or negedge rst_n) begin
    if(!rst_n)
        byte_flag_d0 <= 1'b0;                                   //复位时数据有效信号清零
    else
        byte_flag_d0 <= byte_flag;	                            //将byte_flag打一拍输出
end 
       
endmodule