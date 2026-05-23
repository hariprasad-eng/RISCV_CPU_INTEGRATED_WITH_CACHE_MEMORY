# 🚀 High-Performance 5-Stage Pipelined RISC-V Processor with Multi-Level Cache

## 📌 Project Overview

This repository contains a cycle-accurate hardware implementation of a **32-bit RISC-V Processor** written in **Verilog HDL**.

The processor features:

- ✅ 5-Stage Instruction Pipeline
- ✅ Full Data Hazard Detection
- ✅ Data Forwarding Unit
- ✅ Multi-Level Cache Hierarchy (L1 Instruction Cache, L1 Data Cache, Unified L2 Cache)
- ✅ Comparative Cache vs No-Cache Performance Analysis

The primary objective of this project is to experimentally demonstrate the impact of the **von Neumann Bottleneck** and mathematically prove the importance of cache memory in modern processor architectures.

By dynamically switching between:

- **Cached Architecture**
- **Raw Memory (No-Cache) Architecture**

the processor performs a strict **Ablation Study** to analyze execution latency, stalls, CPI, and memory bottlenecks.

---

# 🏗️ Processor Architecture

## 🔹 5-Stage Pipeline

The processor implements the standard **RV32I** instruction pipeline:

| Stage | Description |
|---|---|
| **IF** | Instruction Fetch |
| **ID** | Instruction Decode & Register Read |
| **EX** | Execute / ALU Operations |
| **MEM** | Data Memory Access |
| **WB** | Register Write Back |

---

# ⚡ Hazard Mitigation & Forwarding

## 🔁 Forwarding Unit

The forwarding logic dynamically routes data from:

- EX/MEM pipeline registers
- MEM/WB pipeline registers

directly back into the ALU inputs to eliminate unnecessary stalls caused by **RAW (Read After Write) Hazards**.

---

## 🛑 Hazard Detection Unit

The Hazard Detection Unit detects:

- Load-Use Dependencies
- Pipeline Conflicts
- Unsafe Instruction Execution

and safely inserts **pipeline bubbles (NOPs)** whenever mathematically required.

---

# ⏱️ Latency Model (Cycle Breakdown)

To accurately measure the memory bottleneck, the processor enforces strict hardware cycle latencies.

The following stages execute in exactly **1 cycle**:

- Instruction Decode (ID)
- Execute (EX)
- Write Back (WB)

The IF and MEM stages interact with the memory hierarchy and therefore experience variable latency.

---

## 📊 Stage Latency Comparison

| Pipeline Stage | Cached CPU (Cache Hit) | No-Cache CPU (Raw Memory) |
|---|---|---|
| **Instruction Fetch (IF)** | **1 Cycle** | **5 Cycles** |
| **Instruction Decode (ID)** | 1 Cycle | 1 Cycle |
| **Execute (EX)** | 1 Cycle | 1 Cycle |
| **Memory Access (MEM)** | **1 Cycle** | **5 Cycles** |
| **Write Back (WB)** | 1 Cycle | 1 Cycle |

> **Note:**  
> The MEM stage incurs latency only for memory instructions (`LW` / `SW`).  
> Arithmetic instructions bypass memory access in a single cycle.

---

# 🧠 Cache Hierarchy

## 🔹 Cache Organization

The processor implements:

- **L1 Instruction Cache**
- **L1 Data Cache**
- **Unified L2 Cache**
- **Main Memory**

---

## 🔹 Cache Miss Penalties

| Access Type | Additional Penalty |
|---|---|
| **L1 Cache Hit** | 1 Cycle |
| **L2 Hit (After L1 Miss)** | +2 to 3 Cycles |
| **Main Memory Access** | +5 Cycles |

The cache controller automatically freezes and resumes the pipeline during cache miss servicing.

---

# 📊 Ablation Study — Proving the Cache

To evaluate the architecture, the processor was tested using a highly stressful RISC-V benchmark called:

# 🔥 “The Straight-Line Avalanche”

This benchmark heavily stresses:

- Load Instructions
- Store Instructions
- Forwarding Paths
- Hazard Logic
- Spatial Locality
- Temporal Locality

