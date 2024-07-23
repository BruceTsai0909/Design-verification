
// transaction class will have data member contains each input and output port.

class transaction;
rand bit oper;
bit wr, rd;
bit [7:0] data_in;
bit [7:0] data_out;
bit full, empty;

constraint oper_ctrl {
    oper dist {1 :/ 50, 0 :/ 50};
}

endclass

////////////////////////////////////////////////////////////////////////////////

class generator;

transaction tr;
mailbox #(transaction) mbx;

int count = 0;
int i = 0;

event next; //when to send next transaction
event done; //completion of requested no. of transaction

//constructor
function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
    tr = new();
endfunction

task run();
    repeat(count) begin
        assert (tr.randomize()) else $error("randomization fail");
        i++;
        mbx.put(tr);
        $display("[GEN] : Oper : %0d iteration : %0d", tr.oper, i);
        @(next); // wait for next event
    end

    -> done; //

endtask

endclass

////////////////////////////////////////////////////////////////////////////////

//driver triggered DUT with the stimulate received frim generator

class driver;

virtual fifo_if fif;
mailbox #(transaction) mbx;
transaction datac;

function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
endfunction

task reset();
    fif.rst <= 1'b1;
    fif.rd <= 1'b0;
    fif.wr <= 1'b0;
    fif.data_in <= 0;
    repeat(5) @(posedge fif.clock);
    fif.rst <= 1'b0;
  $display("[DRV] : DUT Reset done");
  $display("-------------------------------------------------");
endtask

task write();
    @(posedge fif.clock);
    fif.rst <= 1'b0;
    fif.wr <= 1'b1;
    fif.rd <= 1'b0;
    fif.data_in <= $urandom_range(1,10);
    @(posedge fif.clock);
    fif.wr <= 1'b0;
    $display("[DRV] DATA WRITE, data: %0d", fif.data_in);
    @(posedge fif.clock);
endtask

task read();
    @(posedge fif.clock);
    fif.rst <= 1'b0;
    fif.rd <= 1'b1;
    fif.wr <= 1'b0;
    @(posedge fif.clock);
    fif.rd <= 1'b0;
    $display("[DRV] DATA READ");
    @(posedge fif.clock);
endtask

task run();
    forever begin
        mbx.get(datac);
        if (datac.oper == 1'b1)
            write();
        else
            read();
    end
endtask

endclass

////////////////////////////////////////////////////////////////////////////////

class monitor;

virtual fifo_if fif;
mailbox #(transaction) mbx;
transaction tr;

function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
endfunction

task run();
    tr = new();
    forever begin
        repeat(2) @(posedge fif.clock);  // 等待兩個時鐘邊沿
        tr.rd = fif.rd;
        tr.wr = fif.wr;
        tr.data_in = fif.data_in;
        tr.full = fif.full;
        tr.empty = fif.empty;
        @(posedge fif.clock)  // 等待一個時鐘邊沿
        tr.data_out = fif.data_out;

        mbx.put(tr);  // 將捕捉到的事務放入信箱
        $display("[MON] rd : %0d, wr : %0d, data_in : %0d, full : %0d, empty : %0d, data_out : %0d", tr.rd, tr.wr, tr.data_in, tr.full, tr.empty, tr.data_out);
    end
endtask

endclass

////////////////////////////////////////////////////////////////////////////////

class scoreboard;

bit [7:0] din [$];
bit [7:0] temp;
int err;
transaction tr;
mailbox #(transaction) mbx;
event next;

function new(mailbox #(transaction) mbx);
    this.mbx = mbx;
endfunction

task run();
    forever 
    begin
        mbx.get(tr);
        $display("[SCO] rd : %0d, wr : %0d, data_in : %0d, full : %0d, empty : %0d, data_out : %0d", tr.rd, tr.wr, tr.data_in, tr.full, tr.empty, tr.data_out);

        if (tr.wr == 1'b1) 
        begin
            if (tr.full == 1'b0)
            begin
            din.push_front(tr.data_in);
            $display("[SCO] : DATA STORED IN QUEUE : %0d", tr.data_in);
            end
            else
            begin
            $display("[SCO] FIFO IS FULL");
            end
            $display("-------------------------------------------------");
        end

        if (tr.rd == 1'b1) 
        begin
            if (tr.empty == 1'b0)
            begin
                temp = din.pop_back();
                if (temp == tr.data_out)
                begin
                    $display("[SCO] DATA MATCH");
                end
                else
                begin
                    $display("[SCO] DATA MISMATCH");
                    err++;
                end
            end
            else
            begin
                $display("[SCO] FIFO IS EMPTY");
            end
            $display("-------------------------------------------------");
        end

        -> next;
    end
endtask

endclass

////////////////////////////////////////////////////////////////////////////////

class environment;
generator gen;
driver drv;
monitor mon;
scoreboard sco;

mailbox #(transaction) gdmbx; // generator to driver
mailbox #(transaction) msmbx; // monitor to scoreboard

event nextgs;

virtual fifo_if fif;

  // 構造函數
  function new(virtual fifo_if fif);
    // 初始化 mailbox 和物件
    gdmbx = new();
    gen = new(gdmbx);
    drv = new(gdmbx);

    msmbx = new();
    mon = new(msmbx);
    sco = new(msmbx);

    // 設定 fif 接口
    this.fif = fif;

    // 將 fif 接口分配給 driver 和 monitor
    drv.fif = this.fif;
    mon.fif = this.fif;

    // 設定事件同步
    gen.next = nextgs;
    sco.next = nextgs;
  endfunction

task pre_test();
    drv.reset();
endtask

task test();
fork
    gen.run();
    drv.run();
    mon.run();
    sco.run();
join_any
endtask

task post_test();
wait(gen.done.triggered);
$display("-------------------------------------------------");
$display("Error count : %0d", sco.err);
$display("-------------------------------------------------");

$finish();

endtask

task run();
pre_test();
test();
post_test();
endtask

endclass

////////////////////////////////////////////////////////////////////////////////

module tb;

fifo_if fif();

FIFO dut (fif.clock, fif.rst, fif.wr, fif.rd, fif.data_in, fif.data_out, fif.empty, fif.full);

initial begin
    fif.clock <= 0;
end

always #10 fif.clock = ~fif.clock;

environment env;

initial begin
    env = new(fif);
    env.gen.count = 10;
    env.run();
end

initial begin
    $dumpfile("dump.vcd");
    $dumpvars;
end

endmodule

////////////////////////////////////////////////////////////////////////////////