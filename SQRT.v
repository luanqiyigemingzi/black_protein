module SQRT (
    input   [20:0]  radical,    //输入：待开方数
    output  [10:0]  q,          //11位整数平方根结果
    output  [11:0]  remainder   //12位余数
);

reg [10:0] q_reg;
reg [11:0] rem_reg;

reg [10:0] low, high, mid;

reg [21:0] mid_sq;              // 保持22位用于存储平方值
reg [21:0] temp_mid_sq; 
reg [21:0] temp_rem;

//组合逻辑实现二分查找
always @(*) begin
    low = 11'd0;
    high = 11'd2047;
    q_reg = 11'd0;

    // 使用临时变量确保正确的位宽计算

    
    //二分查找迭代（11次）
    repeat(11) begin
        mid = (low + high) >> 1;    //中间值=（low+high）/2
        
        // 确保乘法使用足够位宽
        temp_mid_sq = {11'd0, mid} * {11'd0, mid};
        mid_sq = temp_mid_sq;
        
        if(mid_sq <= {1'b0, radical}) begin  // radical扩展为22位比较
            q_reg = mid;
            low = mid + 1'b1;
        end else begin
            high = mid - 1'b1;
        end
    end

    //计算余数 - 同样需要防止溢出

    temp_rem = {1'b0, radical} - ({11'd0, q_reg} * {11'd0, q_reg});
    rem_reg = temp_rem[11:0];
end

assign q = q_reg;
assign remainder = rem_reg;

endmodule