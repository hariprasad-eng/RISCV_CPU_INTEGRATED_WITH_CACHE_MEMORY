// ============================================================================
// Top-Level Module: RISC-V Processor with Two-Level Cache
// - Integrates L1 I-cache, L1 D-cache, L2 unified cache, and main memory
// - Provides interface for processor
// ============================================================================

module riscv_cache_system #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input  wire                     clk,
    input  wire                     rst,
    
    // ========================================================================
    // Processor Instruction Fetch Interface
    // ========================================================================
    
    input  wire [ADDR_WIDTH-1:0]    pc,              // Program counter
    input  wire                     instr_req,       // Instruction request
    output wire [DATA_WIDTH-1:0]    instruction,     // Fetched instruction
    output wire                     instr_ready,     // Instruction ready
    
    // ========================================================================
    // Processor Data Memory Interface
    // ========================================================================
    input  wire [ADDR_WIDTH-1:0]    data_addr,       // Data address
    input  wire [DATA_WIDTH-1:0]    data_wdata,      // Write data
    input  wire                     data_req,        // Data request
    input  wire                     data_we,         // Write enable
    input  wire [3:0]               data_be,         // Byte enable
    output wire [DATA_WIDTH-1:0]    data_rdata,      // Read data
    output wire                     data_ready,      // Data ready
    
    // ========================================================================
    // Performance Counters (for analysis)
    // ========================================================================
    output wire [31:0]              l1i_hit_count,
    output wire [31:0]              l1i_miss_count,
    output wire [31:0]              l1d_hit_count,
    output wire [31:0]              l1d_miss_count,
    output wire [31:0]              l2_hit_count,
    output wire [31:0]              l2_miss_count,
    output wire [31:0]              l1d_writeback_count,
    output wire [31:0]              l2_writeback_count,
    
    // ========================================================================
    // Total Cycle Counter
    // ========================================================================
    output reg  [31:0]              total_cycles
);

    // ========================================================================
    // Internal Signals - L1 I-Cache to L2
    // ========================================================================
    wire [31:0]  l1i_to_l2_addr;
    wire         l1i_to_l2_req;
    wire [511:0] l2_to_l1i_data;
    wire         l2_to_l1i_ready;
    
    // ========================================================================
    // Internal Signals - L1 D-Cache to L2
    // ========================================================================
    wire [31:0]  l1d_to_l2_addr;
    wire [511:0] l1d_to_l2_wdata;
    wire         l1d_to_l2_req;
    wire         l1d_to_l2_we;
    wire [511:0] l2_to_l1d_data;
    wire         l2_to_l1d_ready;
    
    // ========================================================================
    // Internal Signals - L2 to Main Memory
    // ========================================================================
    wire [31:0]  l2_to_mem_addr;
    wire [511:0] l2_to_mem_wdata;
    wire         l2_to_mem_req;
    wire         l2_to_mem_we;
    wire [511:0] mem_to_l2_data;
    wire         mem_to_l2_ready;
    
    // ========================================================================
    // Internal Signals - Arbiter to L2
    // ========================================================================
    wire [31:0]  arb_to_l2_addr;
    wire [511:0] arb_to_l2_wdata;
    wire         arb_to_l2_req;
    wire         arb_to_l2_we;
    wire [511:0] l2_to_arb_data;
    wire         l2_to_arb_ready;
    
    // ========================================================================
    // Module Instantiations
    // ========================================================================
    
    // ------------------------------------------------------------------------
    // L1 Instruction Cache
    // ------------------------------------------------------------------------
    l1_icache #(
        .CACHE_SIZE(8192),
        .BLOCK_SIZE(64),
        .WAYS(4),
        .ADDR_WIDTH(32)
    ) l1_icache_inst (
        .clk(clk),
        .rst(rst),
        
        // CPU Interface
        .cpu_addr(pc),
        .cpu_req(instr_req),
        .cpu_data(instruction),
        .cpu_ready(instr_ready),
        
        // L2 Interface (via arbiter)
        .l2_addr(l1i_to_l2_addr),
        .l2_req(l1i_to_l2_req),
        .l2_data(l2_to_l1i_data),
        .l2_ready(l2_to_l1i_ready),
        
        // Statistics
        .hit_count(l1i_hit_count),
        .miss_count(l1i_miss_count)
    );
    
    // ------------------------------------------------------------------------
    // L1 Data Cache
    // ------------------------------------------------------------------------
    l1_dcache #(
        .CACHE_SIZE(8192),
        .BLOCK_SIZE(64),
        .WAYS(4)
        
    ) l1_dcache_inst (
        .clk(clk),
        .rst(rst),
        
        // CPU Interface
        .cpu_addr(data_addr),
        .cpu_wdata(data_wdata),
        .cpu_req(data_req),
        .cpu_we(data_we),
        .cpu_be(data_be),
        .cpu_rdata(data_rdata),
        .cpu_ready(data_ready),
        
        // L2 Interface (via arbiter)
        .l2_addr(l1d_to_l2_addr),
        .l2_wdata(l1d_to_l2_wdata),
        .l2_req(l1d_to_l2_req),
        .l2_we(l1d_to_l2_we),
        .l2_rdata(l2_to_l1d_data),
        .l2_ready(l2_to_l1d_ready),
        
        // Statistics
        .hit_count(l1d_hit_count),
        .miss_count(l1d_miss_count),
        .writeback_count(l1d_writeback_count)
    );
    
    // ------------------------------------------------------------------------
    // Cache Controller / Arbiter
    // ------------------------------------------------------------------------
    cache_controller arbiter_inst (
        .clk(clk),
        .rst(rst),
        
        // L1 I-Cache Interface
        .l1i_addr(l1i_to_l2_addr),
        .l1i_req(l1i_to_l2_req),
        .l1i_rdata(l2_to_l1i_data),
        .l1i_ready(l2_to_l1i_ready),
        
        // L1 D-Cache Interface
        .l1d_addr(l1d_to_l2_addr),
        .l1d_wdata(l1d_to_l2_wdata),
        .l1d_req(l1d_to_l2_req),
        .l1d_we(l1d_to_l2_we),
        .l1d_rdata(l2_to_l1d_data),
        .l1d_ready(l2_to_l1d_ready),
        
        // L2 Cache Interface
        .l2_addr(arb_to_l2_addr),
        .l2_wdata(arb_to_l2_wdata),
        .l2_req(arb_to_l2_req),
        .l2_we(arb_to_l2_we),
        .l2_rdata(l2_to_arb_data),
        .l2_ready(l2_to_arb_ready)
    );
    
    // ------------------------------------------------------------------------
    // L2 Unified Cache
    // ------------------------------------------------------------------------
    l2_cache #(
        .CACHE_SIZE(65536),
        .BLOCK_SIZE(64),
        .WAYS(8)
    ) l2_cache_inst (
        .clk(clk),
        .rst(rst),
        
        // L1 Interface (from arbiter)
        .l1_addr(arb_to_l2_addr),
        .l1_wdata(arb_to_l2_wdata),
        .l1_req(arb_to_l2_req),
        .l1_we(arb_to_l2_we),
        .l1_rdata(l2_to_arb_data),
        .l1_ready(l2_to_arb_ready),
        
        // Main Memory Interface
        .mem_addr(l2_to_mem_addr),
        .mem_wdata(l2_to_mem_wdata),
        .mem_req(l2_to_mem_req),
        .mem_we(l2_to_mem_we),
        .mem_rdata(mem_to_l2_data),
        .mem_ready(mem_to_l2_ready),
        
        // Statistics
        .hit_count(l2_hit_count),
        .miss_count(l2_miss_count),
        .writeback_count(l2_writeback_count)
    );
    
    // ------------------------------------------------------------------------
    // Main Memory
    // ------------------------------------------------------------------------
    main_memory #(
        .MEM_SIZE(262144),
        .BLOCK_SIZE(64),
        .ADDR_WIDTH(32),
        .ACCESS_LATENCY(5)
    ) main_memory_inst (
        .clk(clk),
        .rst(rst),
        
        // L2 Cache Interface
        .mem_addr(l2_to_mem_addr),
        .mem_wdata(l2_to_mem_wdata),
        .mem_req(l2_to_mem_req),
        .mem_we(l2_to_mem_we),
        .mem_rdata(mem_to_l2_data),
        .mem_ready(mem_to_l2_ready)
    );
    
    // ========================================================================
    // Total Cycle Counter
    // ========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            total_cycles <= 0;
        end else begin
            total_cycles <= total_cycles + 1;
        end
    end

endmodule