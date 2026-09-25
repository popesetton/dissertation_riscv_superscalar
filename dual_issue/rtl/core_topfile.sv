import types_pkg::*;

/*
    Module name: Core Top File
    Description: Top file for processor design. Imports all other files and is where modules are instantiated for simulation
*/
module core_topfile(input logic             clk, reset,
                    output logic [31:0]     StoreDataFPGA,
                    output logic            mem_writeFPGA);

    // Internal wiring for IF stage
    logic RedirectF, I2_valid, I2_bubble, stall, flushFDRR;
    logic [31:0] PCTargetF, PCF, PCPlus4F, I1_InstrF, I2_InstrF;            // IF - ID pipeline register values
    
    // Insert bubble into issue 2 if it is not valid
    assign I2_bubble = ~I2_valid | flushFDRR;
    
    // Internal wiring for ID stage
    logic [31:0] I1_PCD, I2_PCD, I1_PCPlus4D, I1_InstrD, I2_InstrD;         // IF - ID pipeline register values
    i1_ctrl_t I1_ctrlD;
    i2_ctrl_t I2_ctrlD;
    logic [3:0] I1_ALUControlD, I2_ALUControlD;
    
    logic [4:0] I1_Rs1D, I1_Rs2D, I1_RdD, I2_Rs1D, I2_Rs2D, I2_RdD;         
    assign I1_Rs1D = I1_InstrD[19:15];
    assign I1_Rs2D = I1_InstrD[24:20];
    assign I1_RdD = I1_InstrD[11:7];
    assign I2_Rs1D = I2_InstrD[19:15];
    assign I2_Rs2D = I2_InstrD[24:20];
    assign I2_RdD = I2_InstrD[11:7];
    logic [31:0] I1_ImmExtD, I2_ImmExtD;                                    
    logic I2_wrenable;  
    logic [1:0] I1_fwdsrcAselD, I1_fwdsrcBselD, I2_fwdsrcBselD, I2_fwdsrcAselD;
    logic [31:0] I1_Rs1DataD, I1_Rs2DataD, I2_Rs1DataD, I2_Rs2DataD, I1_WrDataD, I2_WrDataD;  
    
    // Internal wiring for EX stage
    i1_ctrl_t I1_ctrlEX;
    i2_ctrl_t I2_ctrlEX;
    logic br_taken;
    logic [3:0] I1_ALUControlEX, I2_ALUControlEX;
    logic [4:0] I1_Rs1EX, I1_Rs2EX, I1_RdEX, I2_Rs1EX, I2_Rs2EX, I2_RdEX;       
    logic [31:0] I1_PCEX, I2_PCEX, I1_PCPlus4EX, I1_ImmExtEX, I2_ImmExtEX, PCTargetEX, I1_ALUResultEX, I1_Rs2DataSt, I2_PCTargetEX, I2_ALUResultEX;
    logic [1:0] I1_fwdsrcAsel, I1_fwdsrcBsel, I2_fwdsrcBsel, I2_fwdsrcAsel;
    logic [31:0] I1_WBfwdRs1Data, I1_WBfwdRs2Data, I2_WBfwdRs1Data, I2_WBfwdRs2Data, I1_Rs1DataEX, I1_Rs2DataEX, I2_Rs1DataEX, I2_Rs2DataEX;
    
    // Internal wiring for WB stage
    i1_ctrl_t I1_ctrlWB;
    i2_ctrl_t I2_ctrlWB;
    logic killWB;
    logic [4:0] I1_RdWB, I2_RdWB;
    logic [31:0] I1_ALUResultWB, I1_ImmExtWB, I1_PCPlus4WB, PCPlus4WB, PCTargetWB, Rs2DataWB, I2_ALUResultWB, I2_ImmExtWB, I2_PCTargetWB;
    
    logic [31:0] I1_MemResultWB, I1_RegWrite;
    assign I1_RegWrite = I1_ctrlWB.mem_read ? I1_MemResultWB : I1_WrDataD;
    
    assign I2_wrenable = I2_ctrlWB.writes_rd & ~killWB;
    
    // Internal wiring for hazard unit
    logic flushE;
    
    // Instantiate IF stage
    if_stage if_stage(.clk(clk), .reset(reset), .enable(~stall), .RedirectF(RedirectF), .PCTargetF(PCTargetEX), .I2_valid(I2_valid), .PCF(PCF), .PCPlus4F(PCPlus4F), .I1_InstrF(I1_InstrF), .I2_InstrF(I2_InstrF));
    
    // Instantiate IF - ID pipeline registers
    I1_IF_ID I1_IF_ID_pipreg(.clk(clk), .reset(reset), .clear(flushFDRR), .enable(~stall), .PCF(PCF), .PCPlus4F(PCPlus4F), 
                                            .InstrF(I1_InstrF), .PCD(I1_PCD), .PCPlus4D(I1_PCPlus4D), .InstrD(I1_InstrD));
    
    I2_IF_ID I2_IF_ID_pipreg(.clk(clk), .reset(reset), .clear(I2_bubble), .enable(~stall), .PCF(PCPlus4F), 
                                            .InstrF(I2_InstrF), .PCD(I2_PCD), .InstrD(I2_InstrD));    // PCPlus 4 ommitted from pipreg; PCPlus4 fed into PCF since issue 2's current instruction is PC+4
                                            
    // Instantiate ID stage
    i1_id_stage i1_id_stage(.I1_InstrD(I1_InstrD), .I1_ctrlD(I1_ctrlD), .I1_ALUControlD(I1_ALUControlD), .I1_ImmExtD(I1_ImmExtD));
    i2_id_stage i2_id_stage(.I2_InstrD(I2_InstrD), .I2_ctrlD(I2_ctrlD), .I2_ALUControlD(I2_ALUControlD), .I2_ImmExtD(I2_ImmExtD));
    
    // Instantiate RR stage
    rr_stage rr_stage(.clk(clk), .I1_wrenable(I1_ctrlWB.writes_rd), .I2_wrenable(I2_wrenable), .I1_fwdsrcAselD(I1_fwdsrcAselD), .I1_fwdsrcBselD(I1_fwdsrcBselD), .I2_fwdsrcAselD(I2_fwdsrcAselD),
                      .I2_fwdsrcBselD(I2_fwdsrcBselD), .I1_Rs1D(I1_Rs1D), .I1_Rs2D(I1_Rs2D), .I1_RdD(I1_RdWB), .I2_Rs1D(I2_Rs1D), .I2_Rs2D(I2_Rs2D), .I2_RdD(I2_RdWB), .I1_WrDataD(I1_RegWrite), 
                      .I2_WrDataD(I2_WrDataD), .I1_Rs1DataD(I1_Rs1DataD), .I1_Rs2DataD(I1_Rs2DataD), .I2_Rs1DataD(I2_Rs1DataD), .I2_Rs2DataD(I2_Rs2DataD));
                      
    // Instantiate RR - EX pipeline registers
    I1_ID_EX I1_ID_EX_pipreg(.clk(clk), .reset(reset), .clear(flushE) , .enable(~stall), .ALUControlD(I1_ALUControlD), .Rs1D(I1_Rs1D), .Rs2D(I1_Rs2D), .RdD(I1_RdD), 
            .PCD(I1_PCD), .PCPlus4D(I1_PCPlus4D), .I1_ctrlD(I1_ctrlD), .ImmExtD(I1_ImmExtD), .Rs1DataD(I1_Rs1DataD), .Rs2DataD(I1_Rs2DataD),
            .ALUControlEX(I1_ALUControlEX), .Rs1EX(I1_Rs1EX), .Rs2EX(I1_Rs2EX), .RdEX(I1_RdEX), 
            .PCEX(I1_PCEX), .PCPlus4EX(I1_PCPlus4EX), .I1_ctrlEX(I1_ctrlEX), .ImmExtEX(I1_ImmExtEX), .Rs1DataEX(I1_Rs1DataEX), .Rs2DataEX(I1_Rs2DataEX));
    
    I2_ID_EX I2_ID_EX_pipreg(.clk(clk), .reset(reset), .clear(flushE) , .enable(~stall), .ALUControlD(I2_ALUControlD), .Rs1D(I2_Rs1D), .Rs2D(I2_Rs2D), .RdD(I2_RdD), 
            .PCD(I2_PCD), .I2_ctrlD(I2_ctrlD), .ImmExtD(I2_ImmExtD), .Rs1DataD(I2_Rs1DataD), .Rs2DataD(I2_Rs2DataD),
            .ALUControlEX(I2_ALUControlEX), .Rs1EX(I2_Rs1EX), .Rs2EX(I2_Rs2EX), .RdEX(I2_RdEX), 
            .PCEX(I2_PCEX), .I2_ctrlEX(I2_ctrlEX), .ImmExtEX(I2_ImmExtEX), .Rs1DataEX(I2_Rs1DataEX), .Rs2DataEX(I2_Rs2DataEX));
    
    // Instantiate EX stage
    i1_ex_stage i1_ex_stage(.I1_ALUControlEX(I1_ALUControlEX), .brcond(I1_ctrlEX.brcond), .I1_srcA(I1_ctrlEX.srcA), .I1_srcB(I1_ctrlEX.srcB), .I1_PCEX(I1_PCEX), .I1_Rs1DataEX(I1_Rs1DataEX), .I1_Rs2DataEX(I1_Rs2DataEX),
                            .I1_ImmExtEX(I1_ImmExtEX), .I1_WBfwdI1Data(I1_WrDataD), .I1_WBfwdI2Data(I2_WrDataD), .I1_fwdsrcAsel(I1_fwdsrcAsel), .I1_fwdsrcBsel(I1_fwdsrcBsel),
                            .is_jump(I1_ctrlEX.is_jump), .is_jalr(I1_ctrlEX.is_jalr), .RedirectF(RedirectF), .br_taken(br_taken), .PCTargetEX(PCTargetEX), .I1_ALUResultEX(I1_ALUResultEX), .I1_Rs2DataSt(I1_Rs2DataSt));
    
    i2_ex_stage i2_ex_stage(.I2_ALUControlEX(I2_ALUControlEX), .I2_srcA(I2_ctrlEX.srcA), .I2_srcB(I2_ctrlEX.srcB), .I2_PCEX(I2_PCEX), .I2_Rs1DataEX(I2_Rs1DataEX), .I2_Rs2DataEX(I2_Rs2DataEX), .I2_ImmExtEX(I2_ImmExtEX), .I2_WBfwdI1Data(I1_WrDataD),
                            .I2_WBfwdI2Data(I2_WrDataD), .I2_fwdsrcAsel(I2_fwdsrcAsel), .I2_fwdsrcBsel(I2_fwdsrcBsel), .I2_ALUResultEX(I2_ALUResultEX));
    
    
    // Instantiage EX - WB pipeline registers
    I1_EX_WB  I1_EX_WB_pipreg(.clk(clk), .reset(reset), .ldst_unsignedEX(I1_ctrlEX.ldst_unsigned), .mem_readEX(I1_ctrlEX.mem_read), .mem_writeEX(I1_ctrlEX.mem_write), .writes_rdEX(I1_ctrlEX.writes_rd),
                             .ldst_sizeEX(I1_ctrlEX.ldst_size), .result_selEX(I1_ctrlEX.result_sel), .RdEX(I1_RdEX), .ALUResultEX(I1_ALUResultEX), .ImmExtEX(I1_ImmExtEX), .PCPlus4EX(I1_PCPlus4EX), .PCTargetEX(PCTargetEX), .Rs2DataEX(I1_Rs2DataSt),
                             .ldst_unsignedWB(I1_ctrlWB.ldst_unsigned), .mem_readWB(I1_ctrlWB.mem_read), .mem_writeWB(I1_ctrlWB.mem_write), .writes_rdWB(I1_ctrlWB.writes_rd),
                             .ldst_sizeWB(I1_ctrlWB.ldst_size), .result_selWB(I1_ctrlWB.result_sel), .RdWB(I1_RdWB), .ALUResultWB(I1_ALUResultWB), .ImmExtWB(I1_ImmExtWB), .PCPlus4WB(I1_PCPlus4WB), .PCTargetWB(PCTargetWB), .Rs2DataWB(Rs2DataWB));
    
    I2_EX_WB I2_EX_WB_pipreg(.clk(clk), .reset(reset), .writes_rdEX(I2_ctrlEX.writes_rd), .killEX(br_taken), .result_selEX(I2_ctrlEX.result_sel), .RdEX(I2_RdEX), .ALUResultEX(I2_ALUResultEX), .ImmExtEX(I2_ImmExtEX),
            .writes_rdWB(I2_ctrlWB.writes_rd), .killWB(killWB), .result_selWB(I2_ctrlWB.result_sel), .RdWB(I2_RdWB), .ALUResultWB(I2_ALUResultWB), .ImmExtWB(I2_ImmExtWB));
    
   // Instantiate WB stage
   i1_wb_stage i1_wb_stage(.clk(clk), .I1_ALUResultWB(I1_ALUResultWB), .I1_ImmExtWB(I1_ImmExtWB), .I1_PCPlus4WB(I1_PCPlus4WB), .PCTargetWB(PCTargetWB), .I1_result_sel(I1_ctrlWB.result_sel), .mem_read(I1_ctrlWB.mem_read), .mem_write(I1_ctrlWB.mem_write),
                           .ldst_unsigned(I1_ctrlWB.ldst_unsigned), .ldst_size(I1_ctrlWB.ldst_size), .store_data(Rs2DataWB), .I1_ResultWB(I1_WrDataD), .I1_MemResultWB(I1_MemResultWB));
   
   i2_wb_stage i2_wb_stage(.I2_ALUResultWB(I2_ALUResultWB), .I2_ImmExtWB(I2_ImmExtWB), .I2_result_sel(I2_ctrlWB.result_sel), .I2_ResultWB(I2_WrDataD));
    
    // Instantiate hazard unit
    hazardunit hazardunit (.I1_Rs1EX(I1_Rs1EX), .I1_Rs2EX(I1_Rs2EX), .I1_RdWB(I1_RdWB), .I2_Rs1EX(I2_Rs1EX), .I2_Rs2EX(I2_Rs2EX), .I2_RdWB(I2_RdWB), .I1_Rs1D(I1_Rs1D), .I1_Rs2D(I1_Rs2D), .I1_RdEX(I1_RdEX), .I2_Rs1D(I2_Rs1D), .I2_Rs2D(I2_Rs2D),
                           .I2_RdEX(I2_RdEX), .I1_writes_rdWB(I1_ctrlWB.writes_rd), .I2_writes_rdWB(I2_ctrlWB.writes_rd), .I1_writes_rdEX(I1_ctrlEX.writes_rd), .mem_read(I1_ctrlEX.mem_read), .is_jalrD(I1_ctrlD.is_jalr), .brcondD(I1_ctrlD.brcond),
                           .I1_uses_rs1D(I1_ctrlD.uses_rs1), .I1_uses_rs2D(I1_ctrlD.uses_rs2), .I1_uses_rs1EX(I1_ctrlEX.uses_rs1), .I1_uses_rs2EX(I1_ctrlEX.uses_rs2), .I2_uses_rs1D(I2_ctrlD.uses_rs1), .I2_uses_rs2D(I2_ctrlD.uses_rs2), .I2_uses_rs1EX(I2_ctrlEX.uses_rs1), .I2_uses_rs2EX(I2_ctrlEX.uses_rs2), 
                           .RedirectF(RedirectF), .I1_fwdsrcAsel(I1_fwdsrcAsel), .I1_fwdsrcBsel(I1_fwdsrcBsel), .I2_fwdsrcAsel(I2_fwdsrcAsel), .I2_fwdsrcBsel(I2_fwdsrcBsel), .I1_fwdsrcAselD(I1_fwdsrcAselD), .I1_fwdsrcBselD(I1_fwdsrcBselD),
                           .I2_fwdsrcAselD(I2_fwdsrcAselD), .I2_fwdsrcBselD(I2_fwdsrcBselD), .stall(stall), .flushFDRR(flushFDRR), .flushE(flushE));

    // Implementation
    assign StoreDataFPGA = Rs2DataWB;
    assign mem_writeFPGA = I1_ctrlWB.mem_write;  
