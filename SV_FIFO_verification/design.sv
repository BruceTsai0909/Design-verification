module FIFO(
    input clk, rst, wr, rd,
    input [7:0] din,
    output reg [7:0] dout,
    output empty, full
);

reg [3:0] wprt = 0;
reg [3:0] rprt = 0;
reg [7:0] mem [15:0];
reg [4:0] cnt; // might count to 16.

always@(posedge clk)begin
    if (rst) begin
        wprt <= 0;
        rprt <= 0;
        cnt <= 0;
    end
    else if (wr && !full) begin
        mem[wprt] <= din;
        wprt <= wprt + 1;
        cnt <= cnt + 1;
    end
    else if (rd && !empty) begin
        dout <= mem[rprt];
        rprt <= rprt + 1;
        cnt <= cnt - 1;
    end
end

assign full = (cnt == 16)? 1'b1 : 1'b0;
assign empty = (cnt == 0)? 1'b1 : 1'b0;

endmodule

interface fifo_if;
logic clock, rd, wr;
logic full, empty;
logic [7:0] data_in;
logic [7:0] data_out;
logic rst;
endinterface