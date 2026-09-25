import types_pkg::*;
/*
    Pipeline stage name: Execute
    Description: Executes decoded instructions, handles taken branch and target PC logic
*/
module ex_stage(input logic [3:0] ALUControlEX,
                input brcond_e brcond,
                input srcA_e srcA,
                input srcB_e srcB,
                input logic [31:0] PCEX, Rs1DataEX, Rs2DataEX, ImmExtEX, WBfwdRdata1, WBfwdRdata2,
                input logic fwdsrcAsel, fwdsrcBsel, is_jump, is_jalr,
                output logic RedirectF,
                output logic [31:0] PCTargetEX, ALUResultEX,
                output logic [31:0] Rs2DataSt
                );
    
    logic [31:0] srcAfwd, srcBfwd;

    // Instantiate target PC adder
    logic [31:0] PCTarget;
    targetpc targetpc(.PC(PCTarget), .imm(ImmExtEX), .PCTarget(PCTargetEX));
    
    // Instantiate branch condition unit
    logic br_taken;
    brcomp brcomp(.brcond(brcond), .rs1(Rs1DataEX), .rs2(Rs2DataEX), .br_taken(br_taken));
    
    // Choose between ALU result (JALR only) and targetPC adder (all other branch/jump instructions) for target branch address
    //mux2 #(32) pcbrmux(.d0(PCTarget), .d1(ALUResultEX), .s(is_jalr), .y(PCTargetEX)); 
    
    mux2 #(32) targetpcmux(.d0(PCEX), .d1(Rs1DataEX), .s(is_jalr), .y(PCTarget));
    // Control signal that indicates whether next PC will be redirected or not (to go to IF stage)
    assign RedirectF = br_taken | is_jump;
    

    // SrcA forwarding mux
    mux2 #(32) srcAfwdmux(.d0(Rs1DataEX), .d1(WBfwdRdata1), .s(fwdsrcAsel), .y(srcAfwd));
    // SrcB forwarding mux
    mux2 #(32) srcBfwdmux(.d0(Rs2DataEX), .d1(WBfwdRdata2), .s(fwdsrcBsel), .y(srcBfwd));
    
    // SrcA selection mux
    logic [31:0] srcAout, srcBout;
    mux2 #(32) srcAmux(.d0(srcAfwd), .d1(32'b0), .s(srcA), .y(srcAout));
    
    // SrcB selection mux
    mux2 #(32) srcBmux(.d0(srcBfwd), .d1(ImmExtEX), .s(srcB), .y(srcBout));
    
    // Instantiate ALU
    alu alu(.a(srcAout), .b(srcBout), .ALUControl(ALUControlEX), .result(ALUResultEX));
    
    // Add Rs2 data forwarding path for store data forwarding
    assign Rs2DataSt = srcBfwd;
endmodule


module alu(input logic [31:0] a,b,
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

/*
    Module nane: Branch Compare Unit
    Description: Handles different branch comparison types, outputs whether branch is taken or not
*/
module brcomp(input brcond_e brcond,
              input logic [31:0] rs1, rs2,
              output logic br_taken
              );
logic eq, lt_signed, lt_unsigned;

assign eq = rs1 == rs2;
assign lt_unsigned = rs1 < rs2;
assign lt_signed = $signed(rs1) < $signed(rs2);

    always_comb begin
        unique case (brcond)
        BR_EQ: br_taken = eq;
        BR_NE: br_taken = ~eq;
        BR_LT: br_taken = lt_signed;
        BR_GE: br_taken = ~lt_signed;
        BR_LTU: br_taken = lt_unsigned;
        BR_GEU: br_taken = ~lt_unsigned;
        default: br_taken = 1'b0;
        endcase
    end
endmodule

/*
    Module name: Target PC Adder
    Description: Adds PC and immediate from immediate generator. Outputs sum of these two values
*/
module targetpc(input logic [31:0] PC, imm,
                output logic [31:0] PCTarget
                );
assign PCTarget = PC + imm;  
endmodule

/*
    Module name: 2-input Multiplexer
    Description: Module template for a 2-input multiplexer
*/
module mux2 #(parameter WIDTH = 8)
             (input logic [WIDTH-1:0] d0,d1,
              input logic s,
              output logic [WIDTH-1:0] y
              );
    assign y = s ? d1 : d0;
endmodule