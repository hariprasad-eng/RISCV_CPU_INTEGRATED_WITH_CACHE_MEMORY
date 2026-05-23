module main_memory #(
    parameter MEM_SIZE = 262144,
    parameter BLOCK_SIZE = 64,
    parameter ADDR_WIDTH = 32,
    parameter ACCESS_LATENCY = 5  // ✅ 5 cycles for main memory
)(
    input wire clk, rst,
    input wire [ADDR_WIDTH-1:0] mem_addr,
    input wire [511:0] mem_wdata,
    input wire mem_req, mem_we,
    output reg [511:0] mem_rdata,
    output reg mem_ready
);
    localparam MEM_WORDS = MEM_SIZE / 4;
    reg [31:0] memory [0:MEM_WORDS-1];
    reg [7:0] latency_counter;
    reg access_in_progress;
    
    wire [ADDR_WIDTH-1:0] word_addr = mem_addr[ADDR_WIDTH-1:2];
    
    integer i;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_ready <= 0;
            latency_counter <= 0;
            access_in_progress <= 0;
            mem_rdata <= 0;
        end else begin
            if (mem_req && !access_in_progress) begin
                access_in_progress <= 1;
                latency_counter <= ACCESS_LATENCY - 1;  // Start countdown
                mem_ready <= 0;
            end else if (access_in_progress) begin
                if (latency_counter > 0) begin
                    latency_counter <= latency_counter - 1;
                    mem_ready <= 0;
                end else begin
                    // Latency complete - perform operation
                    if (mem_we) begin
                        // WRITE: Store 16 words (512 bits / 32 bits)
                        for (i = 0; i < 16; i = i + 1) begin
                            if ((word_addr + i) < MEM_WORDS) begin
                                memory[word_addr + i] <= mem_wdata[i*32 +: 32];
                            end
                        end
                        // $display("[MEM] Write addr=0x%08h, data[0]=0x%08h", mem_addr, mem_wdata[31:0]);
                    end else begin
                        // READ: Load 16 words
                        for (i = 0; i < 16; i = i + 1) begin
                            if ((word_addr + i) < MEM_WORDS)
                                mem_rdata[i*32 +: 32] <= memory[word_addr + i];
                            else
                                mem_rdata[i*32 +: 32] <= 32'h00000000;
                        end
                        // $display("[MEM] Read addr=0x%08h, data[0]=0x%08h, data[1]=0x%08h", 
                        //          mem_addr, memory[word_addr], memory[word_addr+1]);
                    end
                    mem_ready <= 1;
                    access_in_progress <= 0;
                end
            end else begin
                mem_ready <= 0;
            end
        end
    end
endmodule