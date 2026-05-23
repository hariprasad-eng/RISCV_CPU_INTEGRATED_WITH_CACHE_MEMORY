module Control (
    input [6:0] opcode,
    output reg branch,
    output reg memRead,
    output reg memtoReg,
    output reg [1:0] ALUOp,
    output reg memWrite,
    output reg ALUSrc,
    output reg regWrite,
    // NEW signals for Q3
    output reg jump,        // 1 = JAL  (PC-relative jump)
    output reg jumpReg      // 1 = JALR (register-relative jump)
);

always @(*) begin
    case(opcode)

        // R-type: add, sub, and, or, xor, sll, slt, sltu, srl, sra
        7'b0110011: begin
            ALUSrc   = 1'b0;
            memtoReg = 1'b0;
            regWrite = 1'b1;
            memRead  = 1'b0;
            memWrite = 1'b0;
            branch   = 1'b0;
            ALUOp    = 2'b10;
            jump     = 1'b0;
            jumpReg  = 1'b0;
        end

        // I-type ALU: addi, slti, sltui, xori, ori, andi, slli, srli, srai
        7'b0010011: begin
            ALUSrc   = 1'b1;
            memtoReg = 1'b0;
            regWrite = 1'b1;
            memRead  = 1'b0;
            memWrite = 1'b0;
            branch   = 1'b0;
            ALUOp    = 2'b11;  // I-type: ALUCtrl decodes funct3
            jump     = 1'b0;
            jumpReg  = 1'b0;
        end

        // lw
        7'b0000011: begin
            ALUSrc   = 1'b1;
            memtoReg = 1'b1;
            regWrite = 1'b1;
            memRead  = 1'b1;
            memWrite = 1'b0;
            branch   = 1'b0;
            ALUOp    = 2'b00;
            jump     = 1'b0;
            jumpReg  = 1'b0;
        end

        // sw
        7'b0100011: begin
            ALUSrc   = 1'b1;
            memtoReg = 1'b0;
            regWrite = 1'b0;
            memRead  = 1'b0;
            memWrite = 1'b1;
            branch   = 1'b0;
            ALUOp    = 2'b00;
            jump     = 1'b0;
            jumpReg  = 1'b0;
        end

        // B-type: beq (000), bne (001), blt (100), bge (101)
        // All same opcode — funct3 is checked in SingleCycleCPU for branch condition
        7'b1100011: begin
            ALUSrc   = 1'b0;
            memtoReg = 1'b0;
            regWrite = 1'b0;
            memRead  = 1'b0;
            memWrite = 1'b0;
            branch   = 1'b1;
            ALUOp    = 2'b01;  // SUB — SingleCycleCPU checks zero/negative
            jump     = 1'b0;
            jumpReg  = 1'b0;
        end

        // JAL (UJ-type): rd = PC+4,  PC = PC + imm
        7'b1101111: begin
            ALUSrc   = 1'b0;
            memtoReg = 1'b0;
            regWrite = 1'b1;   // write PC+4 to rd
            memRead  = 1'b0;
            memWrite = 1'b0;
            branch   = 1'b0;
            ALUOp    = 2'b00;
            jump     = 1'b1;   // JAL flag
            jumpReg  = 1'b0;
        end

        // JALR (I-type): rd = PC+4,  PC = (rs1 + imm) & ~1
        7'b1100111: begin
            ALUSrc   = 1'b1;   // use immediate as ALU input
            memtoReg = 1'b0;
            regWrite = 1'b1;   // write PC+4 to rd
            memRead  = 1'b0;
            memWrite = 1'b0;
            branch   = 1'b0;
            ALUOp    = 2'b00;  // ADD: rs1 + imm gives jump address
            jump     = 1'b0;
            jumpReg  = 1'b1;   // JALR flag
        end

        default: begin
            ALUSrc   = 1'b0;
            memtoReg = 1'b0;
            regWrite = 1'b0;
            memRead  = 1'b0;
            memWrite = 1'b0;
            branch   = 1'b0;
            ALUOp    = 2'b00;
            jump     = 1'b0;
            jumpReg  = 1'b0;
        end

    endcase
end

endmodule