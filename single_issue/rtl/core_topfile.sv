import types_pkg::*;

/*
    Module name: Core Top File
    Description: Top file for the processor design. Imports all other files and is where all modules are instantiated for simulation
*/

module core_topfile(input logic             clk, reset,
                    output logic [31:0]     StoreDataFPGA,
                    output logic            mem_writeFPGA);
  
    // Internal wiring for IF stage    
    logic RedirectF;
    logic [31:0] InstrF, PCTargetF, PCF, PCPlus4F;
    
    // Internal wiring for ID stage
    dec_out_t dD;
    logic [3:0] ALUControlD;
    logic [31:0] PCD, PCPlus4D, InstrD, Wd;
    logic [4:0] Rs1D, Rs2D, RdD;
    assign Rs1D = InstrD[19:15];
    assign Rs2D = InstrD[24:20];
    assign RdD = InstrD[11:7];
    logic [31:0] ImmExtD, Rs1DataD, Rs2DataD;
    
    // Internal wiring for EX stage
    dec_out_t dEX;
    logic [3:0] ALUControlEX;
    logic [31:0] PCEX, PCPlus4EX, ImmExtEX, Rs1DataEX, Rs2DataEX;
    logic [4:0] RdEX;
    logic [31:0] PCTargetEX;
    logic [31:0] ALUResultEX, Rs2DataSt;
    logic [4:0] Rs1EX, Rs2EX;
    
    
    // Internal wiring for WB stage
    dec_out_t dWB;
    logic [4:0] RdWB;
    logic [31:0] ALUResultWB, ImmExtWB, PCPlus4WB, PCTargetWB, Rs2DataWB;
    logic Wen;
    
    logic [31:0] MemResultWB;
    logic [31:0] RegWrite;
    
    assign RegWrite = dWB.mem_read ? MemResultWB : Wd;
    
    // Internal wiring for hazard unit
    logic fwdsrcAsel, fwdsrcBsel, fwdsrcAselRR, fwdsrcBselRR, stall, flushFDRR, flushE;
        
    // Instantiate IF stage
    if_stage if_stage(.clk(clk), .reset(reset), .enable(~stall), .RedirectF(RedirectF), .PCTargetF(PCTargetEX), .PCF(PCF), .PCPlus4F(PCPlus4F), .InstrF(InstrF));
    
    // Instantiate IF-ID pipeline register
    IF_ID IF_ID_pipreg(.clk(clk), .reset(reset), .clear(flushFDRR), .enable(~stall), .PCF(PCF), .PCPlus4F(PCPlus4F), 
                       .InstrF(InstrF), .PCD(PCD), .PCPlus4D(PCPlus4D), .InstrD(InstrD));
    
    // Instantiate ID stage
    id_stage id_stage(.clk(clk), .Wen(dWB.writes_rd), .fwdsrcAselD(fwdsrcAselD), .fwdsrcBselD(fwdsrcBselD), .Rd(RdWB), .InstrD(InstrD), .Wd(RegWrite), .dmd(dD), .ALUControl(ALUControlD), .ImmExt(ImmExtD), .Rs1Data(Rs1DataD), .Rs2Data(Rs2DataD));
    
    
   // Instantiate ID-EX pipeline register
   ID_EX ID_EX_pipreg(.clk(clk), .reset(reset), .clear(flushE), .enable(~stall),
                      .ALUControlD(ALUControlD), .PCD(PCD), .PCPlus4D(PCPlus4D), .ImmExtD(ImmExtD), .Rs1DataD(Rs1DataD), .Rs2DataD(Rs2DataD), .dD(dD), .RdD(RdD), .Rs1D(Rs1D), .Rs2D(Rs2D),
                      .ALUControlEX(ALUControlEX), .PCEX(PCEX), .PCPlus4EX(PCPlus4EX), .ImmExtEX(ImmExtEX), .Rs1DataEX(Rs1DataEX), .Rs2DataEX(Rs2DataEX), .dEX(dEX), .RdEX(RdEX), .Rs1EX(Rs1EX), .Rs2EX(Rs2EX));
    
    
    // Instantiate EX stage
    ex_stage ex_stage(.ALUControlEX(ALUControlEX), .brcond(dEX.brcond), .srcA(dEX.srcA), .srcB(dEX.srcB), .is_jump(dEX.is_jump), .is_jalr(dEX.is_jalr), .PCEX(PCEX), .Rs1DataEX(Rs1DataEX), .Rs2DataEX(Rs2DataEX),
                      .ImmExtEX(ImmExtEX), .RedirectF(RedirectF), .PCTargetEX(PCTargetEX), .ALUResultEX(ALUResultEX),
                      .fwdsrcAsel(fwdsrcAsel), .fwdsrcBsel(fwdsrcBsel), .WBfwdRdata1(Wd), .WBfwdRdata2(Wd), .Rs2DataSt(Rs2DataSt));
    
    // Instantiate EX-WB pipeline register
    EX_WB EX_WB_pipreg(.clk(clk), .reset(reset), .ALUResultEX(ALUResultEX), .ImmExtEX(ImmExtEX), .PCPlus4EX(PCPlus4EX), .PCTargetEX(PCTargetEX), .Rs2DataEX(Rs2DataSt), .RdEX(RdEX), .result_selEX(dEX.result_sel), .ldst_sizeEX(dEX.ldst_size),
                .ldst_unsignedEX(dEX.ldst_unsigned), .mem_readEX(dEX.mem_read), .mem_writeEX(dEX.mem_write), .writes_rdEX(dEX.writes_rd),
                .ALUResultWB(ALUResultWB), .ImmExtWB(ImmExtWB), .PCPlus4WB(PCPlus4WB), .PCTargetWB(PCTargetWB), .Rs2DataWB(Rs2DataWB), .RdWB(RdWB), .result_selWB(dWB.result_sel), .ldst_sizeWB(dWB.ldst_size),
                .ldst_unsignedWB(dWB.ldst_unsigned), .mem_readWB(dWB.mem_read), .mem_writeWB(dWB.mem_write), .writes_rdWB(dWB.writes_rd));
                
    // Instantiate WB stage
    logic [31:0] WriteDataWB;
    wb_stage wb_stage(.ALUResultWB(ALUResultWB), .ImmExtWB(ImmExtWB), .PCPlus4WB(PCPlus4WB), .PCTargetWB(PCTargetWB), .result_sel(dWB.result_sel), .clk(clk), .mem_read(dWB.mem_read), 
                      .mem_write(dWB.mem_write), .ldst_unsigned(dWB.ldst_unsigned), .ldst_size(dWB.ldst_size), .store_data(Rs2DataWB), .ResultWB(Wd), .MemResultWB(MemResultWB));
    
    
    // Instantiate Hazard Unit
    hazardunit hazardunit (.Rs1EX(Rs1EX), .Rs2EX(Rs2EX), .RdWB(RdWB), .Rs1D(Rs1D), .Rs2D(Rs2D), .brcondD(dD.brcond), .is_jalrD(dD.is_jalr), .RdEX(RdEX), .writes_rdEX(dEX.writes_rd), .writes_rdWB(dWB.writes_rd), .mem_readEX(dEX.mem_read), 
                           .uses_rs1D(dD.uses_rs1), .uses_rs2D(dD.uses_rs2), .uses_rs1EX(dEX.uses_rs1), .uses_rs2EX(dEX.uses_rs2), .fwdsrcAsel(fwdsrcAsel), .fwdsrcBsel(fwdsrcBsel), .fwdsrcAselD(fwdsrcAselD), .fwdsrcBselD(fwdsrcBselD), 
                           .stall(stall), .flushFDRR(flushFDRR), .flushE(flushE), .RedirectF(RedirectF));

    // Implementation
    assign StoreDataFPGA = Rs2DataWB; 
    assign mem_writeFPGA = dWB.mem_write;  
