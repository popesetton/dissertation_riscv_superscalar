import types_pkg::*;

/*
    Module name: Hazard unit
    Description: Handles all relevant data and control hazards present in the core
*/
module hazardunit(input logic [4:0] Rs1EX, Rs2EX, RdWB, // For forwarding logic
                  input logic [4:0] Rs1D, Rs2D, RdEX, // For load-use hazards
                  input logic writes_rdWB, writes_rdEX, mem_readEX, RedirectF, is_jalrD, uses_rs1D, uses_rs2D, uses_rs1EX, uses_rs2EX,
                  input brcond_e brcondD,
                  output logic fwdsrcAsel, fwdsrcBsel, fwdsrcAselD, fwdsrcBselD, stall, flushFDRR, flushE);
                  
    always_comb begin
        // Defaults
        fwdsrcAsel = 1'b0;
        fwdsrcBsel = 1'b0;
        fwdsrcAselD = 1'b0;
        fwdsrcBselD = 1'b0; 
        stall = 1'b0;
        flushFDRR = 1'b0;
        flushE = 1'b0;
        
        // Forwarding logic
        // WB to EX logic
        if ((Rs1EX == RdWB) && (writes_rdWB) && (Rs1EX != 0) && (uses_rs1EX))
            fwdsrcAsel = 1'b1;
        
        if ((Rs2EX == RdWB) && (writes_rdWB) && (Rs2EX != 0) && (uses_rs2EX))
            fwdsrcBsel = 1'b1;
            
        // WB to ID logic
        if ((Rs1D == RdWB) && (writes_rdWB) && (Rs1D != 0) && (uses_rs1D))
            fwdsrcAselD = 1'b1;
            
        if ((Rs2D == RdWB) && (writes_rdWB) && (Rs2D != 0) && (uses_rs2D))
            fwdsrcBselD = 1'b1;
            
        // Stall logic for load-use hazards
        if ((Rs1D == RdEX) && (writes_rdEX) && (Rs1D != 0) && (mem_readEX) && (uses_rs1D)) begin
            stall = 1'b1;
            flushE = 1'b1;
        end
            
        if ((Rs2D == RdEX) && (writes_rdEX) && (Rs2D != 0) && (mem_readEX) && (uses_rs2D)) begin
            stall = 1'b1;
            flushE = 1'b1;
        end
        
        // Stall logic for branch forwarding
        if ((Rs1D == RdEX) && (brcondD != BR_X) && (Rs1D != 0) && (uses_rs1D)) begin
            stall = 1'b1;
            flushE = 1'b1;
        end
        
        if ((Rs2D == RdEX) && (brcondD != BR_X) && (Rs2D != 0) && (uses_rs2D)) begin
            stall = 1'b1;
            flushE = 1'b1;
        end
        
        // Stall logic for JALR forwarding
        if ((Rs1D == RdEX) && (is_jalrD) && (Rs1D != 0) && (uses_rs1D)) begin
            stall = 1'b1;
            flushE = 1'b1;
        end
            
        // Flush logic for taken branches and jumps
        if (RedirectF) begin
            flushFDRR = 1'b1;
            flushE = 1'b1;
        end
    end
    
endmodule
