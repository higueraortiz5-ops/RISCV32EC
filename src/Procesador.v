`timescale 1ns / 1ps
// Camino de datos completo (sigue el esquematico):
//
//  Inst(4) -> FIFO -> Extend Register / Inst --mux--> a1, a2 -> Register File
//  Rd1 -> ALU.SrcA ; Rd2 / Extend Unit --Rd2_sel--> ALU.SrcB
//  ALU -> FIFO_Out (Dir) ; Rd2 -> FIFO_Out (Data, para SW)
//  Data(4) -> FIFO (LW) ; ALU / FIFO --Wd_sel--> w_data
module Procesador(
    input  wire       clk,
    input  wire       rst_n,

    // Memoria de instrucciones (IM)
    input  wire [3:0] inst_in,
    input  wire       halt,
    output wire       hold,

    // Memoria de datos (DM)
    input  wire [3:0] data_in,
    input  wire       recive,
    output wire       send,
    output wire       mem_write,
    output wire [3:0] dir_out,
    output wire [3:0] data_out
    );

    // ---------------- Senales internas ----------------
    wire [15:0] Inst;
    wire [31:0] mem_word;
    wire [31:0] RD1, RD2, ImmExt, SrcB, ALUResult, WD3;
    wire [3:0]  rs1p, rs2p;
    reg  [3:0]  A1;
    wire [3:0]  A2;

    wire        ResultSrc, SrcB_sel, A2_sel, WE;
    wire [1:0]  A1_sel, ImmSrc;
    wire [2:0]  ALUControl, nib_idx;
    wire        fifo_inst_en, fifo_data_en;

    // ---------------- FIFOs de entrada ----------------
    FIFO_In #(.WIDTH(16)) fifo_inst (
        .clk(clk), .en(fifo_inst_en), .nibble(inst_in), .word(Inst));

    FIFO_In #(.WIDTH(32)) fifo_data (
        .clk(clk), .en(fifo_data_en), .nibble(data_in), .word(mem_word));

    // ---------------- Unidad de control ----------------
    Control_Unit cu (
        .clk(clk), .rst_n(rst_n), .Inst(Inst), .halt(halt), .recive(recive),
        .ResultSrc(ResultSrc), .ALUControl(ALUControl), .SrcB_sel(SrcB_sel),
        .ImmSrc(ImmSrc), .A1_sel(A1_sel), .A2_sel(A2_sel), .WE(WE),
        .fifo_inst_en(fifo_inst_en), .fifo_data_en(fifo_data_en),
        .send(send), .mem_write(mem_write), .nib_idx(nib_idx), .hold(hold));

    // ---------------- Seleccion de registros ----------------
    Extend_Register ext_reg (.Inst(Inst[9:2]), .rs1(rs1p), .rs2(rs2p));

    always @(*) begin
        case (A1_sel)
            2'b00:   A1 = Inst[10:7];   // rd/rs1 completo (RV32E: Inst[11] = 0)
            2'b01:   A1 = rs1p;         // rs1' / rd'
            2'b10:   A1 = rs2p;         // rd' de C.LW (Inst[4:2])
            default: A1 = 4'd0;
        endcase
    end
    assign A2 = A2_sel ? rs2p : Inst[5:2];   // rs2' o rs2 completo (C.MV)

    // ---------------- Banco de registros ----------------
    Register_File rf (
        .CLK(clk), .WE(WE), .A1(A1), .A2(A2), .WD3(WD3), .RD1(RD1), .RD2(RD2));

    // ---------------- Inmediatos y ALU ----------------
    Extend_Unit ext (.Inst(Inst), .ImmSrc(ImmSrc), .ImmExt(ImmExt));

    assign SrcB = SrcB_sel ? ImmExt : RD2;           // Rd2_sel

    ALU alu (.SrcA(RD1), .SrcB(SrcB), .ALUControl(ALUControl), .ALUResult(ALUResult));

    assign WD3 = ResultSrc ? mem_word : ALUResult;   // Wd_sel

    // ---------------- FIFOs de salida ----------------
    FIFO_Out fifo_dir  (.en(send), .idx(nib_idx), .word(ALUResult), .nibble(dir_out));
    FIFO_Out fifo_dout (.en(send), .idx(nib_idx), .word(RD2),       .nibble(data_out));

endmodule
