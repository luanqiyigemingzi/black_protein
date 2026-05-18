

module sd_read(
    input                clk_ref       ,  //ʱ���ź�
    input                clk_ref_180deg,  //ʱ���ź�,��clk_ref��λ����180��
    input                rst_n         ,  //��λ�ź�,�͵�ƽ��Ч
    //SD���ӿ�
    input                sd_miso       ,  //SD��SPI�������������ź�
    output  reg          sd_cs         ,  //SD��SPIƬѡ�ź�
    output  reg          sd_mosi       ,  //SD��SPI�������������ź�
       //�û����ӿ�    
    input                rd_start_en   ,  //��ʼ��SD�������ź�
    input        [31:0]  rd_sec_addr   ,  //������������ַ                        
    output  reg          rd_busy       ,  //������æ�ź�
    output  reg          rd_val_en     ,  //��������Ч�ź�
    output  reg  [15:0]  rd_val_data      //������
    );

//reg define
reg            rd_en_d0      ;            //rd_start_en�ź���ʱ����
reg            rd_en_d1      ;                                
reg            res_en        ;            //����SD������������Ч�ź�      
reg    [7:0]   res_data      ;            //����SD����������                  
reg            res_flag      ;            //��ʼ���շ������ݵı�־            
reg    [5:0]   res_bit_cnt   ;            //����λ���ݼ�����                  
                             
reg            rx_en_t       ;            //����SD������ʹ���ź�
reg    [15:0]  rx_data_t     ;            //����SD������
reg            rx_flag       ;            //��ʼ���յı�־
reg    [3:0]   rx_bit_cnt    ;            //��������λ������
reg    [8:0]   rx_data_cnt   ;            //���յ����ݸ���������
reg            rx_finish_en  ;            //��������ʹ���ź�
                             
reg    [3:0]   rd_ctrl_cnt   ;            //�����Ƽ�����
reg    [47:0]  cmd_rd        ;            //������
reg    [5:0]   cmd_bit_cnt   ;            //������λ������
reg            rd_data_flag  ;            //׼����ȡ���ݵı�־

//wire define
wire           pos_rd_en     ;            //��ʼ��SD�������źŵ�������

//*****************************************************
//**                    main code
//*****************************************************

assign  pos_rd_en = (~rd_en_d1) & rd_en_d0;

//rd_start_en�ź���ʱ����
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        rd_en_d0 <= 1'b0;
        rd_en_d1 <= 1'b0;
    end    
    else begin
        rd_en_d0 <= rd_start_en;
        rd_en_d1 <= rd_en_d0;
    end        
end  

//����sd�����ص���Ӧ����
//��clk_ref_180deg(sd_clk)����������������
always @(posedge clk_ref_180deg or negedge rst_n) begin
    if(!rst_n) begin
        res_en <= 1'b0;
        res_data <= 8'd0;
        res_flag <= 1'b0;
        res_bit_cnt <= 6'd0;
    end    
    else begin
        //sd_miso = 0 ��ʼ������Ӧ����
        if(sd_miso == 1'b0 && res_flag == 1'b0) begin
            res_flag <= 1'b1;
            res_data <= {res_data[6:0],sd_miso};
            res_bit_cnt <= res_bit_cnt + 6'd1;
            res_en <= 1'b0;
        end    
        else if(res_flag) begin
            res_data <= {res_data[6:0],sd_miso};
            res_bit_cnt <= res_bit_cnt + 6'd1;
            if(res_bit_cnt == 6'd7) begin
                res_flag <= 1'b0;
                res_bit_cnt <= 6'd0;
                res_en <= 1'b1; 
            end                
        end  
        else
            res_en <= 1'b0;        
    end
end 

//����SD����Ч����
//��clk_ref_180deg(sd_clk)����������������
always @(posedge clk_ref_180deg or negedge rst_n) begin
    if(!rst_n) begin
        rx_en_t <= 1'b0;
        rx_data_t <= 16'd0;
        rx_flag <= 1'b0;
        rx_bit_cnt <= 4'd0;
        rx_data_cnt <= 9'd0;
        rx_finish_en <= 1'b0;
    end    
    else begin
        rx_en_t <= 1'b0; 
        rx_finish_en <= 1'b0;
        //����ͷ0xfe 8'b1111_1110�����Լ���0Ϊ��ʼλ
        if(rd_data_flag && sd_miso == 1'b0 && rx_flag == 1'b0)    
            rx_flag <= 1'b1;   
        else if(rx_flag) begin
            rx_bit_cnt <= rx_bit_cnt + 4'd1;
            rx_data_t <= {rx_data_t[14:0],sd_miso};
            if(rx_bit_cnt == 4'd15) begin 
                rx_data_cnt <= rx_data_cnt + 9'd1;
                //���յ���BLOCK��512���ֽ� = 256 * 16bit 
                if(rx_data_cnt <= 9'd255)                        
                    rx_en_t <= 1'b1;  
                else if(rx_data_cnt == 9'd257) begin   //���������ֽڵ�CRCУ��ֵ
                    rx_flag <= 1'b0;
                    rx_finish_en <= 1'b1;              //���ݽ�������
                    rx_data_cnt <= 9'd0;               
                    rx_bit_cnt <= 4'd0;
                end    
            end                
        end       
        else
            rx_data_t <= 16'd0;
    end    
end    

//�Ĵ�����������Ч�źź�����
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        rd_val_en <= 1'b0;
        rd_val_data <= 16'd0;
    end
    else begin
        if(rx_en_t) begin
            rd_val_en <= 1'b1;
            rd_val_data <= rx_data_t;
        end    
        else
            rd_val_en <= 1'b0;
    end
end              

//������
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        sd_cs <= 1'b1;
        sd_mosi <= 1'b1;        
        rd_ctrl_cnt <= 4'd0;
        cmd_rd <= 48'd0;
        cmd_bit_cnt <= 6'd0;
        rd_busy <= 1'b0;
        rd_data_flag <= 1'b0;
    end   
    else begin
        case(rd_ctrl_cnt)
            4'd0 : begin
                rd_busy <= 1'b0;
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;
                if(pos_rd_en) begin
                    cmd_rd <= {8'h51,rd_sec_addr,8'hff};    //д�뵥��������CMD17
                    rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1;      //���Ƽ�������1
                    //��ʼִ�ж�ȡ����,���߶�æ�ź�
                    rd_busy <= 1'b1;                      
                end    
            end
            4'd1 : begin
                if(cmd_bit_cnt <= 6'd47) begin              //��ʼ��λ���Ͷ�����
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= cmd_rd[6'd47 - cmd_bit_cnt]; //�ȷ��͸��ֽ�
                end    
                else begin                                  
                    sd_mosi <= 1'b1;
                    if(res_en) begin                        //SD����Ӧ
                        rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1;  //���Ƽ�������1 
                        cmd_bit_cnt <= 6'd0;
                    end    
                end    
            end    
            4'd2 : begin
                //����rd_data_flag�ź�,׼����������
                rd_data_flag <= 1'b1;                       
                if(rx_finish_en) begin                      //���ݽ�������
                    rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1; 
                    rd_data_flag <= 1'b0;
                    sd_cs <= 1'b1;
                end
            end        
            default : begin
                //��������״̬��,����Ƭѡ�ź�,�ȴ�8��ʱ������
                sd_cs <= 1'b1;   
                rd_ctrl_cnt <= rd_ctrl_cnt + 4'd1;
            end    
        endcase
    end         
end

endmodule