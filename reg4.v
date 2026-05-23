// ============================================================
// reg4.v — MEM/WB Pipeline Register
// Reset: active-LOW (~rst), matches PC/Register/DataMemory
// ============================================================

module reg4(
    input clk,
    input rst,
    input stall,
    
    // Data inputs
    input [31:0] alu_result_in,
    input [31:0] mem_data_in,
    input [4:0] rd_in,
    
    // Control inputs
    input reg_write_in,
    input mem_to_reg_in,
    
    // Data outputs
    output reg [31:0] alu_result_out,
    output reg [31:0] mem_data_out,
    output reg [4:0] rd_out,
    
    // Control outputs
    output reg reg_write_out,
    output reg mem_to_reg_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            alu_result_out <= 32'h00000000;
            mem_data_out <= 32'h00000000;
            rd_out <= 5'b00000;
            reg_write_out <= 1'b0;
            mem_to_reg_out <= 1'b0;
        end else if (!stall) begin
            alu_result_out <= alu_result_in;
            mem_data_out <= mem_data_in;
            rd_out <= rd_in;
            reg_write_out <= reg_write_in;
            mem_to_reg_out <= mem_to_reg_in;
        end
    end
endmodule