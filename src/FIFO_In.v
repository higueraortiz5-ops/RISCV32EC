`timescale 1ns / 1ps
// "FIFO" de entrada: registro de desplazamiento que arma una palabra de
// WIDTH bits a partir de nibbles de 4 bits. Se recibe primero el nibble
// menos significativo.
//   WIDTH = 16 -> instruccion (4 nibbles, desde IM)
//   WIDTH = 32 -> dato de C.LW (8 nibbles, desde DM)
module FIFO_In #(
    parameter WIDTH = 16
    )(
    input  wire             clk,
    input  wire             en,      // FIFO_in_EN (viene de la Control Unit)
    input  wire [3:0]       nibble,
    output reg  [WIDTH-1:0] word
    );

    always @(posedge clk) begin
        if (en)
            word <= {nibble, word[WIDTH-1:4]};
    end

endmodule
