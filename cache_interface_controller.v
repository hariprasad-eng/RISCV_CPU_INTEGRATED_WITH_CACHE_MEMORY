module cache_interface_controller(
    input wire clk, rst,
    
    // IF Ports
    input wire [31:0] if_pc, input wire if_req,
    output wire [31:0] if_instruction, output wire if_valid, output wire if_stall,
    
    // MEM Ports
    input wire [31:0] mem_addr, input wire [31:0] mem_wdata,
    input wire mem_req, input wire mem_we, input wire [3:0] mem_be,
    output wire [31:0] mem_rdata, output wire mem_valid, output wire mem_stall,
    
    // L1-I Cache Ports
    output wire [31:0] l1i_addr, output wire l1i_req,
    input wire [31:0] l1i_data, input wire l1i_ready,
   
    // L1-D Cache Ports
    output wire [31:0] l1d_addr, output wire [31:0] l1d_wdata,
    output wire l1d_req, output wire l1d_we, output wire [3:0] l1d_be,
    input wire [31:0] l1d_rdata, input wire l1d_ready,
    
    output reg [31:0] total_stall_cycles
);

    reg if_serviced, mem_serviced;
    reg [31:0] saved_if_instruction, saved_mem_rdata;
    
    assign if_stall = if_req && !if_serviced && !l1i_ready;
    assign mem_stall = mem_req && !mem_serviced && !l1d_ready;
    
    wire pipeline_advancing = !(if_stall || mem_stall);
    
    assign l1i_req = if_req && !if_serviced;
    assign l1i_addr = if_pc;
    
    assign l1d_req = mem_req && !mem_serviced;
    assign l1d_addr = mem_addr;
    assign l1d_wdata = mem_wdata;
    assign l1d_we = mem_we;
    assign l1d_be = mem_be;
    
    // ✅ CRITICAL FIX: Combinational bypass feeds data directly to pipeline forwarding
    assign if_instruction = l1i_ready ? l1i_data : saved_if_instruction;
    assign mem_rdata = l1d_ready ? l1d_rdata : saved_mem_rdata;
    
    assign if_valid = if_serviced || l1i_ready;
    assign mem_valid = mem_serviced || l1d_ready;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            if_serviced <= 0;
            mem_serviced <= 0;
            saved_if_instruction <= 32'h00000013; // NOP
            saved_mem_rdata <= 0;
            total_stall_cycles <= 0;
        end else begin
            if (if_stall || mem_stall) total_stall_cycles <= total_stall_cycles + 1;
            
            // Save data for when the pipeline isn't advancing yet
            if (l1i_ready) saved_if_instruction <= l1i_data;
            if (l1d_ready) saved_mem_rdata <= l1d_rdata;
            
            if (pipeline_advancing) begin
                if_serviced <= 0;
                mem_serviced <= 0;
            end else begin
                if (l1i_ready) if_serviced <= 1;
                if (l1d_ready) mem_serviced <= 1;
            end
        end
    end
endmodule