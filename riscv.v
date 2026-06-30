// =============================================================================
// Project   : 32-bit RISC-V RV32I Processor
// File      : riscv.v
// Author    : VLSI Internship Project
// Tool      : Genus Synthesis Solution 18.1
// Library   : slow_vddlv0_basicCells
// Description:
//   Single-cycle implementation of the RISC-V RV32I base integer ISA.
//   Supports R-type, I-type, S-type, B-type, U-type, and J-type instructions.
//   Synthesised using Cadence Genus with a 20 ns clock (50 MHz target).
// =============================================================================

`timescale 1ns/1ps

// ---------------------------------------------------------------------------
// ALU Operation Codes
// ---------------------------------------------------------------------------
`define ALU_ADD  4'b0000
`define ALU_SUB  4'b0001
`define ALU_AND  4'b0010
`define ALU_OR   4'b0011
`define ALU_XOR  4'b0100
`define ALU_SLL  4'b0101
`define ALU_SRL  4'b0110
`define ALU_SRA  4'b0111
`define ALU_SLT  4'b1000
`define ALU_SLTU 4'b1001

// ---------------------------------------------------------------------------
// RISC-V Opcodes (bits [6:0])
// ---------------------------------------------------------------------------
`define OP_R      7'b0110011   // R-type
`define OP_I_ALU  7'b0010011   // I-type ALU
`define OP_LOAD   7'b0000011   // Load
`define OP_STORE  7'b0100011   // Store
`define OP_BRANCH 7'b1100011   // Branch
`define OP_JAL    7'b1101111   // JAL
`define OP_JALR   7'b1100111   // JALR
`define OP_LUI    7'b0110111   // LUI
`define OP_AUIPC  7'b0010111   // AUIPC

