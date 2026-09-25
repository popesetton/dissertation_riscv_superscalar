/*
    Pipeline stage name: Instruction Fetch
    Description: Fetches next instruction from instruction memory
                 Handles program counter logic for PC+4 and branch/jump instructions
*/
module if_stage(input logic clk, reset, enable,
                input logic RedirectF,                  // Signal to decide whether branch is taken
                input logic [31:0] PCTargetF,           // Redirect target PC
                output logic [31:0] PCF, PCPlus4F,      // Carry out PC and PC+4
                output logic [31:0] InstrF              // Carry out instruction data
                );

    // Internal signals
    logic [31:0] PCNextF;       // Output signal for multiplexer between PCPlus4 and PCTargetF

    
    // Program counter logic
    assign PCPlus4F = PCF + 32'd4;                          // PC plus 4 adder
    assign PCNextF = RedirectF ? PCTargetF : PCPlus4F;      // Chooses between PC+4 and redirected PC from branches and jumps

    
    // PC register holds value of current PC during fetch stage   
    flopenr PCReg(.clk(clk), .reset(reset), .enable(enable) , .d(PCNextF), .q(PCF));
    
    //  Instantiate instruction memory module
    imem imem(.PC(PCF), .InstrF(InstrF));
endmodule

/* 
    Module name: Flip-flop with enable and reset signals
    Description: Used to hold current value of PC
*/
module flopenr (input logic clk, reset, enable, 
                input logic [31:0] d,
                output logic [31:0] q
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
module imem(input logic [31:0] PC,
            output logic [31:0] InstrF
            );
    (* rom_style = "distributed" *) logic [31:0] mem [0:127]; // Generate memory block (currently 128 bytes)
    
    // Obtain instruction memory data for MEM memory initialisation file 
    initial begin
        $readmemh("imem.mem", mem);
    end
   
    assign InstrF = mem[PC[31:2]];
endmodule
