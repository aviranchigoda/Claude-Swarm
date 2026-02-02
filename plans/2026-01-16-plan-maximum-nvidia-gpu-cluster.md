# Plan: Maximum NVIDIA GPU Cluster Analysis (max-setupE.md)

## Objective
Create a comprehensive hardware analysis document (`max-setupE.md`) detailing the most powerful NVIDIA GPU cluster configuration possible with AUD $8,000 cash budget (assuming the $3,900 Apple gift card was converted to cash), integrated with the existing M2 MacBook Pro.

## Key Findings from Analysis

### Budget Context
- **Original setup files** allocated: $4,443 cash + $3,900 Apple gift card
- **New scenario**: $8,000 AUD pure cash (no Apple constraint)
- **Freed from Apple ecosystem**: Can maximize NVIDIA GPU investment

### Codebase Compute Requirements Discovered
| Parameter | Value | Impact on GPU Selection |
|-----------|-------|------------------------|
| Hot path latency target | <500ns | CPU-bound, not GPU |
| ML inference budget | ~350ns | TensorRT for off-path |
| Arena memory | 4GB hugepages | System RAM requirement |
| Max strategies | 32 | Parallel model training |
| Max symbols | 8,192 | Feature dimension scaling |
| Signal history | 64 samples/symbol | Training data volume |
| Training workloads | Custom signal models | VRAM is bottleneck |

## Recommended Configuration: Triple RTX 3090 (72GB VRAM)

### Why Triple RTX 3090 > Dual RTX 4090 for $8,000
| Metric | Triple RTX 3090 | Dual RTX 4090 |
|--------|-----------------|---------------|
| Total VRAM | **72GB** | 48GB |
| Cost (used GPUs) | ~$4,200 | ~$5,600 |
| Tensor TFLOPS (total) | ~426 TFLOPS FP16 | ~660 TFLOPS FP16 |
| Memory bandwidth | 2,808 GB/s | 2,016 GB/s |
| Max trainable model | **70B FP16** | 30B FP16 |
| Budget remaining | ~$3,800 | ~$2,400 |

**Verdict**: Triple RTX 3090 wins on VRAM (critical for training large models)

## Hardware Bill of Materials

### GPU Cluster Build (~$7,450)
| Component | Model | Price (AUD) | Purpose |
|-----------|-------|-------------|---------|
| GPU x3 | RTX 3090 24GB (used) | $4,200 | 72GB combined VRAM |
| CPU | AMD Ryzen 9 5950X (16C/32T) | $550 | Data preprocessing |
| Motherboard | ASUS ProArt X570-Creator WiFi | $550 | 3x PCIe x8 (electrical) |
| RAM | 128GB DDR4-3600 (4x32GB) | $420 | Layer offloading |
| Storage | 4TB NVMe Gen4 | $400 | Models + datasets |
| PSU | Corsair AX1600i | $650 | 1600W for 3x 350W GPUs |
| Case | Phanteks Enthoo Pro 2 | $250 | Triple GPU clearance |
| Cooling | 3x GPU + Noctua NH-D15 | $300 | Thermal management |
| 10GbE NIC | Intel X520-DA1 + DAC | $130 | M2 MacBook integration |
| **TOTAL** | | **$7,450** | |

### Remaining Budget
- **$550** for contingency, cables, peripherals

## Compute Specifications Table

### Raw Compute Power
| Metric | Single RTX 3090 | Triple RTX 3090 Cluster |
|--------|-----------------|------------------------|
| CUDA Cores | 10,496 | 31,488 |
| Tensor Cores | 328 | 984 |
| FP32 TFLOPS | 35.6 | 106.8 |
| FP16 TFLOPS | 142 | 426 |
| INT8 TOPS | 284 | 852 |
| Memory | 24GB GDDR6X | 72GB GDDR6X |
| Memory BW | 936 GB/s | 2,808 GB/s |
| TDP | 350W | 1,050W |

