// ============================================================
// reg1.v — IF/ID Pipeline Register
// Reset  : active-LOW (~rst)
// Stall  : IFIDWrite=0 → hold current values (load-use hazard)
// Flush  : flush=1     → insert NOP (branch taken OR reset)
// Flush takes priority over stall.
// ============================================================

module reg1(
    input clk,
    input rst,
    input stall,
    input [31:0] pc_in,
    input [31:0] instruction_in,
    output reg [31:0] pc_out,
    output reg [31:0] instruction_out
);
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_out <= 32'h00000000;
            instruction_out <= 32'h00000013; // NOP
        end else if (!stall) begin
            pc_out <= pc_in;
            instruction_out <= instruction_in;
        end
    end
endmodule