// ===========================================================================
// Top-Level RISC-V Module
// ===========================================================================
module riscv (
    input  wire        clk,
    input  wire        rst_n
);

    // -----------------------------------------------------------------------
    // Internal wires / registers
    // -----------------------------------------------------------------------
    // Program Counter
    reg  [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] pc_plus4;

    // Instruction Memory interface
    wire [31:0] instr;

    // Instruction fields
    wire [6:0]  opcode  = instr[6:0];
    wire [4:0]  rd      = instr[11:7];
    wire [2:0]  funct3  = instr[14:12];
    wire [4:0]  rs1     = instr[19:15];
    wire [4:0]  rs2     = instr[24:20];
    wire [6:0]  funct7  = instr[31:25];

    // Immediate generation
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    // Register file
    reg  [31:0] regfile [0:31];
    wire [31:0] rs1_data, rs2_data;
    wire        reg_write;
    wire [31:0] rd_data;

    // ALU
    wire [3:0]  alu_op;
    wire        alu_src;
    wire [31:0] alu_a, alu_b, alu_result;
    wire        alu_zero;

    // Data memory
    wire        mem_read, mem_write;
    wire [31:0] mem_rdata;
    wire [1:0]  mem_size;     // 00=byte, 01=half, 10=word
    wire        mem_signed;

    // Control
    wire        branch, jump_jal, jump_jalr;
    wire        pc_src;
    wire [31:0] branch_target;
    wire [31:0] jal_target;
    wire [31:0] jalr_target;

    // Write-back mux select
    wire [1:0]  wb_sel;  // 00=ALU, 01=MEM, 10=PC+4

    // -----------------------------------------------------------------------
    // Program Counter
    // -----------------------------------------------------------------------
    assign pc_plus4    = pc + 32'd4;
    assign branch_target = pc + imm_b;
    assign jal_target    = pc + imm_j;
    assign jalr_target   = (rs1_data + imm_i) & ~32'b1;

    assign pc_src = (branch & alu_zero) | jump_jal | jump_jalr;

    assign pc_next = jump_jalr  ? jalr_target  :
                     jump_jal   ? jal_target   :
                     (branch & alu_zero) ? branch_target :
                     pc_plus4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;
        else
            pc <= pc_next;
    end

    // -----------------------------------------------------------------------
    // Instruction Memory (256 × 32-bit = 1 KiB, synchronous read)
    // -----------------------------------------------------------------------
    reg [31:0] imem [0:255];

    assign instr = imem[pc[9:2]];   // word-addressed

    // -----------------------------------------------------------------------
    // Immediate Decode
    // -----------------------------------------------------------------------
    assign imm_i = {{20{instr[31]}}, instr[31:20]};
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
    assign imm_u = {instr[31:12], 12'b0};
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};

    // -----------------------------------------------------------------------
    // Register File
    // -----------------------------------------------------------------------
    assign rs1_data = (rs1 == 5'b0) ? 32'b0 : regfile[rs1];
    assign rs2_data = (rs2 == 5'b0) ? 32'b0 : regfile[rs2];

    always @(posedge clk) begin
        if (reg_write && (rd != 5'b0))
            regfile[rd] <= rd_data;
    end

    // -----------------------------------------------------------------------
    // Control Unit
    // -----------------------------------------------------------------------
    control_unit cu (
        .opcode    (opcode),
        .funct3    (funct3),
        .funct7    (funct7),
        .reg_write (reg_write),
        .alu_src   (alu_src),
        .alu_op    (alu_op),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_size  (mem_size),
        .mem_signed(mem_signed),
        .branch    (branch),
        .jump_jal  (jump_jal),
        .jump_jalr (jump_jalr),
        .wb_sel    (wb_sel)
    );

    // -----------------------------------------------------------------------
    // ALU
    // -----------------------------------------------------------------------
    assign alu_a = (opcode == `OP_AUIPC) ? pc : rs1_data;
    assign alu_b = alu_src ? imm_i : rs2_data;

    alu alu_inst (
        .a      (alu_a),
        .b      ((opcode == `OP_LUI || opcode == `OP_AUIPC) ? imm_u : alu_b),
        .op     (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // -----------------------------------------------------------------------
    // Data Memory (256 × 32-bit = 1 KiB)
    // -----------------------------------------------------------------------
    data_memory dmem (
        .clk       (clk),
        .mem_write (mem_write),
        .mem_read  (mem_read),
        .mem_size  (mem_size),
        .mem_signed(mem_signed),
        .addr      (alu_result),
        .wdata     (rs2_data),
        .rdata     (mem_rdata)
    );

    // -----------------------------------------------------------------------
    // Write-Back Mux
    // -----------------------------------------------------------------------
    assign rd_data = (wb_sel == 2'b01) ? mem_rdata  :
                     (wb_sel == 2'b10) ? pc_plus4   :
                     alu_result;

endmodule


// ===========================================================================
// Control Unit
// ===========================================================================
module control_unit (
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        alu_src,
    output reg  [3:0] alu_op,
    output reg        mem_read,
    output reg        mem_write,
    output reg  [1:0] mem_size,
    output reg        mem_signed,
    output reg        branch,
    output reg        jump_jal,
    output reg        jump_jalr,
    output reg  [1:0] wb_sel      // 00=ALU, 01=MEM, 10=PC+4
);

    always @(*) begin
        // Defaults
        reg_write  = 1'b0;
        alu_src    = 1'b0;
        alu_op     = `ALU_ADD;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_size   = 2'b10;
        mem_signed = 1'b1;
        branch     = 1'b0;
        jump_jal   = 1'b0;
        jump_jalr  = 1'b0;
        wb_sel     = 2'b00;

        case (opcode)
            // R-type
            `OP_R: begin
                reg_write = 1'b1;
                alu_src   = 1'b0;
                wb_sel    = 2'b00;
                case ({funct7[5], funct3})
                    4'b0000: alu_op = `ALU_ADD;
                    4'b1000: alu_op = `ALU_SUB;
                    4'b0001: alu_op = `ALU_SLL;
                    4'b0010: alu_op = `ALU_SLT;
                    4'b0011: alu_op = `ALU_SLTU;
                    4'b0100: alu_op = `ALU_XOR;
                    4'b0101: alu_op = `ALU_SRL;
                    4'b1101: alu_op = `ALU_SRA;
                    4'b0110: alu_op = `ALU_OR;
                    4'b0111: alu_op = `ALU_AND;
                    default: alu_op = `ALU_ADD;
                endcase
            end

            // I-type ALU
            `OP_I_ALU: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                wb_sel    = 2'b00;
                case (funct3)
                    3'b000: alu_op = `ALU_ADD;
                    3'b010: alu_op = `ALU_SLT;
                    3'b011: alu_op = `ALU_SLTU;
                    3'b100: alu_op = `ALU_XOR;
                    3'b110: alu_op = `ALU_OR;
                    3'b111: alu_op = `ALU_AND;
                    3'b001: alu_op = `ALU_SLL;
                    3'b101: alu_op = funct7[5] ? `ALU_SRA : `ALU_SRL;
                    default: alu_op = `ALU_ADD;
                endcase
            end

            // Load
            `OP_LOAD: begin
                reg_write  = 1'b1;
                alu_src    = 1'b1;
                mem_read   = 1'b1;
                wb_sel     = 2'b01;
                mem_size   = funct3[1:0];
                mem_signed = ~funct3[2];
                alu_op     = `ALU_ADD;
            end

            // Store
            `OP_STORE: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                mem_size  = funct3[1:0];
                alu_op    = `ALU_ADD;
            end

            // Branch
            `OP_BRANCH: begin
                branch = 1'b1;
                case (funct3)
                    3'b000: alu_op = `ALU_SUB;   // BEQ  → zero
                    3'b001: alu_op = `ALU_SUB;   // BNE  → !zero
                    3'b100: alu_op = `ALU_SLT;   // BLT
                    3'b101: alu_op = `ALU_SLT;   // BGE
                    3'b110: alu_op = `ALU_SLTU;  // BLTU
                    3'b111: alu_op = `ALU_SLTU;  // BGEU
                    default: alu_op = `ALU_SUB;
                endcase
            end

            // JAL
            `OP_JAL: begin
                reg_write = 1'b1;
                jump_jal  = 1'b1;
                wb_sel    = 2'b10;
            end

            // JALR
            `OP_JALR: begin
                reg_write  = 1'b1;
                jump_jalr  = 1'b1;
                alu_src    = 1'b1;
                wb_sel     = 2'b10;
                alu_op     = `ALU_ADD;
            end

            // LUI
            `OP_LUI: begin
                reg_write = 1'b1;
                wb_sel    = 2'b00;
                alu_op    = `ALU_ADD;  // result = 0 + imm_u
            end

            // AUIPC
            `OP_AUIPC: begin
                reg_write = 1'b1;
                wb_sel    = 2'b00;
                alu_op    = `ALU_ADD;  // result = PC + imm_u
            end

            default: begin
                reg_write = 1'b0;
            end
        endcase
    end

endmodule


// ===========================================================================
// 32-bit ALU
// ===========================================================================
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [3:0]  op,
    output reg  [31:0] result,
    output wire        zero
);
    assign zero = (result == 32'b0);

    always @(*) begin
        case (op)
            `ALU_ADD : result = a + b;
            `ALU_SUB : result = a - b;
            `ALU_AND : result = a & b;
            `ALU_OR  : result = a | b;
            `ALU_XOR : result = a ^ b;
            `ALU_SLL : result = a << b[4:0];
            `ALU_SRL : result = a >> b[4:0];
            `ALU_SRA : result = $signed(a) >>> b[4:0];
            `ALU_SLT : result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            `ALU_SLTU: result = (a < b)                   ? 32'd1 : 32'd0;
            default  : result = 32'b0;
        endcase
    end
endmodule


// ===========================================================================
// Data Memory (byte-addressable, word-aligned access, 1 KiB)
// ===========================================================================
module data_memory (
    input  wire        clk,
    input  wire        mem_write,
    input  wire        mem_read,
    input  wire [1:0]  mem_size,    // 00=byte, 01=half-word, 10=word
    input  wire        mem_signed,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata
);
    reg [7:0] mem [0:1023];

    wire [9:0] base = addr[9:0];

    // Write
    always @(posedge clk) begin
        if (mem_write) begin
            case (mem_size)
                2'b00: begin
                    mem[base] <= wdata[7:0];
                end
                2'b01: begin
                    mem[base]   <= wdata[7:0];
                    mem[base+1] <= wdata[15:8];
                end
                2'b10: begin
                    mem[base]   <= wdata[7:0];
                    mem[base+1] <= wdata[15:8];
                    mem[base+2] <= wdata[23:16];
                    mem[base+3] <= wdata[31:24];
                end
                default: mem[base] <= wdata[7:0];
            endcase
        end
    end

    // Read (combinational)
    always @(*) begin
        if (mem_read) begin
            case (mem_size)
                2'b00: rdata = mem_signed ?
                               {{24{mem[base][7]}},   mem[base]}                          :
                               {24'b0,                mem[base]};
                2'b01: rdata = mem_signed ?
                               {{16{mem[base+1][7]}}, mem[base+1], mem[base]}             :
                               {16'b0,                mem[base+1], mem[base]};
                2'b10: rdata = {mem[base+3], mem[base+2], mem[base+1], mem[base]};
                default: rdata = 32'b0;
            endcase
        end else begin
            rdata = 32'b0;
        end
    end
endmodule
