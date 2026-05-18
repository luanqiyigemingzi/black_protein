`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: anlgoic
// Author: 	xg 
// description:  顶层模块
//////////////////////////////////////////////////////////////////////////////////

`define DEBUG

`include "./src/sdram/enc_file/global_def.v"

module sdram_top(
    input                                    SYS_CLK                 ,  //系统时钟
    input                                    rst_n                   ,  //复位信号，低电平有效
    input                                    sd_clk                  ,  //SD卡时钟
    output                                   sdr_clk                 ,  //SDRAM时钟
    output                                   LED                     ,  //LED指示灯
    output                                   Sdr_init_done           ,  //SDRAM初始化完成
    output                                   wr_done                 ,  //写完成信号
    input                                    sdr_data_valid          ,  //SDRAM数据有效
    input              [  23: 0]             sdr_data                ,  //SDRAM数据输入
    output                                   Sdr_rd_en               ,  //SDRAM读使能
    output             [`DATA_WIDTH-1: 0]    Sdr_rd_dout             ,  //SDRAM读数据输出
    input                                    full_flag               ,  //FIFO满标志
    output                                   full_flag_sdr  ,  //SDRAM满标志
    input           [11:0]udp_wrusedw           //UDP写使用量
    );



wire                                lock,local_clk,Clk,Clk_sft,Rst/*synthesis syn_keep=1 */;

