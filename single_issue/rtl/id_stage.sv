import types_pkg::*;

/*
    Pipeline stage name: Instruction Decode
    Description: Generates control signals from opcode. Generates operation that needs to be performed by ALU
                 
*/
module id_stage(input logic clk, Wen, fwdsrcAselD, fwdsrcBselD,
                input logic [4:0] Rd,
                input logic [31:0] InstrD, Wd,
                output dec_out_t dmd,
                output logic [3:0] ALUControl,
                output logic [31:0] ImmExt, Rs1Data, Rs2Data
                );
    logic [6:0] op;
    logic opb5;
    logic funct7b5;
    logic [2:0] funct3;
    assign op = InstrD[6:0];
    assign opb5 = op[5];
    assign funct7b5 = InstrD[30];
    assign funct3 = InstrD[14:12];
    
    logic [4:0] Rs1, Rs2;
    assign Rs1 = InstrD[19:15];
    assign Rs2 = InstrD [24:20];
    
    // Control signals unique to ID stage, not part of the control signal bundle
    imm_e md_imm_type;
    aluop_e md_aluop;
    
    // Instantiate main decoder
    maindec maindec(.op(op), .funct3(funct3), .dmd(dmd), .md_aluop(md_aluop), .md_imm_type(md_imm_type));
    
    // Instantiate ALU decoder
    aludec aludec(.aluop(md_aluop), .funct3(funct3), .funct7b5(funct7b5), .opb5(opb5), .ALUControl(ALUControl));
    
    // Instantiate immediate genearator
    immgen immgen(.instr(InstrD), .imm_type(md_imm_type), .immext(ImmExt));
    
    // WB - ID forwarding
    logic [31:0] RegRs1Data, RegRs2Data;        // Data from register file
    
    assign Rs1Data = fwdsrcAselD ? Wd : RegRs1Data;
    assign Rs2Data = fwdsrcBselD ? Wd : RegRs2Data;
    
    // Instantiate register file
    regfile regfile(.clk(clk), .we3(Wen), .a1(Rs1), .a2(Rs2), .a3(Rd), .wd3(Wd), .rd1(RegRs1Data), .rd2(RegRs2Data));
endmodule

/*
    Module name: Main decoder
    Description: Receives instruction and outputs all relevant control signals to ensure data goes through correct datapth and is handled properly
*/
module maindec(
    input  logic [6:0] op,
    input logic [2:0] funct3,
    output dec_out_t dmd,
    output aluop_e md_aluop,
    output imm_e md_imm_type
);

always_comb begin
    // Defaults
    dmd = '0;
    md_imm_type    = IMM_X;
    dmd.result_sel  = RES_ALU;
    dmd.srcA        = SRCA_RS1;
    dmd.srcB        = SRCB_RS2;
    dmd.result_sel  = RES_ALU;
    dmd.brcond      = BR_X;
    dmd.ldst_size   = LDST_X;

    unique case (op)

        7'b0110011: begin // R-type ALU
            dmd.writes_rd   = 1;
            dmd.uses_rs1    = 1;
            dmd.uses_rs2    = 1;
            dmd.srcA        = SRCA_RS1;
            dmd.srcB        = SRCB_RS2;
            md_aluop       = ALUOP_FUNC;
            dmd.result_sel  = RES_ALU;
        end

        7'b0010011: begin // I-type ALU
            dmd.writes_rd   = 1;
            dmd.uses_rs1    = 1;
            md_imm_type    = IMM_I;
            dmd.srcA        = SRCA_RS1;
            dmd.srcB        = SRCB_IMM;
            md_aluop       = ALUOP_FUNC;
            dmd.result_sel  = RES_ALU;
        end

        7'b0000011: begin // Load
            dmd.writes_rd   = 1;
            dmd.uses_rs1    = 1;
            dmd.mem_read    = 1;
            md_imm_type    = IMM_I;
            dmd.srcA        = SRCA_RS1;
            dmd.srcB        = SRCB_IMM;
            md_aluop       = ALUOP_ADD; // Address calculation
            dmd.result_sel  = RES_MEM;
                  
            case(funct3)
            3'b000: begin dmd.ldst_size     = LDST_B; end
            3'b001: begin dmd.ldst_size     = LDST_H; end
            3'b010: begin dmd.ldst_size     = LDST_W; end 
            3'b100: begin dmd.ldst_size     = LDST_B; 
                          dmd.ldst_unsigned = 1; end
            3'b101: begin dmd.ldst_size     = LDST_H;
                          dmd.ldst_unsigned = 1; end   
            endcase
        end

        7'b0100011: begin // Store
            dmd.mem_write   = 1;
            dmd.uses_rs1    = 1;
            dmd.uses_rs2    = 1;
            md_imm_type    = IMM_S;
            dmd.srcA        = SRCA_RS1;
            dmd.srcB        = SRCB_IMM;
            md_aluop       = ALUOP_ADD;
            
            case(funct3)
            3'b000: begin dmd.ldst_size = LDST_B; end
            3'b001: begin dmd.ldst_size = LDST_H; end
            3'b010: begin dmd.ldst_size = LDST_W; end
            endcase
        end

        7'b1100011: begin // Branch
            dmd.uses_rs1    = 1;
            dmd.uses_rs2    = 1;
            md_imm_type    = IMM_B;
            dmd.srcA        = SRCA_RS1;
            dmd.srcB        = SRCB_RS2;
            md_aluop       = ALUOP_SUB;
            
            unique case (funct3)
            3'b000: dmd.brcond = BR_EQ;
            3'b001: dmd.brcond = BR_NE;
            3'b100: dmd.brcond = BR_LT;
            3'b101: dmd.brcond = BR_GE;
            3'b110: dmd.brcond = BR_LTU;
            3'b111: dmd.brcond = BR_GEU;
            endcase
        end

        7'b1101111: begin // JAL
            dmd.writes_rd   = 1;
            dmd.is_jump     = 1;
            md_imm_type    = IMM_J;
            dmd.result_sel  = RES_PC4;
        end

        7'b1100111: begin // JALR
            dmd.is_jalr     = 1;
            dmd.writes_rd   = 1;
            dmd.uses_rs1    = 1;
            dmd.is_jump     = 1;
            md_imm_type    = IMM_I;
            dmd.result_sel  = RES_PC4;
        end

        7'b0010111: begin // AUIPC
            dmd.writes_rd   = 1;
            md_imm_type    = IMM_U;
            dmd.result_sel  = RES_PCT;
        end

        7'b0110111: begin // LUI
            dmd.writes_rd   = 1;
            md_imm_type    = IMM_U;
            dmd.result_sel  = RES_IMM;
        end
    endcase
