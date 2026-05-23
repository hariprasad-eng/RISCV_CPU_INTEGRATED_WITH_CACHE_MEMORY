module l1_icache #(
    parameter CACHE_SIZE = 8192,
    parameter BLOCK_SIZE = 64,
    parameter WAYS = 4,
    parameter ADDR_WIDTH = 32
)(
    input wire clk, rst,
    input wire [31:0] cpu_addr,
    input wire cpu_req,
    output wire [31:0] cpu_data,
    output wire cpu_ready,
    output wire [31:0] l2_addr,
    output reg l2_req,
    input wire [511:0] l2_data,
    input wire l2_ready,
    output reg [31:0] hit_count, miss_count
);
    localparam SETS = CACHE_SIZE / (BLOCK_SIZE * WAYS);
    localparam WORDS_PER_BLOCK = BLOCK_SIZE / 4;
    localparam INDEX_BITS = $clog2(SETS);
    localparam OFFSET_BITS = $clog2(BLOCK_SIZE);
    localparam TAG_BITS = 32 - INDEX_BITS - OFFSET_BITS;
    
    reg [31:0] data_array [0:SETS-1][0:WAYS-1][0:WORDS_PER_BLOCK-1];
    reg [TAG_BITS-1:0] tag_array [0:SETS-1][0:WAYS-1];
    reg valid_array [0:SETS-1][0:WAYS-1];
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
    
    reg [31:0] latched_addr;
    reg [1:0] replace_way;
    
    wire [TAG_BITS-1:0] latched_tag = latched_addr[31:OFFSET_BITS+INDEX_BITS];
    wire [INDEX_BITS-1:0] latched_index = latched_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];
    wire [OFFSET_BITS-1:0] latched_offset = latched_addr[OFFSET_BITS-1:0];
    wire [$clog2(WORDS_PER_BLOCK)-1:0] latched_word_offset = latched_offset[OFFSET_BITS-1:2];
    
    assign l2_addr = {latched_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
    
    localparam IDLE = 0, REFILL = 1;
    reg state;
    
    // ✅ CRITICAL FIX: Combinational Ready
    assign cpu_ready = (state == IDLE && cpu_req && cache_hit) || (state == REFILL && l2_ready);
    assign cpu_data = (state == IDLE) ? data_array[index][hit_way][word_offset] :
                      (state == REFILL && l2_ready) ? l2_data[latched_word_offset*32 +: 32] : 32'h00000013;
    
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            l2_req <= 0;
            hit_count <= 0;
            miss_count <= 0;
            for (i = 0; i < SETS; i = i + 1) begin
                for (k = 0; k < WAYS; k = k + 1) begin
                    valid_array[i][k] <= 0;
                    lru_counter[i][k] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (cpu_req) begin
                        if (cache_hit) begin
                            hit_count <= hit_count + 1;
                            lru_counter[index][hit_way] <= 3'b111;
                            for (k = 0; k < WAYS; k = k + 1)
                                if (k != hit_way && lru_counter[index][k] > 0)
                                    lru_counter[index][k] <= lru_counter[index][k] - 1;
                        end else begin
                            miss_count <= miss_count + 1;
                            latched_addr <= cpu_addr;
                            replace_way <= victim_way;
                            l2_req <= 1;
                            state <= REFILL;
                        end
                    end
                end
                REFILL: begin
                    if (l2_ready) begin
                        l2_req <= 0;
                        for (k = 0; k < WORDS_PER_BLOCK; k = k + 1)
                            data_array[latched_index][replace_way][k] <= l2_data[k*32 +: 32];
                        
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