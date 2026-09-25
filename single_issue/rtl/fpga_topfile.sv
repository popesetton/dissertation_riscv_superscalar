module fpga_topfile(input logic             clk, reset,
                    output logic [3:0]      an,
                    output logic [6:0]      seg
                    );

    logic [31:0] StoreDataFPGA;
    logic mem_writeFPGA;
    logic clk_div;
    
    logic [31:0] DisplayValue;
    
    logic [19:0] refresh_count;
    logic [3:0] BCD;
    
    clkdivider clkdivider(.clk(clk), .reset(reset), .clk_div(clk_div));
       
    core_topfile core(.clk(clk_div), .reset(reset), .StoreDataFPGA(StoreDataFPGA), .mem_writeFPGA(mem_writeFPGA));
      
    // Latch the last written value to memory
    always_ff @(posedge clk_div or posedge reset) begin
        if (reset)
            DisplayValue <= '0;
        else if (mem_writeFPGA)
            DisplayValue <= StoreDataFPGA;
    end
    
    
    // 7-segment display refresh counter   
    always_ff @(posedge clk, posedge reset)
        if (reset)
            refresh_count <= 0;
        else
            refresh_count <= refresh_count + 1;
    
    always_comb
	   case (refresh_count[19:18]) // activation of 4 displays, digit period of 2.5ms
	       2'b00: begin an = 4'b0111; BCD = DisplayValue / 1000; end
	       2'b01: begin an = 4'b1011; BCD = (DisplayValue % 1000)/100; end
	       2'b10: begin an = 4'b1101; BCD = ((DisplayValue % 1000)%100)/10; end
	       2'b11: begin an = 4'b1110; BCD = ((DisplayValue % 1000)%100)%10; end
	   endcase

    
    always_comb
		case (BCD)			//GFEDCBA
			4'b0000: seg = 7'b1000000; //0
			4'b0001: seg = 7'b1111001; //1
			4'b0010: seg = 7'b0100100; //2
			4'b0011: seg = 7'b0110000; //3
			4'b0100: seg = 7'b0011001; //4
			4'b0101: seg = 7'b0010010; //5
			4'b0110: seg = 7'b0000010; //6
			4'b0111: seg = 7'b1111000; //7
			4'b1000: seg = 7'b0000000; //8
			4'b1001: seg = 7'b0010000; //9
			default: seg = 7'b0000110; //E
	   endcase   
endmodule

module clkdivider (input logic clk, reset, output logic clk_div);
     
    parameter half_period_count = 6250000; //0.125 sec 
    logic [31:0] count;
 
    always_ff @ (posedge clk, posedge reset) begin
        if (reset)
            count <= 32'b0;
        else if (count == half_period_count - 1)
            count <= 32'b0;
        else
            count <= count + 1;
    end

    always_ff @ (posedge clk , posedge reset) begin
        if (reset)
            clk_div <= 1'b0;
        else if (count == half_period_count - 1)
            clk_div <= ~clk_div;
        else
            clk_div <= clk_div;
    end
 
endmodule
