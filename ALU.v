module ALU (
    input [3:0] ALUCtl,
    input [31:0] A, B,
    output reg [31:0] ALUOut,
    output zero
);

// ALU operation encoding:
//  0000 = AND
//  0001 = OR
//  0010 = ADD
//  0011 = XOR
//  0110 = SUB
//  0111 = SLT  (signed less than)
//  1011 = SLTU (unsigned less than)
//  1010 = SLL
//  1000 = SRL
//  1001 = SRA

always @(*) begin
    case(ALUCtl)
        4'b0000: ALUOut = A & B;
        4'b0001: ALUOut = A | B;
        4'b0010: ALUOut = A + B;
        4'b0011: ALUOut = A ^ B;
        4'b0110: ALUOut = A - B;
        4'b0111: ALUOut = ($signed(A)   < $signed(B))   ? 32'd1 : 32'd0; // SLT
        4'b1011: ALUOut = ($unsigned(A) < $unsigned(B)) ? 32'd1 : 32'd0; // SLTU
        4'b1010: ALUOut = A << B[4:0];
        4'b1000: ALUOut = A >> B[4:0];
        4'b1001: ALUOut = $signed(A) >>> B[4:0];
        default: ALUOut = 32'd0;
    endcase
end

// Zero flag: ALU result == 0
// Used by beq (A-B==0 means equal), and indirectly bne/blt/bge via SingleCycleCPU
assign zero = (ALUOut == 32'd0);

endmodule