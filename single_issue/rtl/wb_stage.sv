import types_pkg::*;

/*
    Pipeline stage name: Writeback
    Description: Selects from result select enum to write back correct values to register file. Contains load/store unit.
*/
module wb_stage(input logic [31:0] ALUResultWB, ImmExtWB, PCPlus4WB, PCTargetWB,
                input result_e result_sel,
                input logic clk, mem_read, mem_write, ldst_unsigned,
                input ldst_e ldst_size,
                input logic [31:0] store_data, // rs2
                output logic [31:0] ResultWB,
                output logic [31:0] MemResultWB
                );
    //logic [31:0] load_dataWB;
    
    
    always_comb begin
        case (result_sel)
        RES_ALU: ResultWB = ALUResultWB;
        //RES_MEM: ResultWB = load_dataWB;
        RES_PC4: ResultWB = PCPlus4WB;
        RES_IMM: ResultWB = ImmExtWB;
        RES_PCT: ResultWB = PCTargetWB;
        default: ResultWB = 32'b0;
        endcase
    end

    // Instantiate load/store unit
    lsu lsu(.clk(clk), .mem_read(mem_read), .mem_write(mem_write), .ldst_unsigned(ldst_unsigned), .ldst_size(ldst_size), .addr(ALUResultWB), .store_data(store_data), .load_data(MemResultWB));

endmodule

/*
    Module name: Load/Store Unit
    Description: Contains the data memory and logic to handle different load and store sizes
*/
module lsu #(parameter int WORDS = 64)
            (input logic        mem_read, mem_write, ldst_unsigned, clk,
            input               ldst_e ldst_size,
            input logic [31:0]  addr, store_data,
            output logic [31:0] load_data
            );
    
    // Define memory space
    logic [31:0] mem[WORDS-1:0];            // Word-addressed memory
    
    // Check for alignment
    logic misaligned;
    logic [1:0] byte_off;
    logic [$clog2(WORDS)-1:0] word_idx;     // Parameter sized for smaller memory units, eases scalability
    
    assign byte_off = addr[1:0];            // Obtain last two bits of address to check for alignment
    assign word_idx = addr[31:2];           // Word-aligned addresses
    
    logic [31:0]    word;
    assign word = mem[word_idx];
    /*
    // Sequential reads, register for all control signals for load
    logic [31:0]    word_reg;
    logic [1:0]     byte_off_reg;
    ldst_e          ldst_size_reg;
    logic           ldst_unsigned_reg;
    
    always_ff @(posedge clk) begin
        if (mem_read && !misaligned) begin
            word_reg                <= mem[word_idx];
            byte_off_reg            <= byte_off;
            ldst_size_reg           <= ldst_size;
            ldst_unsigned_reg       <= ldst_unsigned;
        end
    end*/
       
    // Store formatting
    logic [3:0] be; // byte enable lanes for sized stores
    logic [31:0] wdata_aligned;
    logic store_we; // Only 0 if there is alignment issue
    
    // Alignment
    always_comb begin
        unique case (ldst_size)
            LDST_B: misaligned = 1'b0; // Always aligned
            LDST_H: misaligned = byte_off[0]; // Last bit of address must be 0 for alignment
            LDST_W: misaligned = |byte_off; // Final 2 bits of address must be 0 for alignment
            LDST_X: misaligned = 1'b0; // Default case for non load/store instructions
        endcase
    end
    
    // Combinational elements of load/store unit
    always_comb begin
        // Defaults
        be = 4'b0000;
        wdata_aligned = 32'b0;
        store_we = 1'b0;
        load_data = 32'b0;
        
        // Store path (not writing into memory combinationally)
        if (mem_write && !misaligned) begin // mem_write = 1 when instruction is store
            store_we = 1'b1;
            unique case (ldst_size)
                LDST_B: begin
                    be = 4'b0001 << byte_off; // Shift byte enable into correct position for SB
                    wdata_aligned = store_data[7:0] << (byte_off * 8);
                end
                
                LDST_H: begin
                    be = (byte_off[1]) ? 4'b1100 : 4'b0011;
                    wdata_aligned = (byte_off[1]) ? (store_data[15:0] << 16) : store_data[15:0];
                end
                
                LDST_W: begin
                    be = 4'b1111;
                    wdata_aligned = store_data;
                end
            endcase    
        end
    
        // Load path
        if (mem_read && !misaligned) begin // mem_read = 1 when instruction is load
            unique case (ldst_size)
                LDST_B: begin
                    logic [7:0] b;
                    b = (word >> (byte_off * 8));
                    load_data = ldst_unsigned ? {24'b0, b} : {{24{b[7]}}, b};
                end
                
                LDST_H: begin
                    logic [15:0] h;
                    h = (word >> (byte_off[1] * 16)); // Shift right if there is a 16-bit offset
                    load_data = ldst_unsigned ? {16'b0, h} : {{16{h[15]}}, h};
                end
                
                LDST_W: begin
                    load_data = word; // No need for shifting
                end
                
                default: load_data = 32'b0;
            endcase
        end
    end
   
    // Sequential masked write for sized stores
    always_ff @(posedge clk) begin
        if (store_we) begin
            if (be[0]) mem[word_idx][7:0] <= wdata_aligned[7:0];
            if (be[1]) mem[word_idx][15:8] <= wdata_aligned[15:8];
            if (be[2]) mem[word_idx][23:16] <= wdata_aligned[23:16];
            if (be[3]) mem[word_idx][31:24] <= wdata_aligned[31:24];
        end
    end
endmodule