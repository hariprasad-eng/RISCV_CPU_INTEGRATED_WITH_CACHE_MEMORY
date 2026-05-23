module riscv_nocache_system #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                     clk, rst,
    input  wire [ADDR_WIDTH-1:0]    pc,
    input  wire                     instr_req,
    output wire [DATA_WIDTH-1:0]    instruction,
    output wire                     instr_ready,
    input  wire [ADDR_WIDTH-1:0]    data_addr,
    input  wire [DATA_WIDTH-1:0]    data_wdata,
    input  wire                     data_req, data_we,
    input  wire [3:0]               data_be,
    output wire [DATA_WIDTH-1:0]    data_rdata,
    output wire                     data_ready,
    // Dummy Counters
    output reg [31:0] l1i_hit_count, l1i_miss_count, l1d_hit_count, l1d_miss_count,
    output reg [31:0] l2_hit_count, l2_miss_count, l1d_writeback_count, l2_writeback_count, total_cycles
);
    reg [31:0] memory [0:65535];
    
    // Instruction Port (5-Cycle Latency)
    reg [2:0] i_timer;
    reg i_busy;
    reg [31:0] latched_pc;
    
    assign instr_ready = (i_busy && i_timer == 0);
    assign instruction = instr_ready ? memory[latched_pc[31:2]] : 32'h00000013;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin i_busy <= 0; i_timer <= 0; end 
        else begin
            if (instr_req && !i_busy) begin
                i_busy <= 1; i_timer <= 4; latched_pc <= pc;
            end else if (i_busy) begin
                if (i_timer > 0) i_timer <= i_timer - 1;
                else i_busy <= 0; 
            end
        end
    end

    // Data Port (5-Cycle Latency)
    reg [2:0] d_timer;
    reg d_busy, latched_we;
    reg [31:0] latched_d_addr, latched_wdata;
    
    assign data_ready = (d_busy && d_timer == 0);
    assign data_rdata = data_ready ? memory[latched_d_addr[31:2]] : 32'h0;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin d_busy <= 0; d_timer <= 0; end 
        else begin
            if (data_req && !d_busy) begin
                d_busy <= 1; d_timer <= 4; 
                latched_d_addr <= data_addr; latched_wdata <= data_wdata; latched_we <= data_we;
            end else if (d_busy) begin
                if (d_timer > 0) d_timer <= d_timer - 1;
                else begin
                    d_busy <= 0;
                    if (latched_we) memory[latched_d_addr[31:2]] <= latched_wdata;
                end
            end
        end
    end
    
    always @(posedge clk) begin
        if (rst) begin
            l1i_hit_count<=0; l1i_miss_count<=0; l1d_hit_count<=0; l1d_miss_count<=0;
            l2_hit_count<=0; l2_miss_count<=0; l1d_writeback_count<=0; l2_writeback_count<=0; total_cycles<=0;
        end
    end
endmodule