`ifndef SIMULATION
wire                                SDRAM_CLK                   ;  //SDRAM时钟
wire                                SDR_RAS                     ;  //SDRAM行地址选通
wire                                SDR_CAS                     ;  //SDRAM列地址选通
wire                                SDR_WE                      ;  //SDRAM写使能
wire               [`BA_WIDTH-1: 0]        SDR_BA                      ;  //SDRAM Bank地址
wire               [`ROW_WIDTH-1: 0]        SDR_ADDR                    ;  //SDRAM地址总线
wire               [`DATA_WIDTH-1: 0]        SDR_DQ                      ;  //SDRAM数据总线
wire               [`DM_WIDTH-1: 0]        SDR_DM                      ;  //SDRAM数据掩码
`endif

wire                                Sdr_init_ref_vld            ;//SDRAM初始化刷新有效信号//synthesis keep

wire                                App_wr_en                   ;//应用层写使能//synthesis keep
wire               [`ADDR_WIDTH-1: 0]        App_wr_addr                 ;//应用层写地址//synthesis keep
wire               [`DM_WIDTH-1: 0]        App_wr_dm                   ;//应用层写数据掩码
wire               [`DATA_WIDTH-1: 0]        App_wr_din                  ;//应用层写数据输入//synthesis keep

wire                                App_rd_en                   ;//应用层读使能//synthesis keep
wire               [`ADDR_WIDTH-1: 0]        App_rd_addr                 ;//应用层读地址//synthesis keep


wire                                Check_ok                    ;//检查完成信号//synthesis keep

    assign                              LED                         = Check_ok;  //LED显示检查状态

//时钟锁相环模块
clk_pll u0_clk(
    .refclk                             (SYS_CLK                   ),  //参考时钟输入
    .reset                              (1'b0                      ),  //复位信号
    .extlock                            (lock                      ),  //锁定信号
    .clk0_out                           (local_clk                 ),  //时钟输出0
    .clk1_out                           (Clk                       ),  //时钟输出1
    .clk2_out                           (Clk_sft                   )   //时钟输出2（相位偏移）
        );
        
    assign                              sdr_clk                     = Clk;  //SDRAM时钟分配
    assign                              Rst_n                       = rst_n & lock;  //系统复位信号
wire                                Sdr_busy                    ;  //SDRAM忙信号

wire                                wr_done                     ;  //写完成信号
//应用层读写控制模块
app_wrrd u1_app_wrrd(
    .clk                                (Clk                       ),  //时钟
    .sd_clk                             (SYS_CLK                   ),  //SD卡时钟
    .rst_n                              (Rst_n                     ),  //复位信号
    .full_flag_net                      (full_flag                 ),  //网络满标志
    .Sdr_init_done                      (Sdr_init_done             ),  //SDRAM初始化完成
    .Sdr_init_ref_vld                   (Sdr_init_ref_vld          ),  //SDRAM初始化刷新有效
    .sdr_data_valid                     (sdr_data_valid            ),  //SDRAM数据有效
    .sdr_data                           (sdr_data                  ),  //SDRAM数据
    .App_wr_en                          (App_wr_en                 ),  //应用层写使能
    .App_wr_addr                        (App_wr_addr               ),  //应用层写地址
    .App_wr_dm                          (App_wr_dm                 ),  //应用层写数据掩码
    .App_wr_din                         (App_wr_din                ),  //应用层写数据输入
    .wr_done                            (wr_done                   ),  //写完成
    .App_rd_en                          (App_rd_en                 ),  //应用层读使能
    .App_rd_addr                        (App_rd_addr               ),  //应用层读地址
    .Sdr_rd_en                          (Sdr_rd_en                 ),  //SDRAM读使能
    .Sdr_rd_dout                        (Sdr_rd_dout               ),  //SDRAM读数据输出
    .Sdr_busy                           (Sdr_busy                  ),  //SDRAM忙信号
    .full_flag                          (full_flag_sdr             ) , //SDRAM满标志
    .udp_wrusedw(udp_wrusedw)  //UDP写使用量
		// .Check_ok(Check_ok)
    );

//SDRAM控制器模块（配置为RAM模式）
sdr_as_ram  #( .self_refresh_open(1'b1))  //开启自刷新
    u2_ram(
    .Sdr_clk                            (Clk                       ),  //SDRAM时钟
    .Sdr_clk_sft                        (Clk_sft                   ),  //SDRAM相位偏移时钟
    .Rst                                (!Rst_n                    ),  //复位信号（高电平有效）
			  			  
    .Sdr_init_done                      (Sdr_init_done             ),  //SDRAM初始化完成
    .Sdr_init_ref_vld                   (Sdr_init_ref_vld          ),  //SDRAM初始化刷新有效
    .Sdr_busy                           (Sdr_busy                  ),  //SDRAM忙信号
		
    .App_ref_req                        (1'b0                      ),  //应用层刷新请求（未使用）
		
    .App_wr_en                          (App_wr_en                 ),  //应用层写使能
    .App_wr_addr                        (App_wr_addr               ),  //应用层写地址
    .App_wr_dm                          (App_wr_dm                 ),  //应用层写数据掩码
    .App_wr_din                         (App_wr_din                ),  //应用层写数据输入

    .App_rd_en                          (App_rd_en                 ),  //应用层读使能
    .App_rd_addr                        (App_rd_addr               ),  //应用层读地址
    .Sdr_rd_en                          (Sdr_rd_en                 ),  //SDRAM读使能
    .Sdr_rd_dout                        (Sdr_rd_dout               ),  //SDRAM读数据输出
	
    .SDRAM_CLK                          (SDRAM_CLK                 ),  //SDRAM时钟输出
    .SDR_RAS                            (SDR_RAS                   ),  //SDRAM行地址选通
    .SDR_CAS                            (SDR_CAS                   ),  //SDRAM列地址选通
    .SDR_WE                             (SDR_WE                    ),  //SDRAM写使能
    .SDR_BA                             (SDR_BA                    ),  //SDRAM Bank地址
    .SDR_ADDR                           (SDR_ADDR                  ),  //SDRAM地址总线
    .SDR_DM                             (SDR_DM                    ),  //SDRAM数据掩码
    .SDR_DQ                             (SDR_DQ                    )   //SDRAM数据总线
    );


    assign                              SDR_CKE                     = 1'b1;  //SDRAM时钟使能（常开）

//SDRAM物理器件实例化
//`ifndef SIMULATION
    EG_PHY_SDRAM_2M_32 sdram(
    .clk                                (SDRAM_CLK                 ),  //时钟
    .ras_n                              (SDR_RAS                   ),  //行地址选通（低电平有效）
    .cas_n                              (SDR_CAS                   ),  //列地址选通（低电平有效）
    .we_n                               (SDR_WE                    ),  //写使能（低电平有效）
    .addr                               (SDR_ADDR[10:0]            ),  //地址总线
    .ba                                 (SDR_BA                    ),  //Bank地址
    .dq                                 (SDR_DQ                    ),  //数据总线
    .cs_n                               (1'b0                      ),  //片选（低电平有效，常选）
    .dm0                                (SDR_DM[0]                 ),  //数据掩码0
    .dm1                                (SDR_DM[1]                 ),  //数据掩码1
    .dm2                                (SDR_DM[2]                 ),  //数据掩码2
    .dm3                                (SDR_DM[3]                 ),  //数据掩码3
    .cke                                (1'b1                      )   //时钟使能
        );
//`endif

endmodule