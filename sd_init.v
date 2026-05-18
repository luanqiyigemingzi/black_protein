
module sd_init(
    input          clk_ref       ,  //ʱ���ź�
    input          rst_n         ,  //��λ�ź�,�͵�ƽ��Ч
    
    input          sd_miso       ,  //SD��SPI�������������ź�
    output         sd_clk        ,  //SD��SPIʱ���ź�
    output  reg    sd_cs         ,  //SD��SPIƬѡ�ź�
    output  reg    sd_mosi       ,  //SD��SPI�������������ź�
    output  reg    sd_init_done     //SD����ʼ�������ź�
    );

//parameter define
//SD��������λ����,���������ż�����Ϊ�̶�ֵ,CRCҲΪ�̶�ֵ,CRC = 8'h95
parameter  CMD0  = {8'h40,8'h00,8'h00,8'h00,8'h00,8'h95};
//�ӿ�״̬����,�������豸�ĵ�ѹ��Χ,��������SD���汾,ֻ��2.0���Ժ��Ŀ���֧��CMD8����
//MMC����V1.x�Ŀ�,��֧�ִ�����,���������ż�����Ϊ�̶�ֵ,CRCҲΪ�̶�ֵ,CRC = 8'h87
parameter  CMD8  = {8'h48,8'h00,8'h00,8'h01,8'haa,8'h87};
//����SD����������������Ӧ������������Ǳ�׼����, ����ҪCRC
parameter  CMD55 = {8'h77,8'h00,8'h00,8'h00,8'h00,8'hff};  
//���Ͳ����Ĵ���(OCR)����, ����ҪCRC
parameter  ACMD41= {8'h69,8'h40,8'h00,8'h00,8'h00,8'hff};
//ʱ�ӷ�Ƶϵ��,��ʼ��SD��ʱ����SD����ʱ��Ƶ��,50M/250K = 200 
parameter  DIV_FREQ = 200;
//�ϵ����ٵȴ�74��ͬ��ʱ������,�ڵȴ��ϵ��ȶ��ڼ�,sd_cs = 1,sd_mosi = 1
parameter  POWER_ON_NUM = 5000;
//����������λ����ʱ�ȴ�SD�����ص�����ʱ��,T = 100ms; 100_000us/4us = 25000
//����ʱ���������ڴ�ֵʱ,��ΪSD����Ӧ��ʱ,���·���������λ����
parameter  OVER_TIME_NUM = 25000;
                        
parameter  st_idle        = 7'b000_0001;  //Ĭ��״̬,�ϵ��ȴ�SD���ȶ�
parameter  st_send_cmd0   = 7'b000_0010;  //����������λ����
parameter  st_wait_cmd0   = 7'b000_0100;  //�ȴ�SD����Ӧ
parameter  st_send_cmd8   = 7'b000_1000;  //�������豸�ĵ�ѹ��Χ������SD���Ƿ�����
parameter  st_send_cmd55  = 7'b001_0000;  //����SD����������������Ӧ����������
parameter  st_send_acmd41 = 7'b010_0000;  //���Ͳ����Ĵ���(OCR)����
parameter  st_init_done   = 7'b100_0000;  //SD����ʼ������

//reg define
reg    [7:0]   cur_state      ;
reg    [7:0]   next_state     ; 
                              
reg    [7:0]   div_cnt        ;    //��Ƶ������
reg            div_clk        ;    //��Ƶ����ʱ��         
reg    [12:0]  poweron_cnt    ;    //�ϵ��ȴ��ȶ�������
reg            res_en         ;    //����SD������������Ч�ź�
reg    [47:0]  res_data       ;    //����SD����������
reg            res_flag       ;    //��ʼ���շ������ݵı�־
reg    [5:0]   res_bit_cnt    ;    //����λ���ݼ�����
                                   
reg    [5:0]   cmd_bit_cnt    ;    //����ָ��λ������
reg   [15:0]   over_time_cnt  ;    //��ʱ������  
reg            over_time_en   ;    //��ʱʹ���ź� 
                                   
wire           div_clk_180deg ;    //ʱ����λ��div_clk����180��

//*****************************************************
//**                    main code
//*****************************************************

assign  sd_clk = ~div_clk;         //SD_CLK
assign  div_clk_180deg = ~div_clk; //��λ��DIV_CLK����180�ȵ�ʱ��

