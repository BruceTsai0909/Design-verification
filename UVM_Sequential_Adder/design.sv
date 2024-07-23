module add(
    input clk, rst,
    input [3:0] a, b,
    output reg [4:0] y
);

always@(posedge clk)begin
    if(rst)
        y <= 5'b00000;
    else
        y <= a + b;
end


endmodule