endmodule

/*
    Module name: IF - ID Pipeline Register
    Description: Holds state between IF and ID pipeline stages
*/
module IF_ID(input logic clk, reset, clear, enable,
             input logic [31:0] PCF, PCPlus4F, InstrF,
             output logic [31:0] PCD, PCPlus4D, InstrD
             );
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin // Asynchronous clear
            InstrD <= 0;
            PCD <= 0;
            PCPlus4D <= 0;
        end
        else if (clear) begin
            InstrD <= 0;
            PCD <= 0;
            PCPlus4D <= 0;
        end
        else if (enable) begin
            InstrD <= InstrF;
            PCD <= PCF;
            PCPlus4D <= PCPlus4F;       
        end
    end
endmodule

/*
    Module name: ID - RR Pipeline Register
    Description: Holds state between ID and RR pipeline stages
module ID_RR(input logic clk, reset, clear, enable,
             input logic [3:0] ALUControlD,
             input logic [4:0] Rs1D, Rs2D, RdD,
             input logic [31:0] PCD, PCPlus4D,
             input dec_out_t dD,
             input logic [31:0] ImmExtD,
             output logic [3:0] ALUControlRR,
             output logic [4:0] Rs1RR,Rs2RR,RdRR,
             output logic [31:0] PCRR, PCPlus4RR, 
             output dec_out_t dRR,
             output logic [31:0] ImmExtRR
             );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin // Asynchronous clear
            ALUControlRR <= 0;
            Rs1RR <= 0;
            Rs2RR <= 0;
            RdRR <= 0;
            PCRR <= 0;
            PCPlus4RR <= 0;
            dRR <= '0;
            ImmExtRR <= '0;
            
        end
        else if (clear) begin
            ALUControlRR <= 0;
            Rs1RR <= 0;
            Rs2RR <= 0;
            RdRR <= 0;
            PCRR <= 0;
            PCPlus4RR <= 0;
            dRR <= '0;
            ImmExtRR <= '0;
        end
        else if (enable) begin
            ALUControlRR <= ALUControlD;
            Rs1RR <= Rs1D;
            Rs2RR <= Rs2D;
            RdRR <= RdD;
            PCRR <= PCD;
            PCPlus4RR <= PCPlus4D;
            dRR <= dD;
            ImmExtRR <= ImmExtD;
        end
    end
endmodule
*/

