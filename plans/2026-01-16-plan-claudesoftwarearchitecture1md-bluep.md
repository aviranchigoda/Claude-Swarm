# Plan: Claude-Software-Architecture1.md Blueprint

## Executive Summary

After exhaustive analysis of Claude-Engineering1.md, the **optimal architecture for maximum low-level control** is a **Hybrid FPGA + Kernel-Bypass Architecture** achieving **<500ns wire-to-wire latency**.

### Control Depth Hierarchy (Analysis Result)

| Level | Technology | Latency | Control Depth | Selected |
|-------|-----------|---------|---------------|----------|
| 0 | ASIC (Custom Silicon) | 50-200ns | Absolute | No (impractical) |
| 1 | **FPGA** | 100-500ns | Near-absolute | **YES** |
| 2 | **Kernel Bypass (ef_vi/DPDK)** | 500ns-2μs | Very High | **YES** |
| 3 | **Optimized C17/Rust** | 2-10μs | High | **YES** |
| 4 | JVM/CLR | 10-50μs | Medium | No |
| 5 | Interpreted | 100+μs | Low | No |

---

## Architecture Blueprint Structure

The Claude-Software-Architecture1.md document (~60,000 words) will contain:

### Layer 0: FPGA Hardware Layer
**Why FPGA = Deepest Control**: You define actual logic gates, not instructions
- **MAC/PHY Interface**: Integrated 10G/25G SerDes, cut-through processing
- **Hardware Timestamping**: GPS-disciplined, <50ns accuracy to UTC
- **DMA Engine**: Scatter/gather, PCIe Gen4 x16, 64-byte cache-line writes
- **Latency Budget**: 289ns target, 380ns worst-case

**Key Code**: Verilog modules for market data parser, order generator, timestamp capture

### Layer 1: Protocol Processing
- **FPGA Parsing**: ITCH 5.0, OUCH binary - single cycle per field
- **CAM-Based Symbol Filter**: 256 symbols, parallel comparison
- **CPU SIMD Parsing**: AVX-512 field extraction (~20ns per message)
- **Latency Budget**: 60ns target, 95ns worst-case

**Key Code**: Verilog protocol FSM, C SIMD parser with shuffle masks

### Layer 2: Kernel Bypass Network Interface
**Primary Choice**: ef_vi (Solarflare) for production (~100ns to userspace)
**Alternative**: DPDK for multi-vendor flexibility (~200-500ns)

- **Poll-Mode Driver**: Dedicated CPU core, 100% utilization, no interrupts
- **Memory Registration**: Hugepage DMA buffers, pre-allocated pools
- **Zero-Copy Architecture**: Direct NIC to application memory path
- **Latency Budget**: 125ns target, 200ns worst-case

**Key Code**: ef_vi initialization, poll loop, buffer management

### Layer 3: Core Trading Engine
- **Order Book**: Array-based, 16-byte price levels, L1 cache resident
- **Lock-Free IPC**: SPSC queues with memory barriers
- **Cache Optimization**: Structure-of-Arrays, cache-line alignment, false sharing prevention
- **SIMD Processing**: Batch mid-price calculation, spread screening
- **Latency Budget**: 65ns target, 115ns worst-case

**Key Code**: Order book structure, SPSC queue, AVX-512 batch operations

### Layer 4: Strategy Execution
**Core Principle**: Eliminate ALL branches in hot path

- **Branch-Free Arithmetic**: Comparison as integer (0/1), arithmetic selection
- **Lookup Tables**: Pre-computed signals, order sizes, price offsets
- **Compile-Time Strategy Selection**: Function pointers, indirect call dispatch
- **Latency Budget**: 45ns target, 75ns worst-case

**Key Code**: Branch-free decision logic, signal generation pipeline

### Layer 5: Risk Engine
- **Risk Checks**: Branch-free limit validation (<30ns)
- **Hardware Kill Switch**: Memory-mapped FPGA register (0xDEAD trigger)
- **Lock-Free Position Tracking**: Atomic operations, CAS for concurrent fills
- **Latency Budget**: 65ns target, 110ns worst-case

**Key Code**: Risk check function, kill switch integration, position tracker

