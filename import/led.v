module led(
 input                                 app_rx_data_valid       ,
 input                 [   7:   0]     app_rx_data             ,
 input  wire           [  15:   0]     app_rx_data_length      ,
 input                                 udp_rx_clk              ,
 input  wire                           reset                   ,
 input clk_50,
 output          [3:0] led_data_1 ,
 output          [15:0] dled                                    
 );
 wire [7:0]seg_sel;
 wire [7:0]seg_data;
reg  [63:0]led_data;
    reg                [  15:   0]     cnt                         ;
    reg                [   1:   0]     state                       ;
    always @(posedge udp_rx_clk or negedge reset)
        begin
            if(!reset)  begin
            cnt   <=16'b0;
            end
            else if (app_rx_data_valid & cnt<(app_rx_data_length-1))begin
                        cnt<=cnt+1;
                    end
                    
            else if (app_rx_data_valid & cnt==(app_rx_data_length-1))
                        cnt<=16'b0;
                        
            else
                        cnt<=cnt;
                    end

    always @(posedge udp_rx_clk or negedge reset)
        begin
            if(!reset)
              led_data<=64'b0;
            else if (app_rx_data_valid)
            case (cnt)
                0:led_data[63:56]<=app_rx_data;
                1:led_data[55:48]<=app_rx_data;
                2:led_data[47:40]<=app_rx_data;
                3:led_data[39:32]<=app_rx_data;
                4:led_data[31:24]<=app_rx_data;
                5:led_data[23:16]<=app_rx_data;
                6:led_data[15:8] <=app_rx_data;
                7:led_data[7:0]  <=app_rx_data;
            endcase
                                                     
            else
            led_data <=led_data;
        end

assign led_data_1 = led_data[63:60];

mux_total shuma( 
.clk(udp_rx_clk),
.reset(reset),
.data(led_data[47:8]),
.seg_sel(seg_sel),                // 数码管位选输出
.seg_data(seg_data)     // 数码管段选输出
);

//assign  dled    = led_data[55:40];
//assign  dled   ={8'h00,8'b1000_1000};
//always@(posedge clk_50)
assign dled={seg_sel,seg_data};



endmodule