endmodule

/*
    Module name: Issue 1 IF - ID Pipeline Register
    Description: Holds state between IF and ID pipeline stages for issue 1
*/
module I1_IF_ID(input logic clk, reset, clear, enable,
                input logic [31:0] PCF, PCPlus4F, InstrF,
                output logic [31:0] PCD, PCPlus4D, InstrD
                );
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin // Asynchronous clear
            InstrD <= '0;
            PCD <= '0;
            PCPlus4D <= '0;
        end
        else if (clear) begin
            InstrD <= '0;
            PCD <= '0;
            PCPlus4D <= '0;
        end
        else if (enable) begin
            InstrD <= InstrF;
            PCD <= PCF;
            PCPlus4D <= PCPlus4F;     
        end
    end

endmodule

/*
    Module name: Issue 2 IF - ID Pipeline Register
    Description: Holds state between IF and ID pipeline stages for issue 2
*/
module I2_IF_ID(input logic clk, reset, clear, enable,
             input logic [31:0] PCF, InstrF,
             output logic [31:0] PCD, InstrD
             );
    
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin // Asynchronous clear
            InstrD <= '0;
            PCD <= '0;
        end
        else if (clear) begin
            InstrD <= '0;
            PCD <= '0;
        end
        else if (enable) begin
            InstrD <= InstrF;
            PCD <= PCF;     
        end
    end
