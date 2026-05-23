
module PipelinedCPU #(
    parameter USE_CACHE = 1 // 1 = Cache System, 0 = Raw Memory System
)(
    input clk, rst,
    output [31:0] debug_pc, debug_instruction, debug_alu_result, debug_mem_data, debug_wb_data,
    output [4:0] debug_wb_addr, output debug_wb_enable,
    output [31:0] total_cycles, total_stalls, l1i_hits, l1i_misses, l1d_hits, l1d_misses, l2_hits, l2_misses,
    output halted // Lets the testbench know when to stop perfectly!
);
    wire [31:0] if_pc, if_instruction;
    wire if_stall_cache;
    
    wire [31:0] id_pc, id_instruction, id_read_data1, id_read_data2, id_imm;
    wire [4:0] id_rs1, id_rs2, id_rd;
    wire id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg, id_alu_src, id_branch;
    wire [1:0] id_alu_op;
    wire id_stall_hazard, id_flush;
    
    wire [31:0] ex_pc, ex_read_data1, ex_read_data2, ex_imm;
    wire [4:0] ex_rs1, ex_rs2, ex_rd;
    wire [6:0] ex_funct7;
    wire [2:0] ex_funct3;
    wire ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg, ex_alu_src, ex_branch;
    wire [1:0] ex_alu_op;
    wire [31:0] ex_alu_input1, ex_alu_input2, ex_alu_result, ex_forward_a_data, ex_forward_b_data;
    wire ex_zero, ex_branch_taken;
    wire [3:0] ex_alu_control;
    wire [1:0] ex_forward_a, ex_forward_b;
    
    wire [31:0] mem_alu_result, mem_write_data, mem_read_data;
    wire [4:0] mem_rd;
    wire mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg, mem_stall_cache;
    
    wire [31:0] wb_alu_result, wb_mem_data, wb_write_data;
    wire [4:0] wb_rd;
    wire wb_reg_write, wb_mem_to_reg;
    
    assign id_flush = ex_branch_taken;
    
    // Hardware Freeze Logic
    wire halt_detected = (id_instruction == 32'h00000063);
    reg halted_reg;
    always @(posedge clk or posedge rst) begin
        if (rst) halted_reg <= 0;
        else if (halt_detected) halted_reg <= 1;
    end
    assign halted = halted_reg;

    wire [31:0] l1i_addr, l1i_data, l1d_addr, l1d_wdata, l1d_rdata;
    wire l1i_req, l1i_ready, l1d_req, l1d_we, l1d_ready;
    wire [3:0] l1d_be;

    // ✅ DYNAMIC STALL ROUTING: Forces the pipeline to respect the No-Cache 5-cycle delays
    wire real_if_stall = (USE_CACHE == 1) ? if_stall_cache : ~l1i_ready;
    wire real_mem_stall = (USE_CACHE == 1) ? mem_stall_cache : (~l1d_ready && (mem_mem_read || mem_mem_write));
    wire cache_stall = real_if_stall || real_mem_stall;
                         
    wire pc_if_id_stall = cache_stall || id_stall_hazard || halted_reg;
    
    assign debug_pc = if_pc; assign debug_instruction = id_instruction; assign debug_alu_result = ex_alu_result;
    assign debug_mem_data = mem_read_data; assign debug_wb_data = wb_write_data;
    assign debug_wb_addr = wb_rd; assign debug_wb_enable = wb_reg_write;
    
    reg [31:0] cycle_counter, stall_counter;
    always @(posedge clk or posedge rst) begin
        if (rst) begin cycle_counter <= 0; stall_counter <= 0; end 
        else if (!halted_reg) begin
            cycle_counter <= cycle_counter + 1;
            if (pc_if_id_stall) stall_counter <= stall_counter + 1;
        end
    end
    assign total_cycles = cycle_counter; assign total_stalls = stall_counter;
    
    cache_interface_controller cache_ctrl(
        .clk(clk), .rst(rst),
        .if_pc(if_pc), .if_req(~id_flush && ~halted_reg),
        .if_instruction(if_instruction), .if_valid(), .if_stall(if_stall_cache),
        .mem_addr(mem_alu_result), .mem_wdata(mem_write_data),
        .mem_req(mem_mem_read || mem_mem_write), .mem_we(mem_mem_write), .mem_be(4'b1111),
        .mem_rdata(mem_read_data), .mem_valid(), .mem_stall(mem_stall_cache),
        .l1i_addr(l1i_addr), .l1i_req(l1i_req), .l1i_data(l1i_data), .l1i_ready(l1i_ready),
        .l1d_addr(l1d_addr), .l1d_wdata(l1d_wdata), .l1d_req(l1d_req), .l1d_we(l1d_we),
        .l1d_be(l1d_be), .l1d_rdata(l1d_rdata), .l1d_ready(l1d_ready), .total_stall_cycles()
    );
    
    // ✅ CONDITIONAL MEMORY ARCHITECTURE
    generate
        if (USE_CACHE == 1) begin : mem_block
            riscv_cache_system cache_sys(
                .clk(clk), .rst(rst), .pc(l1i_addr), .instr_req(l1i_req),
                .instruction(l1i_data), .instr_ready(l1i_ready), .data_addr(l1d_addr), .data_wdata(l1d_wdata),
                .data_req(l1d_req), .data_we(l1d_we), .data_be(l1d_be), .data_rdata(l1d_rdata), .data_ready(l1d_ready),
                .l1i_hit_count(l1i_hits), .l1i_miss_count(l1i_misses), .l1d_hit_count(l1d_hits), .l1d_miss_count(l1d_misses),
                .l2_hit_count(l2_hits), .l2_miss_count(l2_misses), .l1d_writeback_count(), .l2_writeback_count(), .total_cycles()
            );
        end else begin : mem_block
            riscv_nocache_system cache_sys(
                .clk(clk), .rst(rst), .pc(l1i_addr), .instr_req(l1i_req),
                .instruction(l1i_data), .instr_ready(l1i_ready), .data_addr(l1d_addr), .data_wdata(l1d_wdata),
                .data_req(l1d_req), .data_we(l1d_we), .data_be(l1d_be), .data_rdata(l1d_rdata), .data_ready(l1d_ready),
                .l1i_hit_count(l1i_hits), .l1i_miss_count(l1i_misses), .l1d_hit_count(l1d_hits), .l1d_miss_count(l1d_misses),
                .l2_hit_count(l2_hits), .l2_miss_count(l2_misses), .l1d_writeback_count(), .l2_writeback_count(), .total_cycles()
            );
        end
    endgenerate

    PC pc_module(.clk(clk), .rst(rst), .pc_enable(~pc_if_id_stall), .branch(ex_branch_taken), .branch_addr(ex_alu_result), .pc(if_pc));
    reg1 if_id_reg(.clk(clk), .rst(rst || id_flush), .stall(pc_if_id_stall), .pc_in(if_pc), .instruction_in(if_instruction), .pc_out(id_pc), .instruction_out(id_instruction));

    assign id_rs1 = id_instruction[19:15]; assign id_rs2 = id_instruction[24:20]; assign id_rd = id_instruction[11:7];

    Control control_unit(.opcode(id_instruction[6:0]), .regWrite(id_reg_write), .memRead(id_mem_read),
        .memWrite(id_mem_write), .memtoReg(id_mem_to_reg), .ALUSrc(id_alu_src), .branch(id_branch), .ALUOp(id_alu_op));

    Register register_file(.clk(clk), .rst(rst), .read_reg1(id_rs1), .read_reg2(id_rs2), .write_reg(wb_rd),
        .write_data(wb_write_data), .reg_write(wb_reg_write), .read_data1(id_read_data1), .read_data2(id_read_data2));
    
    ImmGen imm_gen(.inst(id_instruction), .imm_out(id_imm));

    wire [31:0] id_bypassed_data1 = (wb_reg_write && (wb_rd != 0) && (wb_rd == id_rs1)) ? wb_write_data : id_read_data1;
    wire [31:0] id_bypassed_data2 = (wb_reg_write && (wb_rd != 0) && (wb_rd == id_rs2)) ? wb_write_data : id_read_data2;

    HazardDetection hazard_unit(.id_rs1(id_rs1), .id_rs2(id_rs2), .id_ex_rd(ex_rd), .id_ex_mem_read(ex_mem_read), .stall(id_stall_hazard));
    
    reg2 id_ex_reg(.clk(clk), .rst(rst || id_flush), .stall(cache_stall), .pc_in(id_pc), 
        .read_data1_in(id_bypassed_data1), .read_data2_in(id_bypassed_data2), 
        .imm_in(id_imm), .rs1_in(id_rs1), .rs2_in(id_rs2), .rd_in(id_rd),
        .funct7_in(id_instruction[31:25]), .funct3_in(id_instruction[14:12]),
        .reg_write_in(id_stall_hazard ? 1'b0 : id_reg_write), 
        .mem_read_in(id_stall_hazard ? 1'b0 : id_mem_read),
        .mem_write_in(id_stall_hazard ? 1'b0 : id_mem_write), 
        .mem_to_reg_in(id_mem_to_reg), .alu_src_in(id_alu_src),
        .branch_in(id_branch), .alu_op_in(id_alu_op), .pc_out(ex_pc), .read_data1_out(ex_read_data1),
        .read_data2_out(ex_read_data2), .imm_out(ex_imm), .rs1_out(ex_rs1), .rs2_out(ex_rs2), .rd_out(ex_rd),
        .funct7_out(ex_funct7), .funct3_out(ex_funct3), .reg_write_out(ex_reg_write), .mem_read_out(ex_mem_read),
        .mem_write_out(ex_mem_write), .mem_to_reg_out(ex_mem_to_reg), .alu_src_out(ex_alu_src),
        .branch_out(ex_branch), .alu_op_out(ex_alu_op));

    ForwardingUnit forwarding_unit(.ex_rs1(ex_rs1), .ex_rs2(ex_rs2), .ex_mem_rd(mem_rd), .mem_wb_rd(wb_rd),
        .ex_mem_reg_write(mem_reg_write), .mem_wb_reg_write(wb_reg_write), .forward_a(ex_forward_a), .forward_b(ex_forward_b));

    wire [31:0] mem_forward_data = mem_mem_to_reg ? mem_read_data : mem_alu_result;
    
    Mux3to1 alu_input1_mux(.sel(ex_forward_a), .in0(ex_read_data1), .in1(wb_write_data), .in2(mem_forward_data), .out(ex_forward_a_data));
    assign ex_alu_input1 = ex_forward_a_data;
    
    Mux3to1 forward_b_mux(.sel(ex_forward_b), .in0(ex_read_data2), .in1(wb_write_data), .in2(mem_forward_data), .out(ex_forward_b_data));
    
    Mux2to1 alu_input2_mux(.sel(ex_alu_src), .s0(ex_forward_b_data), .s1(ex_imm), .out(ex_alu_input2));
    ALUCtrl alu_control(.alu_op(ex_alu_op), .funct7(ex_funct7[5]), .funct3(ex_funct3), .alu_control(ex_alu_control));
    ALU alu(.A(ex_alu_input1), .B(ex_alu_input2), .ALUCtl(ex_alu_control), .ALUOut(ex_alu_result), .zero(ex_zero));

    assign ex_branch_taken = ex_branch && ex_zero;
    
    reg3 ex_mem_reg(.clk(clk), .rst(rst), .stall(cache_stall), .alu_result_in(ex_alu_result), .write_data_in(ex_forward_b_data),
        .rd_in(ex_rd), .reg_write_in(ex_reg_write), .mem_read_in(ex_mem_read), .mem_write_in(ex_mem_write),
        .mem_to_reg_in(ex_mem_to_reg), .alu_result_out(mem_alu_result), .write_data_out(mem_write_data), .rd_out(mem_rd),
        .reg_write_out(mem_reg_write), .mem_read_out(mem_mem_read), .mem_write_out(mem_mem_write), .mem_to_reg_out(mem_mem_to_reg));

    reg4 mem_wb_reg(.clk(clk), .rst(rst), .stall(cache_stall), .alu_result_in(mem_alu_result), .mem_data_in(mem_read_data), .rd_in(mem_rd),
        .reg_write_in(mem_reg_write), .mem_to_reg_in(mem_mem_to_reg), .alu_result_out(wb_alu_result), .mem_data_out(wb_mem_data),
        .rd_out(wb_rd), .reg_write_out(wb_reg_write), .mem_to_reg_out(wb_mem_to_reg));

    Mux2to1 wb_mux(.sel(wb_mem_to_reg), .s0(wb_alu_result), .s1(wb_mem_data), .out(wb_write_data));
endmodule

module Mux3to1(input [1:0] sel, input [31:0] in0, in1, in2, output reg [31:0] out);
    always @(*) case(sel) 2'b00: out=in0; 2'b01: out=in1; 2'b10: out=in2; default: out=in0; endcase
endmodule