without using branch instructions.

---

# 📈 Final Performance Results

The benchmark retired a total of **55 Instructions**.

The No-Cache architecture suffered forced wait states for every memory access, while the Cached CPU absorbed most accesses using L1/L2 cache hits.

---

## 🏆 Performance Comparison

| Metric | Cached CPU (With L1/L2) | No-Cache CPU (Raw Memory) |
|---|---|---|
| **Total Execution Cycles** | **75** | **232** |
| **Total Pipeline Stalls** | **41** | **199** |
| **Calculated CPI** | **1.36** | **4.21** |
| **Stall Percentage** | **54%** | **85%** |

---

# 📉 Cache Analytics

## 🔹 L1 Instruction Cache

- **Hits:** 37
- **Misses:** 2
- **Hit Rate:** **94.8%**

---

## 🔹 L1 Data Cache

- **Hits:** 19
- **Misses:** 1
- **Hit Rate:** **95.0%**

---

## 🔹 Unified L2 Cache

- **Hits:** 3
- **Misses:** 3

---

# ✅ Final Conclusion

The cache hierarchy successfully absorbed the **von Neumann Bottleneck**.

By reducing memory access latency from **5 cycles** to effectively **1 cycle** for most accesses, the Cached CPU achieved:

- ✅ **Over 67% Reduction in Execution Time**
- ✅ CPI Improvement from **4.21 → 1.36**
- ✅ Massive Reduction in Pipeline Stalls
- ✅ Near-Ideal Pipeline Throughput

This experimentally proves the architectural necessity of cache memory in modern high-performance processors.

---

# 📂 Project File Structure

| File | Description |
|---|---|
| `PipelinedCPU.v` | Top-level processor module |
| `riscv_cache_system.v` | L1/L2 cache hierarchy implementation |
| `riscv_nocache_system.v` | Raw memory system with enforced latency |
| `tb_compare.v` | Comparative cache vs no-cache testbench |
| `HazardDetection.v` | Hazard detection logic |
| `ForwardingUnit.v` | Data forwarding logic |
| `test.dat` | RISC-V machine code benchmark |

---

# 🚀 Running the Simulation

## 🔹 Requirements

- **Icarus Verilog (iverilog)**
- **GTKWave** *(Optional for waveform viewing)*

---

## 1️⃣ Clone the Repository

```bash
git clone https://github.com/hariprasad-eng/RISCV_CPU_INTEGRATED_WITH_CACHE_MEMORY.git

cd RISCV_CPU_INTEGRATED_WITH_CACHE_MEMORY
```

---

## 2️⃣ Compile the Design

```bash
iverilog -o cpu_sim tb_compare.v PipelinedCPU.v riscv_cache_system.v riscv_nocache_system.v *.v
```

---

## 3️⃣ Run the Simulation

```bash
vvp cpu_sim
```

---

## 4️⃣ View Waveforms (Optional)

```bash
gtkwave compare.vcd
```

---

# 🛠️ Tools & Technologies Used

- Verilog HDL
- Icarus Verilog
- GTKWave
- RISC-V RV32I ISA
- Digital Logic Design
- Computer Architecture
- Pipeline Hazard Analysis
- Cache Memory Systems

---

# 🔮 Future Work

## ✅ Planned Improvements

- Branch Instructions (`BNE`, `BLT`, `BGE`)
- Dynamic Branch Prediction
- Branch History Table (BHT)
- FPGA Deployment
- Physical Timing Analysis
- Multi-Core Extension
- Superscalar Execution
- Out-of-Order Execution Support



---

# ⭐ Repository Highlights

- ✔️ Complete RV32I 5-Stage Pipeline
- ✔️ Fully Functional Hazard Logic
- ✔️ Cache vs No-Cache Comparative Study
- ✔️ Multi-Level Cache Hierarchy
- ✔️ Detailed CPI & Stall Analytics
- ✔️ Cycle-Accurate Verilog Simulation
- ✔️ Strong Demonstration of Computer Architecture Concepts

