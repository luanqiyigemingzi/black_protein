module addr_crt (
 input         clk,          // 时钟信号
 input         rst_n,        // 复位信号，低电平有效
 input   [7:0] udp_data,     // UDP输入数据
 input         udp_vaild,    // UDP数据有效信号
 input   [15:0]udp_length,   // UDP数据长度
 
 output reg [15:0] wr_addr,  // 写地址输出
 output reg       wr_en,     // 写使能输出
 output        rd_en,        // 读使能输出
 output  [23:0] ram_data     // RAM数据输出
);

reg done;  // 完成标志
assign rd_en=done;  // 读使能连接到完成标志

reg [7:0] ram_data_1;  // RAM数据第一部分（R分量）
reg [7:0] ram_data_2;  // RAM数据第二部分（G分量）
reg [7:0] ram_data_3;  // RAM数据第三部分（B分量）

// 将三个8位数据拼接成24位RGB数据
assign ram_data = {ram_data_1,ram_data_2,ram_data_3};

reg flag;           // 数据包开始标志
reg [15:0] wr_addr_cnt;  // 写地址计数器
reg [2:0] cnt;      // 数据包内字节计数器

// 主要数据处理逻辑
always @(posedge clk or negedge rst_n ) begin
    if(!rst_n)begin  // 复位初始化
    wr_addr_cnt<=0;
        wr_en<=0;
            ram_data_1<=0;
            ram_data_2<=0;
            ram_data_3<=0;
            done<=0;
    end
        else if (udp_vaild  & cnt==0)  // 接收到数据包第一个字节
            begin
                wr_en<=1'b1;
                // 检查是否为数据包起始标志0xf1
                flag<=(udp_data == 8'hf1)?1'b1:1'b0;
            end
            else if (udp_vaild  & cnt==5 & flag)  // 接收第6个字节（B分量）
            begin
                wr_en<=1'b1;
                ram_data_3<=udp_data;  // 存储蓝色分量
            end
    else if (udp_vaild  & cnt==4 & flag)  // 接收第5个字节（G分量）
            begin
                wr_en<=1'b1;
                ram_data_2<=udp_data;  // 存储绿色分量
            end
    else if (udp_vaild  & cnt==3 & flag)  // 接收第4个字节（R分量）
            begin
                wr_en<=1'b1;
                ram_data_1<=udp_data;  // 存储红色分量
            end
            else if (udp_vaild & cnt==2 & flag)  // 接收第3个字节（地址低8位）
            begin
                wr_en<=1'b1;
                wr_addr[7:0]<=udp_data;  // 存储地址低8位
            end
            else if (udp_vaild &  cnt==1 & flag)  // 接收第2个字节（地址高8位）
            begin
                wr_en<=1'b1;
                wr_addr[15:8]<=udp_data;  // 存储地址高8位
            end
        else begin  // 其他情况保持当前值
                wr_en<=1'b0;
                ram_data_1<=ram_data_1;
                ram_data_2<=ram_data_2;
                ram_data_3<=ram_data_3;
        end

end

// 字节计数器控制逻辑
always @(posedge clk or negedge rst_n ) begin
    if(!rst_n)begin  // 复位清零
    cnt<=0;
    end
    else if (udp_vaild & cnt==0  & udp_data == 8'hf1)begin  // 检测到起始标志，开始计数
    cnt<=cnt+1;
    end 
    else if (udp_vaild & cnt>0 & cnt<5  & flag)begin  // 在有效数据包内递增计数
    cnt<=cnt+1;
    end 
    else if (udp_vaild & cnt==5)  // 完成一个数据包，重置计数器
    cnt<=0;
    else  // 其他情况保持当前值
    cnt <= cnt;   
end

endmodule

// 以下为注释掉的旧代码，用于参考

//记length个有效时钟
/*always @(posedge clk or negedge rst_n ) begin
    if(!rst_n)
        cnt_length;
    else if (cnt_vaild==1)
        cnt_length<=cnt_length+1;
    else if (0<cnt_length<udp_length-1)
        cnt_length<=cnt_length+1;
    else if (cnt_length==udp_length-1)
        cnt_length<=0;
    else
        cnt_length<=cnt_length;    
end*/

//列计数器
/*always @(posedge clk or negedge rst_n ) begin
    if(!rst_n)
    cnt_h<=0;
    else if (cnt_vaild==1)begin
            if (cnt_h<10'd639)
            cnt_h<=cnt_h+1;
            else if (cnt_h==10'd639)
            cnt_h<=0;
    end
end

//行计数器
always @(posedge clk or negedge rst_n ) begin
    if(!rst_n)
    cnt_v<=0;
    else if (cnt_h<10'd639)
            cnt_v<=cnt_v;
    else if (cnt_h==10'd639)
            cnt_v<=cnt_v+1;
    else if (cnt_h==10'd639 & cnt_v==10'd479 )begin
            cnt_v<=0;
    end
end

//ram地址生成
always @(posedge clk or negedge rst_n ) begin
    if(!rst_n)begin
    wr_addr<=0;
    done<=0;
    end
    else if (cnt_vaild==1)begin
            if (cnt_h<10'd255 & cnt_v<10'd127)
            wr_addr<=wr_addr+1;
            else if (cnt_h==10'd255 & cnt_v==10'd127)begin
            wr_addr<=0;
            done<=1;
            end
    else wr_addr<=wr_addr;
    end
end*/