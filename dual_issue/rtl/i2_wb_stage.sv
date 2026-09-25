import types_pkg::*;

/*
    Pipeline stage name: Writeback
    Description: Selects from result select enum to write back correct values to register file. Contains load/store unit.
*/
module i2_wb_stage(input logic [31:0] I2_ALUResultWB, I2_ImmExtWB,
                input result_e I2_result_sel,
                output logic [31:0] I2_ResultWB
                );
    logic [31:0] load_dataWB;
    
    
    always_comb begin
        case (I2_result_sel)
        RES_ALU: I2_ResultWB = I2_ALUResultWB;
        RES_IMM: I2_ResultWB = I2_ImmExtWB;
        default: I2_ResultWB = 32'b0;
        endcase
    end

endmodule
