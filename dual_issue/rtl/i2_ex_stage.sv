import types_pkg::*;
/*
    Pipeline stage name: Execute
    Description: Executes decoded instructions, handles taken branch and target PC logic
*/
module i2_ex_stage(input logic [3:0] I2_ALUControlEX,
                input srcA_e I2_srcA,
                input srcB_e I2_srcB,
                input logic [31:0] I2_PCEX, I2_Rs1DataEX, I2_Rs2DataEX, I2_ImmExtEX, I2_WBfwdI1Data, I2_WBfwdI2Data,
                input logic [1:0] I2_fwdsrcAsel, I2_fwdsrcBsel,
                output logic [31:0] I2_ALUResultEX
                );
   
    logic [31:0] srcAfwd, srcBfwd;
    
    // SrcA forwarding mux
    mux3 #(32) srcAfwdmux(.d0(I2_Rs1DataEX), .d1(I2_WBfwdI1Data), .d2(I2_WBfwdI2Data), .s(I2_fwdsrcAsel), .y(srcAfwd));
    
    // SrcB forwarding mux
    mux3 #(32) srcBfwdmux(.d0(I2_Rs2DataEX), .d1(I2_WBfwdI1Data), .d2(I2_WBfwdI2Data), .s(I2_fwdsrcBsel), .y(srcBfwd));
    
    // SrcA selection mux
    logic [31:0] srcAout, srcBout;
    mux2 #(32) srcAmux(.d0(srcAfwd), .d1(I2_PCEX), .s(I2_srcA), .y(srcAout));
    
    // SrcB selection mux
    mux2 #(32) srcBmux(.d0(srcBfwd), .d1(I2_ImmExtEX), .s(I2_srcB), .y(srcBout));
    
    // Instantiate ALU
    i2_alu i2_alu(.a(srcAout), .b(srcBout), .ALUControl(I2_ALUControlEX), .result(I2_ALUResultEX));
    
endmodule


module i2_alu(input logic [31:0] a,b,
           input logic [3:0] ALUControl,
           output logic [31:0] result
           );

    // Logic to invert second operand for SUB instructions
    logic [31:0] condinvb, sum; // Conditionally inverted b
    
    assign condinvb = ALUControl[0] ? ~b : b;
    assign sum = a + condinvb + ALUControl[0]; // If it is ADD, then ALUControl final bit is 0 and b not inverted. In SUB, b is inverted and ALUControl bit is 1 (2's complement)
    
    logic [4:0] shift_amount;
    assign shift_amount = b[4:0];
    // Handle all ALU instructions
    always_comb
        casex(ALUControl)
            4'b000x: result = sum;      // ADD or SUB      
            4'b0010: result = a & b;    // AND
            4'b0011: result = a | b;    // OR
            4'b0100: result = a << shift_amount;	// SLL
            4'b0101: result = ($signed(a) < $signed(b)); //SLT
            4'b0110: result = a ^ b;   // XOR
            4'b0111: result = a >> shift_amount;  // SRL
            4'b1000: result = ($unsigned(a) < $unsigned(b)); // SLTU
            4'b1111: result = $signed(a) >>> shift_amount; // SRA
            default: result = 32'bx;
        endcase        
endmodule