endmodule

/*
    Module name: Issue 1 ID - EX Pipeline Register
    Description: Holds state between ID and EX pipeline stages for issue 1
*/
module I1_ID_EX(input logic clk, reset, clear, enable,
                 input logic [3:0] ALUControlD,
                 input logic [4:0] RdD, Rs1D, Rs2D,
                 input logic [31:0] PCD, PCPlus4D, ImmExtD, Rs1DataD, Rs2DataD,
                 input i1_ctrl_t I1_ctrlD,
                 output logic [3:0] ALUControlEX,
                 output logic [4:0] RdEX, Rs1EX, Rs2EX,
                 output logic [31:0] PCEX, PCPlus4EX, ImmExtEX, Rs1DataEX, Rs2DataEX,
                 output i1_ctrl_t I1_ctrlEX
                 );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin // Asynchronous clear
            ALUControlEX <= '0;
            PCEX <= '0;
            ImmExtEX <= '0;
            Rs1DataEX <= '0;
            Rs2DataEX <= '0;
            RdEX <= '0;
            Rs1EX <= '0;
            Rs2EX <= '0;
            I1_ctrlEX <= '0;
            PCPlus4EX <= '0;
        end
        else if (clear) begin
            ALUControlEX <= '0;
            PCEX <= '0;
            ImmExtEX <= '0;
            Rs1DataEX <= '0;
            Rs2DataEX <= '0;
            RdEX <= '0;
            Rs1EX <= '0;
            Rs2EX <= '0;
            I1_ctrlEX <= '0;
            PCPlus4EX <= '0;
        end
        else if (enable) begin
            ALUControlEX <= ALUControlD;
            PCEX <= PCD;
            ImmExtEX <= ImmExtD;
            Rs1DataEX <= Rs1DataD;
            Rs2DataEX <= Rs2DataD;
            RdEX <= RdD;
            Rs1EX <= Rs1D;
            Rs2EX <= Rs2D;
            PCPlus4EX <= PCPlus4D;
            I1_ctrlEX <= I1_ctrlD;
        end
    end