### Layer 6: Management Plane
**Strict Separation**: Cold path on separate NUMA node (cores 6-11)

- **Configuration Injection**: Double-buffered configs, atomic pointer swap
- **Telemetry Extraction**: Lock-free ring buffer, async export
- **Hot Path Impact**: 25ns target, 40ns worst-case

---

## Memory Architecture

```
NUMA Node 0 (Hot Path)          NUMA Node 1 (Cold Path)
├── Cores 2-5                   ├── Cores 6-11
├── Order books                 ├── Config buffers
├── Position state              ├── Log buffers
├── Ring buffers                ├── Metrics
├── DMA regions (1GB hugepages) └── REST API
└── 75% L3 cache (Intel CAT)
```

**Key Patterns**:
- 2MB/1GB hugepages for TLB efficiency
- Pre-allocation at startup (zero malloc in hot path)
- Intel CAT for L3 cache partitioning

---

## CPU Architecture

```
Core 0: Reserved (OS housekeeping)
Core 1: IRQ Handling (all interrupts steered here)
Core 2: Market Data (poll-mode, 100% utilization)
Core 3: Strategy Engine (spinning on queue)
Core 4: Risk Engine (pre-trade checks)
Core 5: Order Gateway (TX completion polling)
Cores 6-11: Management Plane (normal scheduling)
```

**Kernel Parameters**:
```
isolcpus=2-5 nohz_full=2-5 rcu_nocbs=2-5
processor.max_cstate=0 intel_idle.max_cstate=0 idle=poll
nosoftlockup transparent_hugepage=never
```

---

## Wire-to-Wire Latency Budget Summary

| Layer | Component | Target | Worst Case |
|-------|-----------|--------|------------|
| 0 | FPGA/Hardware | 289ns | 380ns |
| 1 | Protocol Processing | 60ns | 95ns |
| 2 | Kernel Bypass | 125ns | 200ns |
| 3 | Trading Engine | 65ns | 115ns |
| 4 | Strategy Execution | 45ns | 75ns |
| 5 | Risk Engine | 65ns | 110ns |
| 6 | Management Overhead | 25ns | 40ns |
| **Total Inbound** | | **399ns** | **635ns** |
| Outbound TX | | 100ns | 150ns |
| **TOTAL WIRE-TO-WIRE** | | **~500ns** | **~785ns** |

---

## Document Sections (Claude-Software-Architecture1.md)

1. **Executive Architecture Summary** (~2,000 words)
2. **Layer 0: FPGA Hardware** (~8,000 words + Verilog)
3. **Layer 1: Protocol Processing** (~6,000 words + C/Verilog)
4. **Layer 2: Kernel Bypass** (~7,000 words + C)
5. **Layer 3: Core Engine** (~8,000 words + C)
6. **Layer 4: Strategy Execution** (~5,000 words + C)
7. **Layer 5: Risk Engine** (~5,000 words + C)
8. **Layer 6: Management Plane** (~4,000 words + C)
9. **Memory Architecture** (~6,000 words)
10. **CPU Architecture** (~4,000 words + kernel config)
11. **Build & Compilation** (~3,000 words)
12. **Testing & Verification** (~3,000 words)
13. **Compliance & Audit Trail** (~3,000 words)

**Total**: ~60,000 words with complete code examples

---

## Verification Plan

After writing the document:
1. Validate all code examples compile conceptually
2. Cross-reference latency budgets with Claude-Engineering1.md
3. Verify FPGA timing constraints are realistic
4. Ensure memory layouts match cache line sizes

---

## Files to Create

| File | Purpose |
|------|---------|
| `/Users/aviranchigoda/Desktop/software/trading/Claude-Software-Architecture1.md` | Complete architecture blueprint |

---

## Key Design Decisions Resolved

| Decision | Choice | Rationale |
|----------|--------|-----------|
| FPGA vs Pure Software | Hybrid | FPGA for determinism, CPU for flexibility |
| Kernel Bypass | ef_vi primary, DPDK backup | ef_vi is lowest latency |
| Hot Path Language | C17 | Maximum control, predictable codegen |
| Memory Strategy | Hugepages + pre-allocation | Zero malloc in hot path |
| IPC | Lock-free SPSC | Bounded latency, no contention |
