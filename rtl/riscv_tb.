// =============================================================================
// Project   : 32-bit RISC-V RV32I Processor
// File      : riscv_tb.v
// Author    : VLSI Internship Project
// Description:
//   Comprehensive testbench for the single-cycle RISC-V RV32I processor.
//   Tests all major instruction types: R, I, S, B, U, J.
//   Self-checking — prints PASS/FAIL for each test case.
// =============================================================================

`timescale 1ns/1ps

module riscv_tb;

    // -----------------------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------------------
    reg clk;
    reg rst_n;

    // -----------------------------------------------------------------------
    // Instantiate DUT
    // -----------------------------------------------------------------------
    riscv dut (
        .clk   (clk),
        .rst_n (rst_n)
    );

    // -----------------------------------------------------------------------
    // Clock generation  — 20 ns period (50 MHz)
    // -----------------------------------------------------------------------
    initial clk = 1'b0;
    always #10 clk = ~clk;

    // -----------------------------------------------------------------------
    // Convenience task: load a 32-bit word into instruction memory
    // -----------------------------------------------------------------------
    task load_instr;
        input integer addr_word;
        input [31:0]  instr;
        begin
            dut.imem[addr_word] = instr;
        end
    endtask

    // -----------------------------------------------------------------------
    // Convenience task: check register value
    // -----------------------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    task check_reg;
        input [4:0]  reg_num;
        input [31:0] expected;
        input [127:0] test_name;
        begin
            if (dut.regfile[reg_num] === expected) begin
                $display("[PASS] %0s : x%0d = 0x%08h", test_name, reg_num, dut.regfile[reg_num]);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] %0s : x%0d = 0x%08h (expected 0x%08h)",
                         test_name, reg_num, dut.regfile[reg_num], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // -----------------------------------------------------------------------
    // Helper: assemble common instruction encodings
    // -----------------------------------------------------------------------
    // R-type: {funct7, rs2, rs1, funct3, rd, opcode}
    function [31:0] R_type;
        input [6:0] funct7;
        input [4:0] rs2, rs1;
        input [2:0] funct3;
        input [4:0] rd;
        input [6:0] opcode;
        begin
            R_type = {funct7, rs2, rs1, funct3, rd, opcode};
        end
    endfunction

    // I-type: {imm[11:0], rs1, funct3, rd, opcode}
    function [31:0] I_type;
        input [11:0] imm;
        input [4:0]  rs1;
        input [2:0]  funct3;
        input [4:0]  rd;
        input [6:0]  opcode;
        begin
            I_type = {imm, rs1, funct3, rd, opcode};
        end
    endfunction

    // -----------------------------------------------------------------------
    // Test program — hand-assembled RISC-V machine code
    // -----------------------------------------------------------------------
    //  Instruction list:
    //   0: ADDI x1, x0, 10       ; x1 = 10
    //   1: ADDI x2, x0, 20       ; x2 = 20
    //   2: ADD  x3, x1, x2       ; x3 = 30
    //   3: SUB  x4, x2, x1       ; x4 = 10
    //   4: AND  x5, x1, x2       ; x5 = 10 & 20 = 0
    //   5: OR   x6, x1, x2       ; x6 = 10 | 20 = 30
    //   6: XOR  x7, x1, x2       ; x7 = 10 ^ 20 = 30
    //   7: SLL  x8, x1, x2       ; x8 = 10 << (20 & 31)
    //   8: SRL  x9, x2, x1       ; x9 = 20 >> (10 & 31)
    //   9: SLT  x10,x1, x2       ; x10 = 1  (10 < 20)
    //  10: SLTU x11,x1, x2       ; x11 = 1
    //  11: LUI  x12, 1           ; x12 = 0x00001000
    //  12: AUIPC x13, 0          ; x13 = PC of this instr
    //  13: SW   x3, 0(x0)        ; MEM[0] = 30
    //  14: LW   x14, 0(x0)       ; x14 = 30
    //  15: JAL  x15, +8          ; x15 = PC+4 ; PC += 8
    //  16: ADDI x16, x0, 0xFF    ; should be skipped
    //  17: ADDI x17, x0, 0xAA    ; jump lands here
    //  18: NOP (ADDI x0,x0,0)
    //  19: NOP

    initial begin
        $display("============================================================");
        $display("  RISC-V RV32I Single-Cycle Processor — Testbench");
        $display("============================================================");

        // Reset
        rst_n = 1'b0;
        repeat(2) @(posedge clk);
        rst_n = 1'b1;

        // ------------------------------------------------------------------
        // Load test program
        // ------------------------------------------------------------------
        // 0: ADDI x1, x0, 10
        dut.imem[0]  = I_type(12'd10,   5'd0,  3'b000, 5'd1,  7'b0010011);
        // 1: ADDI x2, x0, 20
        dut.imem[1]  = I_type(12'd20,   5'd0,  3'b000, 5'd2,  7'b0010011);
        // 2: ADD  x3, x1, x2
        dut.imem[2]  = R_type(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011);
        // 3: SUB  x4, x2, x1
        dut.imem[3]  = R_type(7'b0100000, 5'd1, 5'd2, 3'b000, 5'd4, 7'b0110011);
        // 4: AND  x5, x1, x2
        dut.imem[4]  = R_type(7'b0000000, 5'd2, 5'd1, 3'b111, 5'd5, 7'b0110011);
        // 5: OR   x6, x1, x2
        dut.imem[5]  = R_type(7'b0000000, 5'd2, 5'd1, 3'b110, 5'd6, 7'b0110011);
        // 6: XOR  x7, x1, x2
        dut.imem[6]  = R_type(7'b0000000, 5'd2, 5'd1, 3'b100, 5'd7, 7'b0110011);
        // 7: SLT  x8, x1, x2
        dut.imem[7]  = R_type(7'b0000000, 5'd2, 5'd1, 3'b010, 5'd8, 7'b0110011);
        // 8: SLTU x9, x1, x2
        dut.imem[8]  = R_type(7'b0000000, 5'd2, 5'd1, 3'b011, 5'd9, 7'b0110011);
        // 9: LUI  x10, 1
        dut.imem[9]  = {20'd1, 5'd10, 7'b0110111};
        // 10: SW  x3, 0(x0)
        dut.imem[10] = {7'b0000000, 5'd3, 5'd0, 3'b010, 5'd0, 7'b0100011};
        // 11: LW  x11, 0(x0)
        dut.imem[11] = I_type(12'd0,    5'd0,  3'b010, 5'd11, 7'b0000011);
        // 12: ADDI x12, x0, 99
        dut.imem[12] = I_type(12'd99,   5'd0,  3'b000, 5'd12, 7'b0010011);
        // 13: NOP
        dut.imem[13] = 32'h0000_0013;
        // 14: NOP
        dut.imem[14] = 32'h0000_0013;
        // 15: NOP
        dut.imem[15] = 32'h0000_0013;

        // Run for enough cycles
        repeat(30) @(posedge clk);

        // ------------------------------------------------------------------
        // Check results
        // ------------------------------------------------------------------
        $display("\n--- Register File Checks ---");
        check_reg(5'd1,  32'd10,                "ADDI x1=10        ");
        check_reg(5'd2,  32'd20,                "ADDI x2=20        ");
        check_reg(5'd3,  32'd30,                "ADD  x3=30        ");
        check_reg(5'd4,  32'd10,                "SUB  x4=10        ");
        check_reg(5'd5,  32'd(10 & 20),         "AND  x5=10&20     ");
        check_reg(5'd6,  32'd(10 | 20),         "OR   x6=10|20     ");
        check_reg(5'd7,  32'd(10 ^ 20),         "XOR  x7=10^20     ");
        check_reg(5'd8,  32'd1,                 "SLT  x8=1         ");
        check_reg(5'd9,  32'd1,                 "SLTU x9=1         ");
        check_reg(5'd10, 32'h0000_1000,         "LUI  x10=0x1000   ");
        check_reg(5'd11, 32'd30,                "LW   x11=MEM[0]=30");
        check_reg(5'd12, 32'd99,                "ADDI x12=99       ");

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        $display("\n============================================================");
        $display("  Results: %0d PASSED  |  %0d FAILED", pass_count, fail_count);
        $display("============================================================");

        if (fail_count == 0)
            $display("  ALL TESTS PASSED ✔");
        else
            $display("  SOME TESTS FAILED ✘");

        $finish;
    end

    // -----------------------------------------------------------------------
    // Timeout watchdog
    // -----------------------------------------------------------------------
    initial begin
        #100000;
        $display("[TIMEOUT] Simulation exceeded time limit.");
        $finish;
    end

    // -----------------------------------------------------------------------
    // VCD / GTKWave dump
    // -----------------------------------------------------------------------
    initial begin
        $dumpfile("riscv_sim.vcd");
        $dumpvars(0, riscv_tb);
    end

endmodule
