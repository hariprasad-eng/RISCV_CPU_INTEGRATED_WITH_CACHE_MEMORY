                //TESTBENCH 6:(ACTUAAL COMPARISON BETWEEN PROCESSOR AND PROCESSOR WITH CACHE)


`timescale 1ns/1ps

module tb_compare;

    reg clk, rst;
    
    // CPU 1: Cached Wires
    wire [31:0] cycles_c, stalls_c, l1i_hits, l1i_misses, l1d_hits, l1d_misses, l2_hits, l2_misses;
    wire halted_c;
    
    // CPU 2: No-Cache Wires
    wire [31:0] cycles_nc, stalls_nc;
    wire halted_nc;
    
    initial begin clk = 0; forever #5 clk = ~clk; end
    
    // ✅ Cached CPU Instance
    PipelinedCPU #(.USE_CACHE(1)) cpu_cached (
        .clk(clk), .rst(rst),
        .total_cycles(cycles_c), .total_stalls(stalls_c),
        .l1i_hits(l1i_hits), .l1i_misses(l1i_misses), .l1d_hits(l1d_hits), .l1d_misses(l1d_misses), .l2_hits(l2_hits), .l2_misses(l2_misses),
        .halted(halted_c)
    );
    
    // ✅ No-Cache CPU Instance
    PipelinedCPU #(.USE_CACHE(0)) cpu_nocache (
        .clk(clk), .rst(rst),
        .total_cycles(cycles_nc), .total_stalls(stalls_nc),
        .halted(halted_nc)
    );
    
    integer i;
    
    initial begin
        $dumpfile("compare.vcd");
        $dumpvars(0, tb_compare);
        
        // 1. CLEAR MEMORY
        for (i = 0; i < 2048; i = i + 1) begin
            cpu_cached.mem_block.cache_sys.main_memory_inst.memory[i] = 32'h00000013; 
            cpu_nocache.mem_block.cache_sys.memory[i]                 = 32'h00000013;
        end
        
        // 2. DYNAMICALLY LOAD THE .DAT FILE
        $readmemh("test.dat", cpu_cached.mem_block.cache_sys.main_memory_inst.memory);
        $readmemh("test.dat", cpu_nocache.mem_block.cache_sys.memory);
        
        $display("=========================================================");
        $display("RUNNING ABLATION STUDY: CACHE VS NO-CACHE");
        $display("=========================================================");
        
        rst = 1; 
        #25; 
        rst = 0;
    end

    // Drain counter to handle massive latencies
    reg [7:0] drain_counter;
    initial drain_counter = 0;

    always @(posedge clk) begin
        // Wait until BOTH processors decode the Halt instruction
        if (!rst && halted_c && halted_nc) begin
            drain_counter <= drain_counter + 1;
            
            if (drain_counter > 50) begin
                $display("\n=========================================================");
                $display("                  PERFORMANCE COMPARISON                 ");
                $display("=========================================================");
                $display("METRIC                 | CACHED CPU       | NO-CACHE CPU");
                $display("---------------------------------------------------------");
                $display("Total Execution Cycles | %-16d | %-16d", (cycles_c + 3), (cycles_nc + 3));
                $display("Total Pipeline Stalls  | %-16d | %-16d", stalls_c, stalls_nc);
                
                // Assuming ~55 retired instructions for the test
                $display("Calculated CPI         | %0d.%-14d | %0d.%-14d", 
                         (cycles_c + 3)/55, ((cycles_c + 3)*100/55)%100, 
                         (cycles_nc + 3)/55, ((cycles_nc + 3)*100/55)%100);
                         
                $display("Stall Percentage       | %0d%%               | %0d%%", 
                         (stalls_c * 100) / (cycles_c + 3), 
                         (stalls_nc * 100) / (cycles_nc + 3));
                         
                $display("\n=========================================================");
                $display("               REGISTER STATE COMPARISON                 ");
                $display("=========================================================");
                $display("REG | CACHED CPU         | NO-CACHE CPU       | MATCH?");
                $display("---------------------------------------------------------");
                for (i = 1; i < 32; i = i + 1) begin
                    
                        $display("x%-2d | %-18d | %-18d | %s",
                            i,
                            $signed(cpu_cached.register_file.registers[i]),
                            $signed(cpu_nocache.register_file.registers[i]),
                            (cpu_cached.register_file.registers[i] == cpu_nocache.register_file.registers[i]) ? "✅ YES" : "❌ NO"
                        );
                    
                end

                $display("\n=========================================================");
                $display("                    MEMORY SNAPSHOT                      ");
                $display("=========================================================");
                
                // Addr 500 = Word 125
                $display("MEM[125] (Base)    | CACHED: %-10d | NO-CACHE: %-10d", 
                    cpu_cached.mem_block.cache_sys.main_memory_inst.memory[125], 
                    cpu_nocache.mem_block.cache_sys.memory[125]);
                    
                // Addr 604 = Word 151
                $display("MEM[151] (Crossed) | CACHED: %-10d | NO-CACHE: %-10d", 
                    cpu_cached.mem_block.cache_sys.main_memory_inst.memory[151], 
                    cpu_nocache.mem_block.cache_sys.memory[151]);

                $display("\n=========================================================");
                $display("            CACHE ANALYTICS (Cached CPU Only)            ");
                $display("=========================================================");
                $display("L1-I Hits/Misses: %0d / %0d", l1i_hits, l1i_misses);
                $display("L1-D Hits/Misses: %0d / %0d", l1d_hits, l1d_misses);
                $display("L2   Hits/Misses: %0d / %0d", l2_hits, l2_misses);
                $display("=========================================================\n");
                
                $finish;
            end
        end
    end
endmodule