`timescale 1ns / 1ps
// Banco de registros RV32E: x0..x15, x0 cableado a cero.
// Igual que en tu diseno, la direccion de escritura es A1 (en RVC rd = rs1
// en casi todas las instrucciones; para C.LW la Control Unit cambia A1 a rd'
// en el ciclo de write-back).
//
// Cambios respecto a la version original:
//  - Se quito el bloque "initial" (no es sintetizable en ASIC).
//  - x0 no se almacena: solo 15 registros fisicos (ahorra 32 flip-flops).
//  - Comparaciones con literales de 4 bits (antes 4'b00000).
module Register_File(
    input  wire        CLK,
    input  wire        WE,
    input  wire [3:0]  A1,      // rs1 / rd
    input  wire [3:0]  A2,      // rs2
    input  wire [31:0] WD3,     // dato a escribir
    output wire [31:0] RD1,
    output wire [31:0] RD2
    );

    reg [31:0] regs [1:15];

    always @(posedge CLK) begin
        if (WE && (A1 != 4'd0))
            regs[A1] <= WD3;    // nunca se escribe en x0
    end

    assign RD1 = (A1 == 4'd0) ? 32'b0 : regs[A1];
    assign RD2 = (A2 == 4'd0) ? 32'b0 : regs[A2];

endmodule
