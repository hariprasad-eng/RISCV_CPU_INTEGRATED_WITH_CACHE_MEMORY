module reg2(
    input clk,
    input rst,
    input stall,
    
    input [31:0] pc_in,
    input [31:0] read_data1_in,
    input [31:0] read_data2_in,
    input [31:0] imm_in,
    input [4:0] rs1_in,
    input [4:0] rs2_in,
    input [4:0] rd_in,
    input [6:0] funct7_in,        // ✅ ADDED
    input [2:0] funct3_in,        // ✅ ADDED
    
    input reg_write_in,
    input mem_read_in,
    input mem_write_in,
    input mem_to_reg_in,
    input alu_src_in,
    input branch_in,
    input [1:0] alu_op_in,
    
    output reg [31:0] pc_out,
    output reg [31:0] read_data1_out,
    output reg [31:0] read_data2_out,
    output reg [31:0] imm_out,
    output reg [4:0] rs1_out,
    output reg [4:0] rs2_out,
    output reg [4:0] rd_out,
    output reg [6:0] funct7_out,  // ✅ ADDED
    output reg [2:0] funct3_out,  // ✅ ADDED
    
    output reg reg_write_out,
    output reg mem_read_out,
    output reg mem_write_out,
    output reg mem_to_reg_out,
    output reg alu_src_out,
    output reg branch_out,
    output reg [1:0] alu_op_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 32'h00000000;
            read_data1_out <= 32'h00000000;
            read_data2_out <= 32'h00000000;
            imm_out <= 32'h00000000;
            rs1_out <= 5'b00000;
            rs2_out <= 5'b00000;
            rd_out <= 5'b00000;
            funct7_out <= 7'b0000000;  // ✅ ADDED
            funct3_out <= 3'b000;      // ✅ ADDED
            reg_write_out <= 1'b0;
            mem_read_out <= 1'b0;
            mem_write_out <= 1'b0;
            mem_to_reg_out <= 1'b0;
            alu_src_out <= 1'b0;
            branch_out <= 1'b0;
            alu_op_out <= 2'b00;
        end else if (!stall) begin
            pc_out <= pc_in;
            read_data1_out <= read_data1_in;
            read_data2_out <= read_data2_in;
            imm_out <= imm_in;
            rs1_out <= rs1_in;
            rs2_out <= rs2_in;
            rd_out <= rd_in;
            funct7_out <= funct7_in;   // ✅ ADDED
            funct3_out <= funct3_in;   // ✅ ADDED
            reg_write_out <= reg_write_in;
            mem_read_out <= mem_read_in;
            mem_write_out <= mem_write_in;
            mem_to_reg_out <= mem_to_reg_in;
            alu_src_out <= alu_src_in;
            branch_out <= branch_in;
            alu_op_out <= alu_op_in;
        end
    end
endmodule