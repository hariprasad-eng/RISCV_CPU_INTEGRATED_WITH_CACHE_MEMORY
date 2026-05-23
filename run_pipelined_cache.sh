#!/bin/bash

echo "Compiling Fixed Pipelined CPU with Cache..."

iverilog -g2012 -o pipelined_cache.vvp \
    PipelinedCPU.v \
    cache_interface_controller.v \
    riscv_cache_system.v \
    l1_icache.v \
    l1_dcache.v \
    l2_cache.v \
    main_memory.v \
    cache_controller.v \
    PC.v \
    reg1.v reg2.v reg3.v reg4.v \
    Control.v \
    ALU.v ALUCtrl.v \
    Register.v \
    ImmGen.v \
    HazardDetection.v \
    ForwardingUnit.v \
    Adder.v \
    Mux2to1.v \
    ShiftLeftOne.v \
    riscv_nocache_system.v\
    tb_pipelined_cache.v

if [ $? -eq 0 ]; then
    echo "✅ Compilation successful!"
    vvp pipelined_cache.vvp
else
    echo "❌ Compilation failed!"
    exit 1
fi