`timescale 1ns / 1ps

/* 
    Simple testbench that will drive the datapath to demosntrate the instruction going through the current pipeline iteration
*/
module testbench;

    logic clk;
    logic reset;

    
    
    core_topfile dut(.clk(clk), .reset(reset));
    
     // generate clock to sequence tests
  always
    begin
      clk <= 1; # 5; clk <= 0; # 5;
    end
    
    initial begin
        reset <= 1;
        #10;
        reset <= 0;
        
        #2000;
        $finish;
    end
    

endmodule
