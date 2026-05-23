module HazardDetection(
    input [4:0] id_rs1, id_rs2,
    input [4:0] id_ex_rd,
    input id_ex_mem_read,
    output stall
);
    // Stall if: EX stage has a LOAD instruction AND current instruction uses its result
    assign stall = id_ex_mem_read && (id_ex_rd != 0) && 
                   ((id_ex_rd == id_rs1) || (id_ex_rd == id_rs2));
endmodule