### Training Capability
| Model Size | Precision | Fits in 72GB? | Training Speed |
|------------|-----------|---------------|----------------|
| Llama 3.1 8B | FP16 | Yes (16GB) | ~100 tok/s |
| Llama 3.1 70B | FP16 | Yes (140GB via offload) | ~10 tok/s |
| Llama 3.1 70B | 4-bit | Yes (35GB) | ~30 tok/s |
| Custom Trading | FP32 | Yes (<1GB) | >100k samples/s |

### Inference Performance (TensorRT Optimized)
| Model Type | Latency | Throughput |
|------------|---------|------------|
| Trading signal (1KB) | <100μs | >10,000/s |
| 7B LLM (FP16) | ~30ms/tok | ~33 tok/s |
| 70B LLM (4-bit) | ~100ms/tok | ~10 tok/s |

## Integration Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    MAXIMUM POWER NVIDIA CLUSTER ($8,000 AUD)           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │              TRIPLE RTX 3090 LINUX WORKSTATION                     │ │
│  │                                                                    │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐             │ │
│  │  │ RTX 3090 #0  │  │ RTX 3090 #1  │  │ RTX 3090 #2  │             │ │
│  │  │ 24GB GDDR6X  │  │ 24GB GDDR6X  │  │ 24GB GDDR6X  │             │ │
│  │  │ PCIe x8 Slot │  │ PCIe x8 Slot │  │ PCIe x8 Slot │             │ │
│  │  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘             │ │
│  │         │                 │                 │                      │ │
│  │         └─────────────────┼─────────────────┘                      │ │
│  │                           │                                        │ │
│  │                    ┌──────┴──────┐                                 │ │
│  │                    │  NCCL/CUDA  │ 3-way tensor parallelism        │ │
│  │                    └─────────────┘                                 │ │
│  │                                                                    │ │
│  │  Capabilities:                                                     │ │
│  │  • 72GB total VRAM (largest model training possible)               │ │
│  │  • 426 TFLOPS FP16 tensor compute                                  │ │
│  │  • 2.8 TB/s aggregate memory bandwidth                             │ │
│  │  • TensorRT: <100μs trading signal inference                       │ │
│  │  • Full Linux kernel control (isolcpus, hugepages, io_uring)       │ │
│  └────────────────────────────────┬──────────────────────────────────┘ │
│                                   │ 10GbE (1.25 GB/s)                   │
│                                   │                                     │
│  ┌────────────────────────────────┴──────────────────────────────────┐ │
│  │                    M2 MACBOOK PRO (ORCHESTRATOR)                   │ │
│  │                                                                    │ │
│  │  • Code development (VSCode, Claude Code)                          │ │
│  │  • Model deployment scripts                                        │ │
│  │  • SSH + API gateway to GPU cluster                                │ │
│  │  • Lightweight MLX inference (supplementary)                       │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

## Document Structure for max-setupE.md

1. **Executive Summary** - The answer: Triple RTX 3090 cluster
2. **Budget Analysis** - $8,000 allocation breakdown
3. **Hardware Specifications** - Complete BOM with prices
4. **Compute Performance Tables** - All FLOPS, bandwidth, latency figures
5. **Training Capability Matrix** - What models can be trained
6. **Inference Performance** - TensorRT optimizations for trading
7. **Integration with Trading Codebase** - Unix socket interface, signal structures
8. **Power & Thermal Engineering** - 1600W PSU, cooling requirements
9. **Network Architecture** - 10GbE integration with M2 MacBook
10. **Software Stack** - CUDA 12.6, PyTorch, vLLM, TensorRT
11. **Comparison Tables** - Triple 3090 vs Dual 4090 vs Dual 3090
12. **Verification Steps** - How to validate the build

## Files to Create
- `/Users/aviranchigoda/Desktop/software/trading/max-setupE.md`

## Verification
- Document completeness check against codebase requirements
- All compute figures validated against NVIDIA specifications
- Budget totals verified within $8,000 limit
