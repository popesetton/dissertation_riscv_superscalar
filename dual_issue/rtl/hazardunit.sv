import types_pkg::*;

/*
    Module name: Hazard unit
    Description: Handles all relevant data and control hazards present in the core
*/
module hazardunit(input logic [4:0] I1_Rs1EX, I1_Rs2EX, I1_RdWB, I2_Rs1EX, I2_Rs2EX, I2_RdWB,       // For forwarding logic
                  input logic [4:0] I1_Rs1D, I1_Rs2D, I1_RdEX, I2_Rs1D, I2_Rs2D, I2_RdEX,       // For load-use hazards
                  input logic I1_writes_rdWB, I2_writes_rdWB, I1_writes_rdEX, mem_read, RedirectF, is_jalrD,
                  input logic I1_uses_rs1D, I1_uses_rs2D, I1_uses_rs1EX, I1_uses_rs2EX,
                  input logic I2_uses_rs1D, I2_uses_rs2D, I2_uses_rs1EX, I2_uses_rs2EX,
                  input brcond_e brcondD,
                  output logic stall, flushFDRR, flushE,
                  output logic [1:0] I1_fwdsrcAsel, I1_fwdsrcBsel, I2_fwdsrcAsel, I2_fwdsrcBsel,
                  output logic [1:0] I1_fwdsrcAselD, I1_fwdsrcBselD, I2_fwdsrcAselD, I2_fwdsrcBselD);
                  
    always_comb begin
        // Defaults
        I1_fwdsrcAsel = 2'b00;
        I1_fwdsrcBsel = 2'b00; 
        I2_fwdsrcAsel = 2'b00;
        I2_fwdsrcBsel = 2'b00;
        I1_fwdsrcAselD = 2'b00;
        I1_fwdsrcBselD = 2'b00; 
        I2_fwdsrcAselD = 2'b00;
        I2_fwdsrcBselD = 2'b00;
        stall = 1'b0;
        flushFDRR = 1'b0;
        flushE = 1'b0;
        
        /* 
            Forwarding logic fom WB to EX stages for RAW hazards 
            8 possible cases: 2 destination registers * 4 source registers
        */
        // From Issue 1 writeback stage
        if ((I1_Rs1EX == I1_RdWB) && (I1_writes_rdWB) && (I1_Rs1EX != 0) && (I1_uses_rs1EX)) begin       // To issue 1 rs1
            I1_fwdsrcAsel = 2'b01;
        end
        
        if ((I1_Rs2EX == I1_RdWB) && (I1_writes_rdWB) && (I1_Rs2EX != 0) && (I1_uses_rs2EX)) begin       // To issue 1 rs2
            I1_fwdsrcBsel = 2'b01;
        end
        
        if ((I2_Rs1EX == I1_RdWB) && (I1_writes_rdWB) && (I2_Rs1EX != 0) && (I2_uses_rs1EX)) begin      // To issue 2 rs1
            I2_fwdsrcAsel = 2'b01;
        end

        if ((I2_Rs2EX == I1_RdWB) && (I1_writes_rdWB) && (I2_Rs2EX != 0) && (I2_uses_rs2EX)) begin      // To issue 2 rs2
            I2_fwdsrcBsel = 2'b01;
        end

        // From Issue 2 writeback stage
        if ((I1_Rs1EX == I2_RdWB) && (I2_writes_rdWB) && (I1_Rs1EX != 0) && (I1_uses_rs1EX)) begin       // To issue 1 rs1
            I1_fwdsrcAsel = 2'b10;
        end
        
        if ((I1_Rs2EX == I2_RdWB) && (I2_writes_rdWB) && (I1_Rs2EX != 0) && (I1_uses_rs2EX)) begin       // To issue 1 rs2
            I1_fwdsrcBsel = 2'b10;
        end
        
        if ((I2_Rs1EX == I2_RdWB) && (I2_writes_rdWB) && (I2_Rs1EX != 0) && (I2_uses_rs1EX)) begin      // To issue 2 rs1
            I2_fwdsrcAsel = 2'b10;
        end

        if ((I2_Rs2EX == I2_RdWB) && (I2_writes_rdWB) && (I2_Rs2EX != 0) && (I2_uses_rs2EX)) begin      // To issue 2 rs2
            I2_fwdsrcBsel = 2'b10;
        end

        /* 
            Forwarding logic from WB to RR stage for RAW data hazards 
            8 possible cases: 2 destination registers * 4 source registers
        */
        // From Issue 1 writeback stage
        if ((I1_Rs1D == I1_RdWB) && (I1_writes_rdWB) && (I1_Rs1D != 0) && (I1_uses_rs1D)) begin       // To issue 1 rs1
            I1_fwdsrcAselD = 2'b01;
        end
        
        if ((I1_Rs2D == I1_RdWB) && (I1_writes_rdWB) && (I1_Rs2D != 0) && (I1_uses_rs2D)) begin       // To issue 1 rs2
            I1_fwdsrcBselD = 2'b01;
        end
        
        if ((I2_Rs1D == I1_RdWB) && (I1_writes_rdWB) && (I2_Rs1D != 0) && (I2_uses_rs1D)) begin      // To issue 2 rs1
            I2_fwdsrcAselD = 2'b01;
        end

        if ((I2_Rs2D == I1_RdWB) && (I1_writes_rdWB) && (I2_Rs2D != 0) && (I2_uses_rs2D)) begin      // To issue 2 rs2
            I2_fwdsrcBselD = 2'b01;
        end

        // From Issue 2 writeback stage
        if ((I1_Rs1D == I2_RdWB) && (I2_writes_rdWB) && (I1_Rs1D != 0) && (I1_uses_rs1D)) begin       // To issue 1 rs1
            I1_fwdsrcAselD = 2'b10;
        end
        
        if ((I1_Rs2D == I2_RdWB) && (I2_writes_rdWB) && (I1_Rs2D != 0) && (I1_uses_rs2D)) begin       // To issue 1 rs2
            I1_fwdsrcBselD = 2'b10;
        end
        
        if ((I2_Rs1D == I2_RdWB) && (I2_writes_rdWB) && (I2_Rs1D != 0) && (I2_uses_rs1D)) begin      // To issue 2 rs1
            I2_fwdsrcAselD = 2'b10;
        end

        if ((I2_Rs2D == I2_RdWB) && (I2_writes_rdWB) && (I2_Rs2D != 0) && (I2_uses_rs2D)) begin      // To issue 2 rs2
            I2_fwdsrcBselD = 2'b10;
        end
        
        /*
            Stall logic for load-use hazards
            Only 4 possible cases since load instructions cannot go through issue 2
            Stalls both issues in order to keep processor in-order and fetches aligned
        */
        if ((I1_Rs1D == I1_RdEX) && (I1_writes_rdEX) && (I1_Rs1D != 0) && (mem_read) && (I1_uses_rs1D)) begin      // Check issue 1 rs1
            stall = 1'b1;
            flushE = 1'b1;
        end

        if ((I1_Rs2D == I1_RdEX) && (I1_writes_rdEX) && (I1_Rs2D != 0) && (mem_read) && (I1_uses_rs2D)) begin      // Check issue 1 rs2
            stall = 1'b1;
            flushE = 1'b1;
        end

        if ((I2_Rs1D == I1_RdEX) && (I1_writes_rdEX) && (I2_Rs1D != 0) && (mem_read) && (I2_uses_rs1D)) begin      // Check issue 2 rs1
            stall = 1'b1;
            flushE = 1'b1;
        end

        if ((I2_Rs2D == I1_RdEX) && (I1_writes_rdEX) && (I2_Rs2D != 0) && (mem_read) && (I2_uses_rs2D)) begin      // Check issue 2 rs2
            stall = 1'b1;
            flushE = 1'b1;
        end

        /*
            Stall logic for JALR and conditional branches
            Only for issue 1, as issue 2 does not handle PC changing instructions
        */
        if (((I1_Rs1D == I1_RdEX) || (I1_Rs1D == I2_RdEX)) && (brcondD != BR_X) && (I1_Rs1D != 0) && (I1_uses_rs1D)) begin    // Branch rs1 check
            stall = 1'b1;
            flushE = 1'b1;
        end
       
        if (((I1_Rs2D == I1_RdEX) || (I1_Rs2D == I2_RdEX)) && (brcondD != BR_X) && (I1_Rs2D != 0) && (I1_uses_rs2D)) begin    // Branch rs2 check
            stall = 1'b1;
            flushE = 1'b1;
        end
        
        if (((I1_Rs1D == I1_RdEX) || (I1_Rs1D == I2_RdEX)) && (is_jalrD) && (I1_Rs1D != 0) && (I1_uses_rs1D)) begin           // JALR check
            stall = 1'b1;
            flushE = 1'b1;
        end   
        
        /*
            Flush logic for taken branches and jumps
            Flushes both issues 
        */
        if (RedirectF) begin
            flushFDRR = 1'b1;
            flushE = 1'b1;
        end
    end
    
endmodule
