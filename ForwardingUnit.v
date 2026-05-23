module ForwardingUnit(
    input [4:0] ex_rs1, ex_rs2, ex_mem_rd, mem_wb_rd,
    input ex_mem_reg_write, mem_wb_reg_write,
    output reg [1:0] forward_a, forward_b
);
    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;
        
        // EX Hazard
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == ex_rs1))
            forward_a = 2'b10;
        // MEM Hazard 
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == ex_rs1))
            forward_a = 2'b01;
            
        // EX Hazard
        if (ex_mem_reg_write && (ex_mem_rd != 0) && (ex_mem_rd == ex_rs2))
            forward_b = 2'b10;
        // MEM Hazard - THIS TYPO CAUSED x23 TO BE 21!
        else if (mem_wb_reg_write && (mem_wb_rd != 0) && (mem_wb_rd == ex_rs2))
            forward_b = 2'b01;
    end
endmodule