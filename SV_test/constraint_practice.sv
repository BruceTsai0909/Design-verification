class transaction;
  rand bit oper;
  rand byte data;	
  rand int rand_int;
  rand byte datac;
  
  constraint oper_control {
    oper dist{0:/50, 1:/50};
    }  
  
  constraint rand_int_control {
    rand_int > 0; rand_int<100;
    }  

  constraint data_control {
    data inside {[0:3], [8:10]};
    } 

  constraint datac_control {
    datac dist {0:=10,[1:3]:=45};
    } 
                       
                          
endclass

module tb();
  
  transaction tr;
  
  initial begin
    tr = new();
    for(int i = 0; i < 10; i++)begin
      tr.randomize();

      $display("tr.oper: %0d", tr.oper);
      $display("tr.rand_int: %0d", tr.rand_int);
      $display("tr.data: %0d", tr.data);
      $display("tr.datac: %0d", tr.datac);
    end
    
    
  end
  
  
endmodule