endmodule

/*
    Module name: Issue 2 ID - EX Pipeline Register
    Description: Holds state between ID and EX pipeline stages for issue 2
*/
module I2_ID_EX (input logic clk, reset, clear, enable,
             input logic [3:0] ALUControlD,
             input logic [4:0] RdD, Rs1D, Rs2D,
             input logic [31:0] PCD, ImmExtD, Rs1DataD, Rs2DataD,
             input i2_ctrl_t I2_ctrlD,
             output logic [3:0] ALUControlEX,
             output logic [4:0] RdEX, Rs1EX, Rs2EX,
             output logic [31:0] PCEX, ImmExtEX, Rs1DataEX, Rs2DataEX,
             output i2_ctrl_t I2_ctrlEX
             );

    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin // Asynchronous clear
            ALUControlEX <= '0;
            PCEX <= '0;
            ImmExtEX <= '0;
            Rs1DataEX <= '0;
            Rs2DataEX <= '0;
            RdEX <= '0;
            Rs1EX <= '0;
            Rs2EX <= '0;
            I2_ctrlEX <= '0;
        end
        else if (clear) begin
            ALUControlEX <= '0;
            PCEX <= '0;
            ImmExtEX <= '0;
            Rs1DataEX <= '0;
            Rs2DataEX <= '0;
            RdEX <= '0;
            Rs1EX <= '0;
            Rs2EX <= '0;
            I2_ctrlEX <= '0;
        end
        else if (enable) begin
            ALUControlEX <= ALUControlD;
            PCEX <= PCD;
            ImmExtEX <= ImmExtD;
            Rs1DataEX <= Rs1DataD;
            Rs2DataEX <= Rs2DataD;
            RdEX <= RdD;
            Rs1EX <= Rs1D;
            Rs2EX <= Rs2D;
            I2_ctrlEX <= I2_ctrlD;
        end
    end
