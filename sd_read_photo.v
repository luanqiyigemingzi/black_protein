module sd_read_photo(
    input                clk           ,  //时钟信号
    input                rst_n         ,  //复位信号,低电平有效

    input        [23:0]  ddr_max_addr  ,  //DDR最大读写地址  
    input        [15:0]  sd_sec_num    ,  //SD卡扇区总数
    input                rd_busy       ,  //SD卡读忙信号
    input                sd_rd_val_en  ,  //SD卡读数据有效信号
    input        [15:0]  sd_rd_val_data,  //SD卡读数据
    output  reg          rd_start_en   ,  //开始读SD卡信号
    output  reg  [31:0]  rd_sec_addr   ,  //读扇区地址
    output  reg          sdr_wr_en     ,  //sdram写使能信号
    output       [23:0]  sdr_wr_data    ,  //sdram写数据,
    input                    full_flag_sdr
    );

//参数定义                          

parameter PHOTO_SECTION_ADDR0 = 32'd8480;//第一张图片扇区起始地址

//BMP文件头部数据=BMP文件头+信息头
parameter BMP_HEAD_NUM = 6'd54;           //BMP文件头+信息头=14+40=54

//寄存器定义
reg    [1:0]          rd_flow_cnt      ;  //读流程控制计数器
reg    [15:0]         rd_sec_cnt       ;  //读扇区计数器
reg                   rd_addr_sw       ;  //读取图片切换
reg    [25:0]         delay_cnt        ;  //延时切换图片计数器
reg                   bmp_rd_done      ;  //单张图片读取完成

reg                   rd_busy_d0       ;  //读忙信号打拍，用于检测下降沿
reg                   rd_busy_d1       ;  

reg    [1:0]          val_en_cnt       ;  //SD卡数据有效计数器
reg    [15:0]         val_data_t       ;  //SD卡数据有效缓存
reg    [5:0]          bmp_head_cnt     ;  //BMP头部计数器
reg                   bmp_head_flag    ;  //BMP头部标志
reg    [23:0]         rgb888_data      ;  //24位RGB888数据
reg    [23:0]         ddr_wr_cnt       ;  //DDR写数据计数器
reg    [1:0]          ddr_flow_cnt     ;  //DDR写数据流程控制计数器

//线网定义
wire                  neg_rd_busy      ;  //SD卡读忙信号下降沿
      
//*****************************************************
//**                    main code
//*****************************************************

//检测SD卡读忙信号下降沿
assign  neg_rd_busy = rd_busy_d1 & (~rd_busy_d0);
//24位RGB888格式转16位RGB565格式
assign  sdr_wr_data = rgb888_data;//[23:19],rgb888_data[15:10],rgb888_data[7:3];

//对rd_busy信号进行打拍延时，用于检测rd_busy信号的下降沿
always @(posedge clk or negedge rst_n) begin
    if(rst_n == 1'b0) begin
        rd_busy_d0 <= 1'b0;
        rd_busy_d1 <= 1'b0;
    end
    else begin
        rd_busy_d0 <= rd_busy;
        rd_busy_d1 <= rd_busy_d0;
    end
end

//循环读取SD卡中的两张图片，读取完成后延时1s再读下一张
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        rd_flow_cnt <= 2'd0;
        rd_addr_sw <= 1'b0;
        rd_sec_cnt <= 16'd0;
        rd_start_en <= 1'b0;
        rd_sec_addr <= 32'd0;
        bmp_rd_done <= 1'b0;
        delay_cnt <= 26'd0;
    end
    else begin
        rd_start_en <= 1'b0;
        // bmp_rd_done <= 1'b0;
        case(rd_flow_cnt)
            2'd0 : begin
                //开始读取SD卡数据 //读完一张图片后停止
                if(bmp_rd_done == 1'b0)begin
                rd_flow_cnt <= rd_flow_cnt + 2'd1;
                rd_start_en <= 1'b1;
                rd_sec_addr <= PHOTO_SECTION_ADDR0;
                end
                else
                rd_flow_cnt <=2'b0;
            end
            2'd1 : begin
                //忙信号下降沿处理完成一个扇区，开始读取下一个扇区地址
                if(neg_rd_busy) begin                          
                    rd_sec_cnt <= rd_sec_cnt + 1'b1;
                    rd_sec_addr <= rd_sec_addr + 32'd1;
					//单张图片读完
                    if(rd_sec_cnt == sd_sec_num - 1'b1) begin
                        rd_sec_cnt <= 16'd0;
                        rd_flow_cnt <= rd_flow_cnt + 2'd1;
                        bmp_rd_done <= 1'b1;
                    end    
                    else
                        rd_start_en <= 1'b1;                   
                end                    
            end
            2'd2 : begin
                delay_cnt <= delay_cnt + 1'b1;                 //单张图片读取完成后延时1秒
                if(delay_cnt == 26'd50_000_000 - 26'd1) begin  //50_000_000*20ns = 1s
                    delay_cnt <= 26'd0;
                    rd_flow_cnt <= 2'd0;
                end 
            end    
            default : ;
        endcase    
    end
end



//SD卡读取的16位数据，转换成24位RGB888格式
always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        val_en_cnt <= 2'd0;
        val_data_t <= 16'd0; 
        bmp_head_cnt <= 6'd0;
        sdr_wr_en <= 1'b0;
        rgb888_data <= 24'd0;
        ddr_wr_cnt <= 24'd0;
        ddr_flow_cnt <= 2'd0;
    end
    else begin
        sdr_wr_en <= 1'b0;
        case(ddr_flow_cnt)
            2'd0 : begin   //BMP头部数据处理         
                if(sd_rd_val_en) begin
                    bmp_head_cnt <= bmp_head_cnt + 1'b1;
                    if(bmp_head_cnt == BMP_HEAD_NUM[5:1] - 1'b1) begin
                        ddr_flow_cnt <= ddr_flow_cnt + 1'b1;
                        bmp_head_cnt <= 6'd0;
                    end    
                end   
            end                
            2'd1 : begin   //BMP有效数据
                if(sd_rd_val_en) begin
                    val_en_cnt <= val_en_cnt + 1'b1;
                    val_data_t <= sd_rd_val_data;                
                    if(val_en_cnt == 2'd1) begin  //3个16位数据转2个24位数据
                        sdr_wr_en <= 1'b1;
                        rgb888_data <= {sd_rd_val_data[15:8],val_data_t[7:0],
                                       val_data_t[15:8]}; 
                    end
                    else if(val_en_cnt == 2'd2) begin
                        sdr_wr_en <= 1'b1;
                        rgb888_data <= {sd_rd_val_data[7:0],sd_rd_val_data[15:8],
                                        val_data_t[7:0]};
                        val_en_cnt <= 2'd0;
                    end   
                end     
                if(sdr_wr_en) begin
                    ddr_wr_cnt <= ddr_wr_cnt + 1'b1;
                    if(ddr_wr_cnt == ddr_max_addr - 1'b1) begin
                        ddr_wr_cnt <= 24'd0;
                        ddr_flow_cnt <= ddr_flow_cnt + 1'b1;
                    end
                end
            end
            2'd2 : begin //等待单张BMP图片读取完成
                if(bmp_rd_done)
                    ddr_flow_cnt <= 2'd0;
            end
            default :;
        endcase
    end
end

endmodule