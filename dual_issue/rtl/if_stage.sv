/* 
    Pipeline stage name: Instruction Fetch
    Description: Fetches next instructions from instruction memory
                 Contains instruction decision unit to assess whether issue 2 will be enabled
                 Contains instruction memory
*/
module if_stage(input logic         clk, reset, enable,
                input logic         RedirectF,      // Indicates taken branch
                input logic [31:0]  PCTargetF,      // Target PC from branch and jump instructions
                output logic        I2_valid,       // Insert bubble into issue 2 IF ID pipeline reg if issue 2 not valid
                output logic [31:0] PCF, PCPlus4F,  // PC and PC+4 for jump instruction return address
                output logic [31:0] I1_InstrF, I2_InstrF        // Instruction data for both issues
                );

    // Internal signals
    logic [31:0] PCPlus8F;
    logic [31:0] PCNextF;       // Output signal for multiplexer between PCPlus4 and PCTargetF
    logic [31:0] PCOffset;      // Determine whether PC offset is 4 or 8
    logic [63:0] IDU_Instr;
    
    // Program counter logic
    assign PCPlus4F = PCF + 32'd4;  // PC plus 4 adder
    assign PCPlus8F = PCF + 32'd8;  // PC plus 8 adder
    assign PCOffset = I2_valid ? PCPlus8F: PCPlus4F;
    assign PCNextF = RedirectF ? PCTargetF : PCOffset ; // Chooses between PC+4 and redirected PC from branches and jumps

    
    // PC register holds value of current PC during fetch stage
    flopenr PCreg(.clk(clk), .reset(reset), .enable(enable), .d(PCNextF), .q(PCF));
    
    //  Instantiate instruction memory module
    imem imem(.PC(PCF), .IDU_Instr(IDU_Instr));
    
    // Instantiate issue decision unit
    idu idu(.IDU_Instr(IDU_Instr), .I2_valid(I2_valid), .I1_InstrF(I1_InstrF), .I2_InstrF(I2_InstrF));   
                
endmodule

/* 
    Module name: Flip-flop with enable and reset signals
    Description: Used for registers within fetch stage, mainly to hold instructions and PC data
*/
module flopenr (input logic             clk, reset, enable, 
                input logic [31:0]      d,
                output logic [31:0]     q
                );
    
    // Turns to 0 on reset, otherwise update value from instruction memory
    always_ff @(posedge clk, posedge reset)
        if (reset) q <= 0;
        else if (enable) q <= d;              
endmodule

/*
    Module name: Instruction memory
    Description: Block of ROM that holds program instructions to be fetched by fetch stage
*/
module imem(input logic [31:0]      PC,
            output logic [63:0]     IDU_Instr
            );
    logic [31:0] mem[127:0]; // Generate memory block (currently 128 bytes)
    
    // Read instruction memory DAT file from directory
    initial
        $readmemh("imem.mem", mem);
    
    assign IDU_Instr = {mem[PC[31:2] + 1], mem[PC[31:2]]}; // Word-aligned fetches from memory block
endmodule