/*
    Module name: ID - EX Pipeline Register
    Description: Holds state between RR and EX pipeline stages
*/
module ID_EX(input logic clk, reset, clear, enable,
             input logic [3:0] ALUControlD,
             input logic [4:0] RdD, Rs1D, Rs2D,
             input logic [31:0] PCD, PCPlus4D, ImmExtD, Rs1DataD, Rs2DataD,
             input dec_out_t dD,
             output logic [3:0] ALUControlEX,
             output logic [4:0] RdEX, Rs1EX, Rs2EX,
             output logic [31:0] PCEX, PCPlus4EX, ImmExtEX, Rs1DataEX, Rs2DataEX,
             output dec_out_t dEX
             );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin // Asynchronous clear
            ALUControlEX <= '0;
            PCEX <= '0;
            PCPlus4EX <= '0;
            ImmExtEX <= '0;
            Rs1DataEX <= '0;
            Rs2DataEX <= '0;
            dEX <= '0;
            RdEX <= '0;
            Rs1EX <= '0;
            Rs2EX <= '0;
        end
        else if (clear) begin
            ALUControlEX <= '0;
            PCEX <= '0;
            PCPlus4EX <= '0;
            ImmExtEX <= '0;
            Rs1DataEX <= '0;
            Rs2DataEX <= '0;
            dEX <= '0;
            RdEX <= '0;
            Rs1EX <= '0;
            Rs2EX <= '0;
        end
        else if (enable) begin
            ALUControlEX <= ALUControlD;
            PCEX <= PCD;
            PCPlus4EX <= PCPlus4D;
            ImmExtEX <= ImmExtD;
            Rs1DataEX <= Rs1DataD;
            Rs2DataEX <= Rs2DataD;
            dEX <= dD;
            RdEX <= RdD;
            Rs1EX <= Rs1D;
            Rs2EX <= Rs2D;
        end
    end
endmodule

/*
    Module name: EX - WB Pipeline Register
    Description: Holds state between EX and WB pipeline stages
*/
module EX_WB(input logic clk, reset,
             input logic ldst_unsignedEX, mem_readEX, mem_writeEX, writes_rdEX,
             input ldst_e ldst_sizeEX,
             input result_e result_selEX,
             input logic [4:0] RdEX,
             input logic [31:0] ALUResultEX, ImmExtEX, PCPlus4EX, PCTargetEX, Rs2DataEX,
             output logic ldst_unsignedWB, mem_readWB, mem_writeWB, writes_rdWB,
             output ldst_e ldst_sizeWB,
             output result_e result_selWB,
             output logic [4:0] RdWB,
             output logic [31:0] ALUResultWB, ImmExtWB, PCPlus4WB, PCTargetWB, Rs2DataWB            
             );
             
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            ALUResultWB <= '0;
            ImmExtWB <= '0;
            PCPlus4WB <= '0;
            PCTargetWB <= '0;
            Rs2DataWB <= '0;
            RdWB <= '0;
            ldst_unsignedWB <= '0;
            mem_readWB <= '0;
            mem_writeWB <= '0;
            writes_rdWB <= '0;
            ldst_sizeWB <= LDST_X;
            result_selWB <= RES_X;    
        end
        else begin
            ALUResultWB <= ALUResultEX;
            ImmExtWB <= ImmExtEX;
            PCPlus4WB <= PCPlus4EX;
            PCTargetWB <= PCTargetEX;
            Rs2DataWB <= Rs2DataEX;
            RdWB <= RdEX;
            ldst_unsignedWB <= ldst_unsignedEX;
            mem_readWB <= mem_readEX;
            mem_writeWB <= mem_writeEX;
            writes_rdWB <= writes_rdEX;
            ldst_sizeWB <= ldst_sizeEX;
            result_selWB <= result_selEX; 
        end
    end
endmodule

