module ALUCtrl(
    input [1:0] alu_op,
    input funct7,
    input [2:0] funct3,
    output reg [3:0] alu_control
);

always @(*) begin
    case (alu_op)

        2'b00: alu_control = 4'b0010; // ADD for load/store

        2'b01: alu_control = 4'b0110; // SUB for branch

        2'b10: begin
            case (funct3)

                3'b000:
                    alu_control = (funct7) ? 4'b0110 : 4'b0010; // SUB : ADD

                3'b111:
                    alu_control = 4'b0000; // AND

                3'b110:
                    alu_control = 4'b0001; // OR

                3'b100:
                    alu_control = 4'b0011; // XOR

                3'b001:
                    alu_control = 4'b1010; // SLL

                3'b101:
                    alu_control = (funct7) ? 4'b1001 : 4'b1000; // SRA : SRL

                3'b010:
                    alu_control = 4'b0111; // SLT

                3'b011:
                    alu_control = 4'b1011; // SLTU

                default:
                    alu_control = 4'b0010;

            endcase
        end

        default:
            alu_control = 4'b0010;

    endcase
end

endmodule