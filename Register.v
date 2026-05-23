module Register(
    input clk, rst,
    input [4:0] read_reg1, read_reg2, write_reg,
    input [31:0] write_data,
    input reg_write,
    output [31:0] read_data1, read_data2
);
    reg [31:0] registers [0:31];
    integer i;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 0;
            end
        end else if (reg_write && write_reg != 0) begin
            registers[write_reg] <= write_data;
        end
    end
    
    assign read_data1 = (read_reg1 == 0) ? 0 : registers[read_reg1];
    assign read_data2 = (read_reg2 == 0) ? 0 : registers[read_reg2];
endmodule