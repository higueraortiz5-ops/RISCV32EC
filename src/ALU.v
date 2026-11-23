`timescale 1ns / 1ps
// ALU de 32 bits para RV32EC (subconjunto)
//
// Tabla de control (redefinida):
//   000 ADD    (C.ADDI, direccion de C.LW / C.SW)
//   001 SUB    (C.SUB)
//   010 AND    (C.AND)
//   011 XOR    (C.XOR)
//   100 SLL    (C.SLLI)
//   101 SRL    (C.SRLI)
//   110 SRA    (C.SRAI)
//   111 PASS_B (C.LUI -> imm, C.MV -> rs2)
//
// Para ahorrar area en Tiny Tapeout se usa UN solo desplazador a la derecha:
//   - SRA/SRL: se desplaza {bit_extra, A} de 33 bits, bit_extra = A[31] solo en SRA
//   - SLL    : se invierte A, se desplaza a la derecha y se vuelve a invertir
module ALU(
    input  wire [31:0] SrcA,
    input  wire [31:0] SrcB,
    input  wire [2:0]  ALUControl,
    output reg  [31:0] ALUResult
    );

    // Sumador/restador compartido
    wire        sub   = (ALUControl == 3'b001);
    wire [31:0] B_mux = sub ? ~SrcB : SrcB;
    wire [31:0] sum   = SrcA + B_mux + {31'b0, sub};

    // Desplazador unico
    wire        is_left  = (ALUControl == 3'b100);
    wire        is_arith = (ALUControl == 3'b110);
    wire [4:0]  shamt    = SrcB[4:0];

    function [31:0] rev32(input [31:0] x);
        integer k;
        begin
            for (k = 0; k < 32; k = k + 1) rev32[k] = x[31-k];
        end
    endfunction

    wire [31:0] sh_in   = is_left ? rev32(SrcA) : SrcA;
    wire        fill    = is_arith & SrcA[31];
    wire signed [32:0] sh_ext = {fill, sh_in};
    wire [32:0] sh_res  = sh_ext >>> shamt;
    wire [31:0] shift_r = sh_res[31:0];
    wire [31:0] shift_op = is_left ? rev32(shift_r) : shift_r;

    always @(*) begin
        case (ALUControl)
            3'b000:  ALUResult = sum;
            3'b001:  ALUResult = sum;
            3'b010:  ALUResult = SrcA & SrcB;
            3'b011:  ALUResult = SrcA ^ SrcB;
            3'b100,
            3'b101,
            3'b110:  ALUResult = shift_op;
            3'b111:  ALUResult = SrcB;
            default: ALUResult = 32'b0;
        endcase
    end

endmodule