//ʱ�ӷ�Ƶ,div_clk = 250KHz
always @(posedge clk_ref or negedge rst_n) begin
    if(!rst_n) begin
        div_clk <= 1'b0;
        div_cnt <= 8'd0;
    end
    else begin
        if(div_cnt == DIV_FREQ/2-1'b1) begin
            div_clk <= ~div_clk;
            div_cnt <= 8'd0;
        end
        else    
            div_cnt <= div_cnt + 1'b1;
    end        
end

//�ϵ��ȴ��ȶ�������
always @(posedge div_clk or negedge rst_n) begin
    if(!rst_n) 
        poweron_cnt <= 13'd0;
    else if(cur_state == st_idle) begin
        if(poweron_cnt < POWER_ON_NUM)
            poweron_cnt <= poweron_cnt + 1'b1;                   
    end
    else
        poweron_cnt <= 13'd0;    
end    

//����sd�����ص���Ӧ����
//��div_clk_180deg(sd_clk)����������������
always @(posedge div_clk_180deg or negedge rst_n) begin
    if(!rst_n) begin
        res_en <= 1'b0;
        res_data <= 48'd0;
        res_flag <= 1'b0;
        res_bit_cnt <= 6'd0;
    end    
    else begin
        //sd_miso = 0 ��ʼ������Ӧ����
        if(sd_miso == 1'b0 && res_flag == 1'b0) begin 
            res_flag <= 1'b1;
            res_data <= {res_data[46:0],sd_miso};
            res_bit_cnt <= res_bit_cnt + 6'd1;
            res_en <= 1'b0;
        end    
        else if(res_flag) begin
            //R1����1���ֽ�,R3 R7����5���ֽ�
            //������ͳһ����6���ֽ�������,������1���ֽ�ΪNOP(8��ʱ�����ڵ���ʱ)
            res_data <= {res_data[46:0],sd_miso};     
            res_bit_cnt <= res_bit_cnt + 6'd1;
            if(res_bit_cnt == 6'd47) begin
                res_flag <= 1'b0;
                res_bit_cnt <= 6'd0;
                res_en <= 1'b1; 
            end                
        end  
        else
            res_en <= 1'b0;         
    end
end                    

always @(posedge div_clk or negedge rst_n) begin
    if(!rst_n)
        cur_state <= st_idle;
    else
        cur_state <= next_state;
end

always @(*) begin
    next_state = st_idle;
    case(cur_state)
        st_idle : begin
            //�ϵ����ٵȴ�74��ͬ��ʱ������
            if(poweron_cnt == POWER_ON_NUM)          //Ĭ��״̬,�ϵ��ȴ�SD���ȶ�
                next_state = st_send_cmd0;
            else
                next_state = st_idle;
        end 
        st_send_cmd0 : begin                         //����������λ����
            if(cmd_bit_cnt == 6'd47)
                next_state = st_wait_cmd0;
            else
                next_state = st_send_cmd0;    
        end               
        st_wait_cmd0 : begin                         //�ȴ�SD����Ӧ
            if(res_en) begin                         //SD��������Ӧ�ź�
                if(res_data[47:40] == 8'h01)         //SD�����ظ�λ�ɹ�
                    next_state = st_send_cmd8;
                else
                    next_state = st_idle;
            end
            else if(over_time_en)                    //SD����Ӧ��ʱ
                next_state = st_idle;
            else
                next_state = st_wait_cmd0;                                    
        end    
        //�������豸�ĵ�ѹ��Χ,����SD���Ƿ�����
        st_send_cmd8 : begin 
            if(res_en) begin                         //SD��������Ӧ�ź�  
                //����SD���Ĳ�����ѹ,[19:16] = 4'b0001(2.7V~3.6V)
                if(res_data[19:16] == 4'b0001)       
                    next_state = st_send_cmd55;
                else
                    next_state = st_idle;
            end
            else
                next_state = st_send_cmd8;            
        end
        //����SD����������������Ӧ����������
        st_send_cmd55 : begin     
            if(res_en) begin                         //SD��������Ӧ�ź�  
                if(res_data[47:40] == 8'h01)         //SD�����ؿ���״̬
                    next_state = st_send_acmd41;
                else
                    next_state = st_send_cmd55;    
            end        
            else
                next_state = st_send_cmd55;     
        end  
        st_send_acmd41 : begin                       //���Ͳ����Ĵ���(OCR)����
            if(res_en) begin                         //SD��������Ӧ�ź�  
                if(res_data[47:40] == 8'h00)         //��ʼ�������ź�
                    next_state = st_init_done;
                else
                    next_state = st_send_cmd55;      //��ʼ��δ����,���·��� 
            end
            else
                next_state = st_send_acmd41;     
        end                
        st_init_done : next_state = st_init_done;    //��ʼ������ 
        default : next_state = st_idle;
    endcase
end

//SD����div_clk_180deg(sd_clk)����������������,������sd_clk���½�����������
//Ϊ��ͳһ��alway����ʹ�������ش���,�˴�ʹ�ú�sd_clk��λ����180�ȵ�ʱ��
always @(posedge div_clk or negedge rst_n) begin
    if(!rst_n) begin
        sd_cs <= 1'b1;
        sd_mosi <= 1'b1;
        sd_init_done <= 1'b0;
        cmd_bit_cnt <= 6'd0;
        over_time_cnt <= 16'd0;
        over_time_en <= 1'b0;
    end
    else begin
        over_time_en <= 1'b0;
        case(cur_state)
            st_idle : begin                               //Ĭ��״̬,�ϵ��ȴ�SD���ȶ�
                sd_cs <= 1'b1;                            //�ڵȴ��ϵ��ȶ��ڼ�,sd_cs=1
                sd_mosi <= 1'b1;                          //sd_mosi=1
            end     
            st_send_cmd0 : begin                          //����CMD0������λ����
                cmd_bit_cnt <= cmd_bit_cnt + 6'd1;        
                sd_cs <= 1'b0;                            
                sd_mosi <= CMD0[6'd47 - cmd_bit_cnt];     //�ȷ���CMD0������λ
                if(cmd_bit_cnt == 6'd47)                  
                    cmd_bit_cnt <= 6'd0;                  
            end      
            //�ڽ���CMD0��Ӧ�����ڼ�,ƬѡCS����,����SPIģʽ                                     
            st_wait_cmd0 : begin                          
                sd_mosi <= 1'b1;             
                if(res_en)                                //SD��������Ӧ�ź�
                    //��������֮��������,����SPIģʽ                     
                    sd_cs <= 1'b1;                                      
                over_time_cnt <= over_time_cnt + 1'b1;    //��ʱ��������ʼ����
                //SD����Ӧ��ʱ,���·���������λ����
                if(over_time_cnt == OVER_TIME_NUM - 1'b1)
                    over_time_en <= 1'b1; 
                if(over_time_en)
                    over_time_cnt <= 16'd0;                                        
            end                                           
            st_send_cmd8 : begin                          //����CMD8
                if(cmd_bit_cnt<=6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= CMD8[6'd47 - cmd_bit_cnt]; //�ȷ���CMD8������λ       
                end
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin                      //SD��������Ӧ�ź�
                        sd_cs <= 1'b1;
                        cmd_bit_cnt <= 6'd0; 
                    end   
                end                                                                   
            end 
            st_send_cmd55 : begin                         //����CMD55
                if(cmd_bit_cnt<=6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= CMD55[6'd47 - cmd_bit_cnt];       
                end
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin                      //SD��������Ӧ�ź�
                        sd_cs <= 1'b1;
                        cmd_bit_cnt <= 6'd0;     
                    end        
                end                                                                                    
            end
            st_send_acmd41 : begin                        //����ACMD41
                if(cmd_bit_cnt <= 6'd47) begin
                    cmd_bit_cnt <= cmd_bit_cnt + 6'd1;
                    sd_cs <= 1'b0;
                    sd_mosi <= ACMD41[6'd47 - cmd_bit_cnt];      
                end
                else begin
                    sd_mosi <= 1'b1;
                    if(res_en) begin                      //SD��������Ӧ�ź�
                        sd_cs <= 1'b1;
                        cmd_bit_cnt <= 6'd0;  
                    end        
                end     
            end
            st_init_done : begin                          //��ʼ������
                sd_init_done <= 1'b1;
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;
            end
            default : begin
                sd_cs <= 1'b1;
                sd_mosi <= 1'b1;                
            end    
        endcase
    end
end

endmodule