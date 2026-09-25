/*
    Package: Types package
    Description: Package that contains enums and various control signals for ease of implementation between pipeline registers
*/
package types_pkg;

    // Defines immediate type
    typedef enum logic [2:0]{
        IMM_X, IMM_I, IMM_S, IMM_B, IMM_U, IMM_J
    } imm_e;
    
    // Defines result source
    typedef enum logic [2:0]{
        RES_X, RES_ALU, RES_PC4, RES_IMM, RES_PCT      // PCT for AUIPC as PCT comes from PC+imm adder, not ALU
    } result_e;
    
    // Defines ALUOp
    typedef enum logic [1:0]{
        ALUOP_ADD, ALUOP_SUB, ALUOP_FUNC
    } aluop_e;
    
    // Defines branch types
    typedef enum logic [2:0]{
        BR_X, BR_EQ, BR_NE, BR_LT, BR_GE, BR_LTU, BR_GEU
    }brcond_e;
    
    // Defines operand A source
    typedef enum logic {
        SRCA_RS1, SRCA_PC
    } srcA_e;
    
    // Defines operand B source
    typedef enum logic {
        SRCB_RS2, SRCB_IMM
    } srcB_e;
    
    // Defines load/store size
    typedef enum logic [1:0]{
        LDST_X, LDST_B, LDST_H, LDST_W
    } ldst_e;
    
    
    // Packed struct that contains signal bundle for decode stage outputs to go into ID-RR pipeline register
    typedef struct packed {

        // High level controls
        logic is_jump;
        logic is_jalr;
        logic mem_read;
        logic mem_write;
        logic writes_rd;
        logic uses_rs1;
        logic uses_rs2;
        
        // Load/store controls
        logic ldst_unsigned;

        // Branch type
        brcond_e brcond;
        
        // Load/store size
        ldst_e ldst_size;
        
        // Operand selection
        srcA_e srcA;
        srcB_e srcB;
        
        // Result selection
        result_e result_sel;
    } i1_ctrl_t;

    
    // Packed struct that contains signal bundle for decode stage outputs to go into ID-RR pipeline register
    typedef struct packed {
        // High level controls
        logic writes_rd;
        logic uses_rs1;
        logic uses_rs2;
     
        // Operand selection
        srcA_e srcA;
        srcB_e srcB;
        
        // Result selection
        result_e result_sel;
    } i2_ctrl_t;
endpackage