end

endmodule

/*
    Module: Immediate generator
    Description: Generates immediates depending on instruction type. Generates immediate passthrough for U-type instructions (LUI) so no ALU is needed
*/
module immgen(input logic [31:0] instr,
              input imm_e imm_type,
              output logic [31:0] immext
              );

always_comb begin

    unique case(imm_type)
        // I-type instructions
        IMM_I: begin
        immext = {{20{instr[31]}}, instr[31:20]}; 
        end

        // S-type instructions
        IMM_S: begin
        immext = {{20{instr[31]}}, instr[31:25], instr[11:7]}; 
        end
        
        // B-type instructions
        IMM_B: begin
        immext = {{20{instr[31]}}, instr[7], instr[30:25], instr[11:8], 1'b0}; 
        end
        
        // U-type instructions
        IMM_U: begin
        immext = {instr[31:12], 12'b0}; 
        end
        
        // J-type instructions
        IMM_J: begin
        immext = {{12{instr[31]}}, instr[19:12], instr[20], instr[30:21],1'b0}; 
        end

        default: begin
        immext = 32'b0;
        end
    endcase
end
endmodule

/*
    Module: ALU Decoder
    Description: Uses ALUOp for guaranteed ADD or SUB instructions. Uses funct3 and funct7 to determine exact ALU operation needed
*/

module aludec(input aluop_e aluop,
              input logic [2:0] funct3,
              input logic funct7b5,
              input logic opb5,
              output logic [3:0] ALUControl
              );
             
// Logic to determine between ADD or SUB instructions
logic RtypeSub;
assign RtypeSub = funct7b5 & opb5;

always_comb begin
    unique case (aluop)
        // Forced ADD instructions
        ALUOP_ADD: begin
        ALUControl = 4'b0000;
        end
    
        // Forced SUB instructions
        ALUOP_SUB: begin
        ALUControl = 4'b0001;
        end
        
        // Funct3 and funct7 calculation for specific function
        ALUOP_FUNC: begin
        case(funct3) // R-type or I-type ALU
			3'b000: if (RtypeSub)
				ALUControl = 4'b0001; // sub
			else
				ALUControl = 4'b0000; // add, addi
			3'b001: ALUControl = 4'b0100; // sll, slli
			3'b010: ALUControl = 4'b0101; // slt, slti
			3'b011: ALUControl = 4'b1000; // sltu, sltiu
			3'b100: ALUControl = 4'b0110; // xor, xori
			3'b101: if (~funct7b5)
				ALUControl = 4'b0111;	// srl
			else
				ALUControl = 4'b1111;  // sra
			3'b110: ALUControl = 4'b0011; // or, ori
			3'b111: ALUControl = 4'b0010; // and, andi
			default: ALUControl = 4'bxxxx; // ???
			endcase
        end
    endcase    
end
endmodule

/*
    Module name:    Register file
    Description:    Three ported register file (2 reads 1 write)
                    Read two ports combinationally
                    Write third port on rising edge of the clock
                    Register 0 hardwired to 0
*/
module regfile(input logic clk, we3,
               input logic [4:0] a1, a2, a3,
               input logic [31:0] wd3,
               output logic [31:0] rd1, rd2
               );
    logic [31:0] rf[31:0];

  always_ff @(posedge clk)
    if (we3 && (a3 != 0)) rf[a3] <= wd3;	

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule