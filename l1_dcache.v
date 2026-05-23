module l1_dcache #(
    parameter CACHE_SIZE = 8192,
    parameter BLOCK_SIZE = 64,
    parameter WAYS = 4
)(
    input wire clk, rst,
    input wire [31:0] cpu_addr,
    input wire [31:0] cpu_wdata,
    input wire cpu_req, cpu_we,
    input wire [3:0] cpu_be,
    output wire [31:0] cpu_rdata,
    output wire cpu_ready,
    output wire [31:0] l2_addr,
    output reg [511:0] l2_wdata,
    output reg l2_req, l2_we,
    input wire [511:0] l2_rdata,
    input wire l2_ready,
    output reg [31:0] hit_count, miss_count, writeback_count
);
    localparam SETS = CACHE_SIZE / (BLOCK_SIZE * WAYS);
    localparam WORDS_PER_BLOCK = BLOCK_SIZE / 4;
    localparam INDEX_BITS = $clog2(SETS);
    localparam OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS;
    
    reg [31:0] data_array [0:SETS-1][0:WAYS-1][0:WORDS_PER_BLOCK-1];
    reg [TAG_BITS-1:0] tag_array [0:SETS-1][0:WAYS-1];
    reg valid_array [0:SETS-1][0:WAYS-1];
    reg dirty_array [0:SETS-1][0:WAYS-1];
    reg [2:0] lru_counter [0:SETS-1][0:WAYS-1];
    
    wire [TAG_BITS-1:0] tag = cpu_addr[31:OFFSET_BITS+INDEX_BITS];
    wire [INDEX_BITS-1:0] index = cpu_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    wire [OFFSET_BITS-1:0] offset = cpu_addr[OFFSET_BITS-1:0];
    wire [$clog2(WORDS_PER_BLOCK)-1:0] word_offset = offset[OFFSET_BITS-1:2];
    
    wire [WAYS-1:0] way_hit;
    wire cache_hit;
    wire [1:0] hit_way;
    
    genvar w;
    generate
        for (w = 0; w < WAYS; w = w + 1) begin : hit_check
            assign way_hit[w] = valid_array[index][w] && (tag_array[index][w] == tag);
        end
    endgenerate
    
    assign cache_hit = |way_hit;
    assign hit_way = way_hit[0] ? 2'd0 : way_hit[1] ? 2'd1 : way_hit[2] ? 2'd2 : 2'd3;
    
    reg [1:0] min_lru_way;
    integer i, k;
    always @(*) begin
        min_lru_way = 0;
        for (i = 1; i < WAYS; i = i + 1)
            if (lru_counter[index][i] < lru_counter[index][min_lru_way])
                min_lru_way = i;
    end
    wire [1:0] victim_way = min_lru_way;
    wire victim_dirty = valid_array[index][victim_way] && dirty_array[index][victim_way];
    
    reg [31:0] latched_addr, latched_wdata;
    reg latched_we;
    reg [3:0] latched_be;
    reg [1:0] replace_way;
    
    wire [TAG_BITS-1:0] latched_tag = latched_addr[31:OFFSET_BITS+INDEX_BITS];
    wire [INDEX_BITS-1:0] latched_index = latched_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    wire [OFFSET_BITS-1:0] latched_offset = latched_addr[OFFSET_BITS-1:0];
    wire [$clog2(WORDS_PER_BLOCK)-1:0] latched_word_offset = latched_offset[OFFSET_BITS-1:2];
    
    assign l2_addr = {latched_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
    
    localparam IDLE = 0, WRITE_BACK = 1, REFILL = 2;
    reg [1:0] state;
    
    assign cpu_ready = (state == IDLE && cpu_req && cache_hit) || (state == REFILL && l2_ready);
    assign cpu_rdata = (state == IDLE) ? data_array[index][hit_way][word_offset] :
                       (state == REFILL && l2_ready) ? l2_rdata[latched_word_offset*32 +: 32] : 32'h0;
    
    // ✅ SIMULATOR SAFE READ WRAPPERS
    wire [31:0] old_word_hit = data_array[index][hit_way][word_offset];
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            l2_req <= 0; l2_we <= 0;
            hit_count <= 0; miss_count <= 0; writeback_count <= 0;
            for (i = 0; i < SETS; i = i + 1) begin
                for (k = 0; k < WAYS; k = k + 1) begin
                    valid_array[i][k] <= 0; dirty_array[i][k] <= 0; lru_counter[i][k] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_req) begin
                        if (cache_hit) begin
                            hit_count <= hit_count + 1;
                            if (cpu_we) begin
                                data_array[index][hit_way][word_offset] <= {
                                    cpu_be[3] ? cpu_wdata[31:24] : old_word_hit[31:24],
                                    cpu_be[2] ? cpu_wdata[23:16] : old_word_hit[23:16],
                                    cpu_be[1] ? cpu_wdata[15:8]  : old_word_hit[15:8],
                                    cpu_be[0] ? cpu_wdata[7:0]   : old_word_hit[7:0]
                                };
                                dirty_array[index][hit_way] <= 1;
                            end
                            lru_counter[index][hit_way] <= 3'b111;
                            for (k = 0; k < WAYS; k = k + 1)
                                if (k != hit_way && lru_counter[index][k] > 0)
                                    lru_counter[index][k] <= lru_counter[index][k] - 1;
                        end else begin
                            miss_count <= miss_count + 1;
                            latched_addr <= cpu_addr; latched_wdata <= cpu_wdata;
                            latched_we <= cpu_we; latched_be <= cpu_be;
                            replace_way <= victim_way;
                            if (victim_dirty) state <= WRITE_BACK;
                            else begin l2_req <= 1; l2_we <= 0; state <= REFILL; end
                        end
                    end
                end
                WRITE_BACK: begin
                    if (!l2_req) begin
                        l2_req <= 1; l2_we <= 1;
                        for (k = 0; k < WORDS_PER_BLOCK; k = k + 1)
                            l2_wdata[k*32 +: 32] <= data_array[latched_index][replace_way][k];
                        writeback_count <= writeback_count + 1;
                    end else if (l2_ready) begin
                        l2_req <= 1; l2_we <= 0; state <= REFILL;
                    end
                end
                REFILL: begin
                    if (l2_ready) begin
                        l2_req <= 0;
                        for (k = 0; k < WORDS_PER_BLOCK; k = k + 1) begin
                            if (latched_we && k == latched_word_offset) begin
                                data_array[latched_index][replace_way][k] <= {
                                    latched_be[3] ? latched_wdata[31:24] : l2_rdata[k*32 + 24 +: 8],
                                    latched_be[2] ? latched_wdata[23:16] : l2_rdata[k*32 + 16 +: 8],
                                    latched_be[1] ? latched_wdata[15:8]  : l2_rdata[k*32 +  8 +: 8],
                                    latched_be[0] ? latched_wdata[7:0]   : l2_rdata[k*32 +  0 +: 8]
                                };
                            end else begin
                                data_array[latched_index][replace_way][k] <= l2_rdata[k*32 +: 32];
                            end
                        end
                        if (latched_we) dirty_array[latched_index][replace_way] <= 1;
                        else dirty_array[latched_index][replace_way] <= 0;
                        
                        tag_array[latched_index][replace_way] <= latched_tag;
                        valid_array[latched_index][replace_way] <= 1;
                        
                        lru_counter[latched_index][replace_way] <= 3'b111;
                        for (k = 0; k < WAYS; k = k + 1)
                            if (k != replace_way && lru_counter[latched_index][k] > 0)
                                lru_counter[latched_index][k] <= lru_counter[latched_index][k] - 1;
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
endmodule