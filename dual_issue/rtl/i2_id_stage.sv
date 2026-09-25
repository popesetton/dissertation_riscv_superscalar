import types_pkg::*;

/*
    Pipeline stage name: Instruction Decode
    Description: Generates control signal bundle
                 Generates ALU control
                 Generates extended immediates ready for use
*/
module i2_id_stage(input logic [31:0] I2_InstrD,
                   output i2_ctrl_t I2_ctrlD,
                   output logic [3:0] I2_ALUControlD,
                   output logic [31:0] I2_ImmExtD
                   );
    logic [6:0] op;
    logic opb5;
    logic funct7b5;
    logic [2:0] funct3;
    assign op = I2_InstrD[6:0];
    assign opb5 = op[5];
    assign funct7b5 = I2_InstrD[30];
    assign funct3 = I2_InstrD[14:12];
    
    aluop_e md_aluop;
    imm_e md_imm_type;
    
    
    // Instantiate main decoder
    i2_maindec i2_maindec(.op(op), .funct3(funct3), .dmd(I2_ctrlD), .md_imm_type(md_imm_type), .md_aluop(md_aluop));
    
    // Instantiate ALU decoder
    i2_aludec i2_aludec(.aluop(md_aluop), .funct3(funct3), .funct7b5(funct7b5), .opb5(opb5), .ALUControl(I2_ALUControlD));
    
    // Instantiate immediate genearator
    i2_immgen i2_immgen(.instr(I2_InstrD), .imm_type(md_imm_type), .immext(I2_ImmExtD));
    
endmodule

/*
    Module name: Main decoder
    Description: Receives instruction and outputs all relevant control signals to ensure data goes through correct datapth and is handled properly
*/
module i2_maindec(
    input  logic [6:0] op,
    input logic [2:0] funct3,
    output i2_ctrl_t dmd,
    output imm_e md_imm_type,
    output aluop_e md_aluop
);

always_comb begin
    // Defaults
    dmd = '0;
    md_imm_type   = IMM_X;
    dmd.result_sel = RES_ALU;
    dmd.srcA       = SRCA_RS1;
    dmd.srcB       = SRCB_RS2;
    dmd.result_sel = RES_ALU;
    md_aluop = ALUOP_ADD;

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

        7'b0010111: begin // AUIPC
            dmd.writes_rd = 1;
            dmd.srcA        = SRCA_PC;
            dmd.srcB        = SRCB_IMM;
            md_aluop        = ALUOP_ADD;
            md_imm_type  = IMM_U;
            dmd.result_sel = RES_ALU;
        end

        7'b0110111: begin // LUI
            dmd.writes_rd = 1;
            md_imm_type  = IMM_U;
            dmd.result_sel = RES_IMM;
        end
    endcase
end

endmodule

/*
    Module: Immediate generator
    Description: Generates immediates depending on instruction type. Generates immediate passthrough for U-type instructions (LUI) so no ALU is needed
*/
module i2_immgen(input logic [31:0] instr,
              input imm_e imm_type,
              output logic [31:0] immext
              );

always_comb begin

    unique case(imm_type)
        // I-type instructions
        IMM_I: begin
        immext = {{20{instr[31]}}, instr[31:20]}; 
        end
        
        // U-type instructions
        IMM_U: begin
        immext = {instr[31:12], 12'b0}; 
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

module i2_aludec(input aluop_e aluop,
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