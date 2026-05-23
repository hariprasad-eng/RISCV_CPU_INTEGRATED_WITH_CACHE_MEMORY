// ============================================================================
// Cache Controller / Arbiter
// - Arbitrates between L1 I-cache and D-cache requests to L2
// - Round-robin or priority-based arbitration
// ============================================================================

module cache_controller (
    input  wire         clk,
    input  wire         rst,
    
    // L1 I-Cache Interface
    input  wire [31:0]  l1i_addr,
    input  wire         l1i_req,
    output reg  [511:0] l1i_rdata,
    output reg          l1i_ready,
    
    // L1 D-Cache Interface
    input  wire [31:0]  l1d_addr,
    input  wire [511:0] l1d_wdata,
    input  wire         l1d_req,
    input  wire         l1d_we,
    output reg  [511:0] l1d_rdata,
    output reg          l1d_ready,
    
    // L2 Cache Interface
    output reg  [31:0]  l2_addr,
    output reg  [511:0] l2_wdata,
    output reg          l2_req,
    output reg          l2_we,
    input  wire [511:0] l2_rdata,
    input  wire         l2_ready
);

    // ========================================================================
    // Arbitration State Machine
    // ========================================================================
    localparam IDLE      = 2'b00;
    localparam SERVE_I   = 2'b01;
    localparam SERVE_D   = 2'b10;
    
    reg [1:0] state, next_state;
    reg       last_served;  // 0=I-cache, 1=D-cache (for round-robin)
    
    // ========================================================================
    // State Transition
    // ========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            last_served <= 0;
        end else begin
            state <= next_state;
        end
    end
    
    // ========================================================================
    // Next State Logic (Priority: D-cache > I-cache for better performance)
    // ========================================================================
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                // Priority arbitration: D-cache has higher priority
                if (l1d_req) begin
                    next_state = SERVE_D;
                end else if (l1i_req) begin
                    next_state = SERVE_I;
                end
            end
            
            SERVE_I: begin
                if (l2_ready) begin
                    next_state = IDLE;
                end
            end
            
            SERVE_D: begin
                if (l2_ready) begin
                    next_state = IDLE;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // ========================================================================
    // Output Logic
    // ========================================================================
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            l1i_ready <= 0;
            l1d_ready <= 0;
            l2_req <= 0;
            l2_we <= 0;
            l2_addr <= 0;
            l2_wdata <= 0;
            l1i_rdata <= 0;
            l1d_rdata <= 0;
        end else begin
            case (state)
                IDLE: begin
                    l1i_ready <= 0;
                    l1d_ready <= 0;
                    l2_req <= 0;
                end
                
                SERVE_I: begin
                    // Forward I-cache request to L2
                    l2_req <= 1;
                    l2_we <= 0;  // Read only
                    l2_addr <= l1i_addr;
                    
                    if (l2_ready) begin
                        l1i_rdata <= l2_rdata;
                        l1i_ready <= 1;
                        l2_req <= 0;
                        last_served <= 0;
                    end else begin
                        l1i_ready <= 0;
                    end
                end
                
                SERVE_D: begin
                    // Forward D-cache request to L2
                    l2_req <= 1;
                    l2_we <= l1d_we;
                    l2_addr <= l1d_addr;
                    l2_wdata <= l1d_wdata;
                    
                    if (l2_ready) begin
                        l1d_rdata <= l2_rdata;
                        l1d_ready <= 1;
                        l2_req <= 0;
                        last_served <= 1;
                    end else begin
                        l1d_ready <= 0;
                    end
                end
                
                default: begin
                    l1i_ready <= 0;
                    l1d_ready <= 0;
                    l2_req <= 0;
                end
            endcase
        end
    end

endmodule