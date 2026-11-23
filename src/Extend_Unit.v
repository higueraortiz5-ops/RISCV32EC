`timescale 1ns / 1ps
// Generador de inmediatos para las instrucciones comprimidas soportadas
//
//  ImmSrc | Formato               | Instrucciones
//  -------+-----------------------+-------------------------------
//   00    | CL/CS uimm[6:2]       | C.LW, C.SW   (cero-extendido, x4)
//   01    | CI imm[5:0] con signo | C.ADDI
//   10    | CI nzimm[17:12]       | C.LUI        (con signo, << 12)
//   11    | CI/CB shamt[5:0]      | C.SLLI, C.SRLI, C.SRAI (cero-ext.)
module Extend_Unit(
    input  wire [15:0] Inst,
    input  wire [1:0]  ImmSrc,
    output reg  [31:0] ImmExt
    );

    wire [5:0] ci = {Inst[12], Inst[6:2]};

    always @(*) begin
        case (ImmSrc)
            2'b00: ImmExt = {25'b0, Inst[5], Inst[12:10], Inst[6], 2'b00};
            2'b01: ImmExt = {{26{ci[5]}}, ci};
            2'b10: ImmExt = {{14{ci[5]}}, ci, 12'b0};
            2'b11: ImmExt = {26'b0, ci};
        endcase
    end

endmodule
