import types_pkg::*;

/* 
    Pipeline stage name: Register read
    Description: Reads from register file
*/
module rr_stage(input logic             clk, I1_wrenable, I2_wrenable,
                input logic [1:0]       I1_fwdsrcAselD, I1_fwdsrcBselD, I2_fwdsrcAselD, I2_fwdsrcBselD,
                input logic [4:0]       I1_Rs1D, I1_Rs2D, I1_RdD, I2_Rs1D, I2_Rs2D, I2_RdD,
                input logic [31:0]      I1_WrDataD, I2_WrDataD,
                output logic [31:0]     I1_Rs1DataD, I1_Rs2DataD, I2_Rs1DataD, I2_Rs2DataD
                );
    // Register file bypass forwarding logic          
    logic [31:0] I1_RegRs1Data, I1_RegRs2Data, I2_RegRs1Data, I2_RegRs2Data;        // Data from register file

    mux3 #(32) I1_Rs1fwdsel(.d0(I1_RegRs1Data), .d1(I1_WrDataD), .d2(I2_WrDataD), .s(I1_fwdsrcAselD), .y(I1_Rs1DataD));
    mux3 #(32) I1_Rs2fwdsel(.d0(I1_RegRs2Data), .d1(I1_WrDataD), .d2(I2_WrDataD), .s(I1_fwdsrcBselD), .y(I1_Rs2DataD));
    mux3 #(32) I2_Rs1fwdsel(.d0(I2_RegRs1Data), .d1(I1_WrDataD), .d2(I2_WrDataD), .s(I2_fwdsrcAselD), .y(I2_Rs1DataD));
    mux3 #(32) I2_Rs2fwdsel(.d0(I2_RegRs2Data), .d1(I1_WrDataD), .d2(I2_WrDataD), .s(I2_fwdsrcBselD), .y(I2_Rs2DataD));
    
    
    // Instantiate register file
    regfile regfile(.clk(clk), .I1_wrenable(I1_wrenable), .I2_wrenable(I2_wrenable), .I1_Rs1(I1_Rs1D), .I1_Rs2(I1_Rs2D), .I1_Rd(I1_RdD), 
                    .I2_Rs1(I2_Rs1D), .I2_Rs2(I2_Rs2D), .I2_Rd(I2_RdD), .I1_WrData(I1_WrDataD), .I2_WrData(I2_WrDataD), .I1_Rs1Data(I1_RegRs1Data),
                    .I1_Rs2Data(I1_RegRs2Data), .I2_Rs1Data(I2_RegRs1Data), .I2_Rs2Data(I2_RegRs2Data));
endmodule

module regfile(input logic clk, I1_wrenable, I2_wrenable,
               input logic [4:0] I1_Rs1, I1_Rs2, I1_Rd, I2_Rs1, I2_Rs2, I2_Rd,
               input logic [31:0] I1_WrData, I2_WrData,
               output logic [31:0] I1_Rs1Data, I1_Rs2Data, I2_Rs1Data, I2_Rs2Data
               );
    (* ram_style = "distributed" *)logic [31:0] rf[31:0];
 
  // Six port register file
  // Two read ports and one write port per issue
  // Writes on positive clock edge
  // Register 0 hardwired to 0
    
    always_ff @(posedge clk) begin
        if (I1_wrenable && (I1_Rd != 0)) rf[I1_Rd] <= I1_WrData;
        if (I2_wrenable && (I2_Rd != 0)) rf[I2_Rd] <= I2_WrData;
    end
	
    assign I1_Rs1Data = (I1_Rs1 != 0) ? rf[I1_Rs1] : 0;
    assign I1_Rs2Data = (I1_Rs2 != 0) ? rf[I1_Rs2] : 0;
    assign I2_Rs1Data = (I2_Rs1 != 0) ? rf[I2_Rs1] : 0;
    assign I2_Rs2Data = (I2_Rs2 != 0) ? rf[I2_Rs2] : 0;
endmodule