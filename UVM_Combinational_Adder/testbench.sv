`timescale 1ns/1ps

`include "uvm_macros.svh"
import uvm_pkg::*;

/////////////////////////////////////////////////
class transaction extends uvm_sequence_item;
rand bit [3:0] a;
rand bit [3:0] b;
bit [4:0] y;

function new(input string path = "transaction")
    super.new(path);
endfunction

`uvm_object_utils_begin(transaction) //讓 UVM 知道這是一個 UVM 物件
`uvm_field_int(a, UVM_DEFAULT)
`uvm_field_int(b, UVM_DEFAULT)
`uvm_field_int(y, UVM_DEFAULT)
`uvm_object_utils_end


endclass
/////////////////////////////////////////////////
class generator extends uvm_sequence #(transaction);
`uvm_object_utils(generator)

transaction t;
integer i;

function new(string path = "generator");
    super.new(path);
endfunction

virtual task body();
t = transaction::type_id::create::("t");
repeat(10) begin
    start_item(t);
    t.randomize();
    `uvm_info("GEN", $formatf("Data send to driver a : %0d, b : %0d", t.a, t.b), UVM_NONE);
    finish_item(t);
end
endtask

endclass
/////////////////////////////////////////////////
class driver extends uvm_driver #(transaction);
`uvm_component_utils(driver) //使用 UVM 提供的宏來自動化 driver 類別的註冊

function new(input string path = "driver", uvm_component parent = null);
    super.new(path, parent);
endfunction

transaction tc; //用來儲存從序列中獲取的交易數據
virtual add_if aif; // get access to a interface

virtual function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    tc = transaction::type_id::create("tc");

    if(!uvm_config_db #(virtual add_if)::get(this, "", "aif", aif)) //將配置項 "aif" 的值存儲到 aif 變數中。
        `uvm_error("DRV", "Unable to  access uvm_config_db");

endfunction 

virtual task run_phase(uvm_phase phase);
    forever begin
        seq_item_port.get_next_item(tc);
        aif.a <= tc.a;
        aif.b <= tc.b;
        `uvm_info("DRV", $sformatf("Trigger DUT a : %0d, b : %0d", tc.a, tc.b), UVM_NONE);
        seq_item_port.item_done();
    #10;
    end
endtask

endclass
/////////////////////////////////////////////////
class monitor extends uvm_monitor;
`uvm_component_utils(monitor)

uvm_analysis_port #(transaction) send;

function new(input string inst = "monitor", uvm_component parent = bull);
    super.new(path, parent);
    send = new("send", this);
endfunction

transaction t;
virtual add_if aif;

virtual function build_phase(uvm_phase phase);
super.build_phase(phase);
t = transaction::type_id::create("t");
if(!uvm_config_db #(virtual add_if)::get(this,,"aif", aif))
    `uvm_error("MON", "Unable to access uvm_config_db");
endfunction

virtual task run_phase(uvm_phase phase);
forever begin
#10;
t.a = aif.a;
t.b = aif.b;
t.y = aif.y;
`uvm_info("MON", $sformatf("Data send to scoreboard a : %0d, b : %0d, y : %0d", t.a, t.b, t.y), UVM_NONE);
send.write(t); //send data to scoreboard
end
endtask

endclass
/////////////////////////////////////////////////