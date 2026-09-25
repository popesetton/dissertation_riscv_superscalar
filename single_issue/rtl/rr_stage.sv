import types_pkg::*;

/* 
    Pipeline stage name: Register read
    Description: Reads from register file
*/
module rr_stage(input logic clk, Wen, fwdsrcAselRR, fwdsrcBselRR,
                input logic [4:0] Rs1, Rs2, Rd,
                input logic [31:0] Wd,
                output logic [31:0] Rs1Data, Rs2Data
                );
    // WB - RR forwarding
    logic [31:0] RegRs1Data, RegRs2Data;        // Data from register file

    assign Rs1Data = fwdsrcAselRR ? Wd : RegRs1Data;
    assign Rs2Data = fwdsrcBselRR ? Wd : RegRs2Data;
                
    // Instantiate register file
    regfile regfile(.clk(clk), .we3(Wen), .a1(Rs1), .a2(Rs2), .a3(Rd), .wd3(Wd), .rd1(RegRs1Data), .rd2(RegRs2Data));
endmodule

module regfile(input logic clk, we3,
               input logic [4:0] a1, a2, a3,
               input logic [31:0] wd3,
               output logic [31:0] rd1, rd2
               );
    logic [31:0] rf[31:0];

  // three ported register file
  // read two ports combinationally (A1/RD1, A2/RD2)
  // write third port on rising edge of clock (A3/WD3/WE3)
  // register 0 hardwired to 0

  always_ff @(posedge clk)
    if (we3 && (a3 != 0)) rf[a3] <= wd3;	

  assign rd1 = (a1 != 0) ? rf[a1] : 0;
  assign rd2 = (a2 != 0) ? rf[a2] : 0;
endmodule