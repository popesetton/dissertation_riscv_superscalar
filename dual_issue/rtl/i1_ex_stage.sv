import types_pkg::*;
/*
    Pipeline stage name: Execute
    Description: Executes decoded instructions, handles taken branch and target PC logic
*/
module i1_ex_stage(input logic [3:0]    I1_ALUControlEX,
                input                   brcond_e brcond,
                input srcA_e            I1_srcA,
                input srcB_e            I1_srcB,
                input logic [31:0]      I1_PCEX, I1_Rs1DataEX, I1_Rs2DataEX, I1_ImmExtEX, I1_WBfwdI1Data, I1_WBfwdI2Data,
                input logic             is_jump, is_jalr,
                input logic [1:0]       I1_fwdsrcAsel, I1_fwdsrcBsel,
                output logic            RedirectF, br_taken,
                output logic [31:0]     PCTargetEX, I1_ALUResultEX,
                output logic [31:0]     I1_Rs2DataSt
                );
 
    // Interal wiring
    logic [31:0] srcAfwd, srcBfwd;      // Forwarding mux outputs
    logic [31:0] PCTarget;              // Target PC mux output
    
    // Instantiate target PC adder
    i1_targetpc i1_targetpc(.PC(PCTarget), .imm(I1_ImmExtEX), .PCTarget(PCTargetEX));
    
    // Choose between PC or rs1 data for target PC adder (rs1 for JALR only)   
    mux2 #(32) targetpcmux(.d0(I1_PCEX), .d1(I1_Rs1DataEX), .s(is_jalr), .y(PCTarget));
    
    // SrcA forwarding mux
    mux3 #(32) srcAfwdmux(.d0(I1_Rs1DataEX), .d1(I1_WBfwdI1Data), .d2(I1_WBfwdI2Data), .s(I1_fwdsrcAsel), .y(srcAfwd));
    
    // SrcB forwarding mux
    mux3 #(32) srcBfwdmux(.d0(I1_Rs2DataEX), .d1(I1_WBfwdI1Data), .d2(I1_WBfwdI2Data), .s(I1_fwdsrcBsel), .y(srcBfwd));
    
    // SrcA selection mux
    logic [31:0] srcAout, srcBout;
    mux2 #(32) srcAmux(.d0(srcAfwd), .d1(32'b0), .s(I1_srcA), .y(srcAout));
    
    // SrcB selection mux
    mux2 #(32) srcBmux(.d0(srcBfwd), .d1(I1_ImmExtEX), .s(I1_srcB), .y(srcBout));
    
    // Instantiate ALU
    i1_alu i1_alu(.a(srcAout), .b(srcBout), .ALUControl(I1_ALUControlEX), .result(I1_ALUResultEX));
    
    // Instantiate branch condition unit
    brcomp brcomp(.brcond(brcond), .rs1(I1_Rs1DataEX), .rs2(I1_Rs2DataEX), .br_taken(br_taken));
    
     // Control signal that indicates whether next PC will be redirected or not (to go to IF stage)
    assign RedirectF = (is_jump | br_taken);
    
    // Add rs2 data forwarding path for store data forwarding
    assign I1_Rs2DataSt = srcBfwd;
endmodule


module i1_alu(input logic [31:0] a,b,
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
module i1_targetpc(input logic [31:0] PC, imm,
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

/*
    Module name: 3-input multiplexer
    Description: Module template for a 3-input multiplexer
*/
module mux3 #(parameter WIDTH = 8)
             (input logic [WIDTH-1:0] d0, d1, d2,
              input logic [1:0] s,
              output logic [WIDTH-1:0] y);
    /*
        s[00] = d0
        s[01] = d1
        s[10] = d2
        s[11] = default
    */
    assign y = s[1] ? d2 : (s[0] ? d1 : d0); 
endmodule