/*
    Module name: Instruction decision unit
    Description: Assesses whether Issue 2 can be enabled, control next PC logic accordingly
*/
module idu(input logic [63:0]       IDU_Instr,
           output logic             I2_valid,
           output logic [31:0]      I1_InstrF, I2_InstrF
           );
           
    // Assign instruction to issue paths from 64-bit memory fetch
    assign I1_InstrF = IDU_Instr[31:0];
    assign I2_InstrF = IDU_Instr[63:32];
    
    // Partially decode instructions to obtain source and destination registers
    logic [4:0] I1_Rd, I2_Rd, I2_Rs1, I2_Rs2;       // Obtain rd for issue 1 and rs for issue 2 to avoid same-cycle RAW
    logic [6:0] I1_Opcode, I2_Opcode;               // Obtain opcodes to disable issue 2 for unallowed instructions
    
    // Register used flags
    //logic I1_uses_rs1, I1_uses_rs2;
    logic I1_writes_rd;   // Register usage for issue 1
    logic I2_uses_rs1, I2_uses_rs2, I2_writes_rd;   // Register usage for issue 2
    
    // Assign registers and opcode to relevant bits of the instruction
    assign I1_Rd        = I1_InstrF[11:7];
    assign I2_Rd        = I2_InstrF[11:7];
    assign I2_Rs1       = I2_InstrF[19:15];
    assign I2_Rs2       = I2_InstrF[24:20];
    assign I1_Opcode    = I1_InstrF[6:0];
    assign I2_Opcode    = I2_InstrF[6:0];
    
    // Combinational block that contains flags to indicate if instructions use relevant registers to prevent issue 2 blocking unnecessarily
    always_comb begin
        // Defaults
        //I1_uses_rs1   = 1'b0;
        //I1_uses_rs2   = 1'b0;
        I1_writes_rd    = 1'b0;
        I2_uses_rs1     = 1'b0;
        I2_uses_rs2     = 1'b0;
        I2_writes_rd    = 1'b0;
        
        // Check registers used for Issue 1
        case (I1_Opcode)
            7'b0110011: begin       // R-type instructions
                //I1_uses_rs1     = 1'b1;
                //I1_uses_rs2     = 1'b1;
                I1_writes_rd    = 1'b1;
            end
            
            7'b0010011,             // I-type instructions
            7'b0000011,             
            7'b1100111: begin       
                //I1_uses_rs1     = 1'b1;
                I1_writes_rd    = 1'b1;
            end
            
            /*7'b0100011,             // S/B-type instructions
            7'b1100011: begin
                I1_uses_rs1     = 1'b1;
                I1_uses_rs2     = 1'b1;
            end*/
            
            7'b1101111,             // U/J-type instructions
            7'b0110111,
            7'b0010111: begin
                I1_writes_rd    = 1'b1;
            end
            
            default: begin          // Default
                //I1_uses_rs1     = 1'b0;
                //I1_uses_rs2     = 1'b0;
                I1_writes_rd    = 1'b0;
            end
        endcase
                
        // Check registers used for Issue 2
        case (I2_Opcode)
            7'b0110011: begin       // R-type instructions
                I2_uses_rs1     = 1'b1;
                I2_uses_rs2     = 1'b1;
                I2_writes_rd    = 1'b1;
            end
            
            7'b0010011,             // I-type instructions
            7'b0000011,             
            7'b1100111: begin       
                I2_uses_rs1     = 1'b1;
                I2_writes_rd    = 1'b1;
            end
            
            7'b0100011,             // S/B-type instructions
            7'b1100011: begin
                I2_uses_rs1     = 1'b1;
                I2_uses_rs2     = 1'b1;
            end
            
            7'b1101111,             // U/J-type instructions
            7'b0110111,
            7'b0010111: begin
                I2_writes_rd    = 1'b1;
            end
            
            default: begin          // Default
                I2_uses_rs1     = 1'b0;
                I2_uses_rs2     = 1'b0;
                I2_writes_rd    = 1'b0;
            end
        endcase
    end
    
    // Combinational block that contains if statements to determine whether issue 2 will be valid and if issue swap is possible
    always_comb begin
        if (I1_Opcode inside {7'b1101111, 7'b1100111}) // Issue 2 is not valid when issue 1 is a non-conditional branch (JAL or JALR)
            I2_valid = 1'b0;    
        else if ((I1_writes_rd) && (I1_Rd != 0) && ((I2_uses_rs1 && (I1_Rd == I2_Rs1)) || (I2_uses_rs2 && (I1_Rd == I2_Rs2)))) // Issue 2 is not valid when there is a same-cycle RAW
            I2_valid = 1'b0;    
        else if ((I1_Rd == I2_Rd) && (I1_Rd != 0) && (I2_Rd != 0) && (I1_writes_rd) && (I2_writes_rd)) // Issue 2 is not valid when there is a same-cycle WAW hazard
            I2_valid = 1'b0;             
        else if (I2_Opcode inside {7'b0100011, 7'b0000011, 7'b1100011, 7'b1101111, 7'b1100111}) // Issue 2 is not valid is the instruction is a load, store, branch, or jump
            I2_valid = 1'b0;    
        else 
            I2_valid = 1'b1;   // Issue 2 will be valid in all other cases
    end
endmodule
