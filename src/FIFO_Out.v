`timescale 1ns / 1ps
// "FIFO" de salida: envia una palabra de 32 bits en 8 nibbles (LSB primero).
// No usa flip-flops: mientras dura el envio la instruccion esta congelada,
// asi que ALUResult y RD2 son estables y basta un mux 8:1 indexado por el
// contador de nibbles de la Control Unit.
module FIFO_Out(
    input  wire        en,      // FIFO_out_EN / Send
    input  wire [2:0]  idx,     // nibble que se esta enviando
    input  wire [31:0] word,
    output wire [3:0]  nibble
    );

    assign nibble = en ? word[idx*4 +: 4] : 4'b0;

endmodule
