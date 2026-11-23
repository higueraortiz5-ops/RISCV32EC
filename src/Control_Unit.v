`timescale 1ns / 1ps
// Unidad de control multiciclo para el subconjunto RV32EC:
//   C.LW C.SW C.ADDI C.LUI C.SRLI C.SRAI C.SUB C.XOR C.AND C.SLLI C.MV
//
// Protocolo con las memorias externas (todo en nibbles, LSB primero):
//  IM: el procesador toma un nibble de Inst en cada flanco con
//      halt = 1 y hold = 0  (halt = "valid", hold = "no envies mas").
//  DM: send = 1 durante 8 ciclos -> Dir (y Data si es SW) en las salidas.
//      mem_write = 1 indica SW, 0 indica LW.
//      En LW la DM responde 8 nibbles por Data_in con recive = 1.
//
// Estados:
//   FETCH : recibe los 4 nibbles de la instruccion
//   EXEC  : instrucciones de ALU escriben el resultado (1 ciclo)
//   SEND  : LW/SW envian direccion (y dato en SW), 8 ciclos
//   RECV  : LW espera los 8 nibbles del dato
//   WB    : LW escribe el dato en rd'
module Control_Unit(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [15:0] Inst,
    input  wire        halt,       // IM: hay un nibble de instruccion valido
    input  wire        recive,     // DM: hay un nibble de dato valido

    output reg         ResultSrc,  // Wd_sel : 0 ALU, 1 dato de memoria
    output reg  [2:0]  ALUControl,
    output reg         SrcB_sel,   // Rd2_sel: 0 RD2, 1 inmediato
    output reg  [1:0]  ImmSrc,
    output reg  [1:0]  A1_sel,     // Rs1_sel: 00 Inst[10:7], 01 rs1', 10 rd'(Inst[4:2])
    output reg         A2_sel,     // Rs2_sel: 0 Inst[5:2], 1 rs2'
    output reg         WE,

    output wire        fifo_inst_en,  // FIFO_in_EN de instruccion
    output wire        fifo_data_en,  // FIFO_in_EN de dato (LW)
    output wire        send,          // FIFO_out_EN, valido hacia la DM
    output wire        mem_write,     // 1 = SW, 0 = LW
    output wire [2:0]  nib_idx,       // nibble que se envia
    output wire        hold           // hacia la IM: no enviar
    );

    // ---------------- Codigos de la ALU ----------------
    localparam ALU_ADD = 3'b000, ALU_SUB = 3'b001, ALU_AND = 3'b010, ALU_XOR = 3'b011,
               ALU_SLL = 3'b100, ALU_SRL = 3'b101, ALU_SRA = 3'b110, ALU_PASSB = 3'b111;

    // ---------------- Estados ----------------
    localparam S_FETCH = 3'd0, S_EXEC = 3'd1, S_SEND = 3'd2, S_RECV = 3'd3, S_WB = 3'd4;

    reg [2:0] state, next_state;
    reg [2:0] cnt;

    // ---------------- Decodificador ----------------
    wire [1:0] op = Inst[1:0];
    wire [2:0] f3 = Inst[15:13];

    wire is_lw   = (op == 2'b00) && (f3 == 3'b010);
    wire is_sw   = (op == 2'b00) && (f3 == 3'b110);
    wire is_addi = (op == 2'b01) && (f3 == 3'b000);
    wire is_lui  = (op == 2'b01) && (f3 == 3'b011);
    wire is_misc = (op == 2'b01) && (f3 == 3'b100);
    wire is_srli = is_misc && (Inst[11:10] == 2'b00);
    wire is_srai = is_misc && (Inst[11:10] == 2'b01);
    wire is_arit = is_misc && (Inst[11:10] == 2'b11) && !Inst[12];
    wire is_sub  = is_arit && (Inst[6:5] == 2'b00);
    wire is_xor  = is_arit && (Inst[6:5] == 2'b01);
    wire is_and  = is_arit && (Inst[6:5] == 2'b11);
    wire is_slli = (op == 2'b10) && (f3 == 3'b000);
    wire is_mv   = (op == 2'b10) && (f3 == 3'b100) && !Inst[12] && (Inst[6:2] != 5'd0);

    wire is_alu  = is_addi | is_lui | is_srli | is_srai | is_sub |
                   is_xor  | is_and | is_slli | is_mv;
    wire is_mem  = is_lw | is_sw;

    // ---------------- Registro de estado y contador ----------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_FETCH;
            cnt   <= 3'd0;
        end else begin
            state <= next_state;
            case (state)
                S_FETCH: if (halt)   cnt <= (cnt == 3'd3) ? 3'd0 : cnt + 3'd1;
                S_SEND :             cnt <= cnt + 3'd1;      // 0..7, vuelve a 0
                S_RECV : if (recive) cnt <= cnt + 3'd1;
                default:             cnt <= 3'd0;
            endcase
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            S_FETCH: if (halt && cnt == 3'd3) next_state = S_EXEC;
            S_EXEC : next_state = is_mem ? S_SEND : S_FETCH;   // ilegal -> NOP
            S_SEND : if (cnt == 3'd7) next_state = is_sw ? S_FETCH : S_RECV;
            S_RECV : if (recive && cnt == 3'd7) next_state = S_WB;
            S_WB   : next_state = S_FETCH;
            default: next_state = S_FETCH;
        endcase
    end

    // ---------------- Senales del camino de datos ----------------
    always @(*) begin
        // valores por defecto
        ResultSrc  = 1'b0;
        ALUControl = ALU_ADD;
        SrcB_sel   = 1'b0;
        ImmSrc     = 2'b00;
        A1_sel     = 2'b00;
        A2_sel     = 1'b0;

        if (is_lw | is_sw) begin
            A1_sel = 2'b01; A2_sel = 1'b1; SrcB_sel = 1'b1; ImmSrc = 2'b00; ALUControl = ALU_ADD;
        end
        if (is_addi) begin A1_sel = 2'b00; SrcB_sel = 1'b1; ImmSrc = 2'b01; ALUControl = ALU_ADD;   end
        if (is_lui)  begin A1_sel = 2'b00; SrcB_sel = 1'b1; ImmSrc = 2'b10; ALUControl = ALU_PASSB; end
        if (is_slli) begin A1_sel = 2'b00; SrcB_sel = 1'b1; ImmSrc = 2'b11; ALUControl = ALU_SLL;   end
        if (is_srli) begin A1_sel = 2'b01; SrcB_sel = 1'b1; ImmSrc = 2'b11; ALUControl = ALU_SRL;   end
        if (is_srai) begin A1_sel = 2'b01; SrcB_sel = 1'b1; ImmSrc = 2'b11; ALUControl = ALU_SRA;   end
        if (is_sub)  begin A1_sel = 2'b01; A2_sel = 1'b1; ALUControl = ALU_SUB; end
        if (is_xor)  begin A1_sel = 2'b01; A2_sel = 1'b1; ALUControl = ALU_XOR; end
        if (is_and)  begin A1_sel = 2'b01; A2_sel = 1'b1; ALUControl = ALU_AND; end
        if (is_mv)   begin A1_sel = 2'b00; A2_sel = 1'b0; ALUControl = ALU_PASSB; end

        // write-back de LW: escribir el dato de memoria en rd' = Inst[4:2]
        if (state == S_WB) begin
            A1_sel    = 2'b10;
            ResultSrc = 1'b1;
        end
    end

    always @(*) begin
        WE = 1'b0;
        if (state == S_EXEC && is_alu) WE = 1'b1;
        if (state == S_WB)             WE = 1'b1;
    end

    assign hold         = (state != S_FETCH);
    assign fifo_inst_en = (state == S_FETCH) && halt;
    assign fifo_data_en = (state == S_RECV)  && recive;
    assign send         = (state == S_SEND);
    assign mem_write    = (state == S_SEND) && is_sw;
    assign nib_idx      = cnt;

endmodule