endmodule

/*
    Module name: Issue 1 EX - WB Pipeline Register
    Description: Holds state between EX and WB pipeline stages for issue 1
*/
module I1_EX_WB(input logic clk, reset,
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
            PCTargetWB <= '0;
            writes_rdWB <= '0;
            RdWB <= '0;
            result_selWB <= RES_X;
            PCPlus4WB <= '0;
            Rs2DataWB <= '0;
            ldst_unsignedWB <= '0;
            mem_readWB <= '0;
            mem_writeWB <= '0;
            ldst_sizeWB <= LDST_X;    
        end
        else begin
            ALUResultWB <= ALUResultEX;
            ImmExtWB <= ImmExtEX;
            PCTargetWB <= PCTargetEX;
            writes_rdWB <= writes_rdEX;
            RdWB <= RdEX;
            result_selWB <= result_selEX; 
            PCPlus4WB <= PCPlus4EX;
            Rs2DataWB <= Rs2DataEX;
            ldst_unsignedWB <= ldst_unsignedEX;
            mem_readWB <= mem_readEX;
            mem_writeWB <= mem_writeEX;
            ldst_sizeWB <= ldst_sizeEX;
        end
    end
endmodule

/*
    Module name: Issue 2 EX - WB Pipeline Register
    Description: Holds state between EX and WB pipeline stages for issue 2
*/
module I2_EX_WB(input logic clk, reset,
                input logic writes_rdEX, killEX,
                input result_e result_selEX,
                input logic [4:0] RdEX,
                input logic [31:0] ALUResultEX, ImmExtEX, PCTargetEX,
                output logic writes_rdWB, killWB,
                output ldst_e ldst_sizeWB,
                output result_e result_selWB,
                output logic [4:0] RdWB,
                output logic [31:0] ALUResultWB, ImmExtWB,PCTargetWB          
             );
             
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            ALUResultWB <= '0;
            ImmExtWB <= '0;
            PCTargetWB <= '0;
            writes_rdWB <= '0;
            RdWB <= '0;
            result_selWB <= RES_X; 
            killWB <= '0;   
        end
        else begin
            ALUResultWB <= ALUResultEX;
            ImmExtWB <= ImmExtEX;
            PCTargetWB <= PCTargetEX;
            writes_rdWB <= writes_rdEX;
            RdWB <= RdEX;
            result_selWB <= result_selEX; 
            killWB <= killEX;
        end
    end
endmodule