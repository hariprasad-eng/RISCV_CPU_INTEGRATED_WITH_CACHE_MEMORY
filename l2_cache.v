module l2_cache #(
    parameter CACHE_SIZE = 65536,
    parameter BLOCK_SIZE = 64,
    parameter WAYS = 8
)(
    input wire clk, rst,
    input wire [31:0] l1_addr,
    input wire [511:0] l1_wdata,
    input wire l1_req, l1_we,
    output wire [511:0] l1_rdata,
    output wire l1_ready,
    output wire [31:0] mem_addr,
    output reg [511:0] mem_wdata,
    output reg mem_req, mem_we,
    input wire [511:0] mem_rdata,
    input wire mem_ready,
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

    wire [TAG_BITS-1:0] tag = l1_addr[31:OFFSET_BITS+INDEX_BITS];
    wire [INDEX_BITS-1:0] index = l1_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];

    wire [WAYS-1:0] way_hit;
    wire cache_hit;
    wire [2:0] hit_way;

    genvar w;
    generate
        for (w = 0; w < WAYS; w = w + 1) begin : hit_check
            assign way_hit[w] = valid_array[index][w] && (tag_array[index][w] == tag);
        end
    endgenerate

    assign cache_hit = |way_hit;
    assign hit_way = way_hit[0] ? 3'd0 : way_hit[1] ? 3'd1 : way_hit[2] ? 3'd2 : way_hit[3] ? 3'd3 :
                     way_hit[4] ? 3'd4 : way_hit[5] ? 3'd5 : way_hit[6] ? 3'd6 : 3'd7;

    reg [2:0] min_lru_way;
    integer i, k;
    always @(*) begin
        min_lru_way = 0;
        for (i = 1; i < WAYS; i = i + 1)
            if (lru_counter[index][i] < lru_counter[index][min_lru_way])
                min_lru_way = i;
    end
    wire [2:0] victim_way = min_lru_way;
    wire victim_dirty = valid_array[index][victim_way] && dirty_array[index][victim_way];

    reg [31:0] latched_addr;
    reg [511:0] latched_wdata;
    reg latched_we;
    reg [2:0] replace_way;

    wire [TAG_BITS-1:0] latched_tag = latched_addr[31:OFFSET_BITS+INDEX_BITS];
    wire [INDEX_BITS-1:0] latched_index = latched_addr[OFFSET_BITS+INDEX_BITS-1:OFFSET_BITS];

    assign mem_addr = {latched_addr[31:OFFSET_BITS], {OFFSET_BITS{1'b0}}};

    localparam IDLE = 0, WRITE_BACK = 1, REFILL = 2;
    reg [1:0] state;

    // ✅ COMBINATIONAL OUTPUTS PREVENT DEADLOCKS
    assign l1_ready = (state == IDLE && l1_req && cache_hit) || (state == REFILL && mem_ready);
    
    reg [511:0] hit_rdata;
    always @(*) begin
        for (i = 0; i < WORDS_PER_BLOCK; i = i + 1)
            hit_rdata[i*32 +: 32] = data_array[index][hit_way][i];
    end
    assign l1_rdata = (state == IDLE) ? hit_rdata : mem_rdata;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            mem_req <= 0;
            mem_we <= 0;
            hit_count <= 0; miss_count <= 0; writeback_count <= 0;
            for (i = 0; i < SETS; i = i + 1) begin
                for (k = 0; k < WAYS; k = k + 1) begin
                    valid_array[i][k] <= 0; dirty_array[i][k] <= 0; lru_counter[i][k] <= 0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    if (l1_req) begin
                        if (cache_hit) begin
                            hit_count <= hit_count + 1;
                            if (l1_we) begin
                                for (k = 0; k < WORDS_PER_BLOCK; k = k + 1)
                                    data_array[index][hit_way][k] <= l1_wdata[k*32 +: 32];
                                dirty_array[index][hit_way] <= 1;
                            end
                            lru_counter[index][hit_way] <= 3'b111;
                            for (k = 0; k < WAYS; k = k + 1)
                                if (k != hit_way && lru_counter[index][k] > 0)
                                    lru_counter[index][k] <= lru_counter[index][k] - 1;
                        end else begin
                            miss_count <= miss_count + 1;
                            latched_addr <= l1_addr; latched_wdata <= l1_wdata; latched_we <= l1_we;
                            replace_way <= victim_way;
                            if (victim_dirty) state <= WRITE_BACK;
                            else begin mem_req <= 1; mem_we <= 0; state <= REFILL; end
                        end
                    end
                end
                WRITE_BACK: begin
                    if (!mem_req) begin
                        mem_req <= 1; mem_we <= 1;
                        for (k = 0; k < WORDS_PER_BLOCK; k = k + 1)
                            mem_wdata[k*32 +: 32] <= data_array[latched_index][replace_way][k];
                        writeback_count <= writeback_count + 1;
                    end else if (mem_ready) begin
                        mem_req <= 1; mem_we <= 0; state <= REFILL;
                    end
                end
                REFILL: begin
                    if (mem_ready) begin
                        mem_req <= 0;
                        for (k = 0; k < WORDS_PER_BLOCK; k = k + 1)
                            data_array[latched_index][replace_way][k] <= mem_rdata[k*32 +: 32];
                        tag_array[latched_index][replace_way] <= latched_tag;
                        valid_array[latched_index][replace_way] <= 1;
                        dirty_array[latched_index][replace_way] <= 0;

                        if (latched_we) begin
                            for (k = 0; k < WORDS_PER_BLOCK; k = k + 1)
                                data_array[latched_index][replace_way][k] <= latched_wdata[k*32 +: 32];
                            dirty_array[latched_index][replace_way] <= 1;
                        end

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