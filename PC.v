module PC(
    input clk,
    input rst,
    input pc_enable,      // This is ~stall (1 = run, 0 = stall)
    input branch,
    input [31:0] branch_addr,
    output reg [31:0] pc
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'h00000000;
        end else if (pc_enable) begin  // Only update when enabled
            if (branch) begin
                pc <= branch_addr;
            end else begin
                pc <= pc + 4;
            end
        end
        // When pc_enable = 0, PC holds its value
    end
endmodule