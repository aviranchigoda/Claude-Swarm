# Plan: Maximum Power NVIDIA AI Cluster Analysis

## Summary

Analyzed setup-A.md through setup-F.md and the trading codebase to determine the optimal AI cluster configuration with **$8,000 AUD all-cash** (assuming the $3,900 Apple gift card was cash instead).

## Key Finding

**The Single Most Powerful Setup: Dual RTX 3090 24GB Linux Workstation**

This configuration provides:
- 48GB combined VRAM (tensor parallel)
- 1,872 GB/s memory bandwidth (6.9x faster than Mac Mini)
- 656 Tensor Cores for ML training and inference
- Full CUDA/TensorRT stack for <100μs trading signal inference
- Training capability (LoRA, QLoRA, custom models)

## Deliverable Created

**File**: `/Users/aviranchigoda/Desktop/software/trading/max-setupA.md`

Contains:
1. Complete hardware specification with AUD pricing
2. GPU compute specifications table (CUDA cores, Tensor cores, VRAM, bandwidth)
3. VRAM capacity analysis (what models fit in 48GB)
4. Training VRAM requirements table
5. CPU specifications (Ryzen 9 5950X)
6. Memory bandwidth hierarchy
7. Power consumption analysis (1,015W peak, 1500W PSU)
8. Thermal engineering design
9. 10GbE network topology
10. Software stack (CUDA 12.6, PyTorch, vLLM, TensorRT)
11. Integration with trading codebase (Unix socket interface, <100μs latency target)
12. Comparison: All-cash dual 3090 vs hybrid Mac+3090
13. Upgrade paths (third GPU, 4090 migration)
14. Implementation timeline

## Budget Summary

| Component | Price (AUD) |
|-----------|-------------|
| 2x RTX 3090 24GB (used) | $3,000 |
| Ryzen 9 5950X | $550 |
| ASUS ROG Crosshair VIII | $350 |
| 128GB DDR4-3600 | $450 |
| 5TB NVMe storage | $630 |
| 1500W PSU | $450 |
| Case + Cooling | $590 |
| 10GbE + UPS | $490 |
| **Total** | **$6,360** |
| **Remaining** | **$1,640** |

## Why Dual RTX 3090 > Mac Mini M4 Pro + RTX 3090

1. **55% more memory bandwidth** (1,872 vs 1,209 GB/s)
2. **True training capability** on 48GB tensor-parallel
3. **TensorRT <100μs inference** for trading signals (impossible on Apple)
4. **Single unified stack** (Linux/CUDA vs macOS/MLX + Linux/CUDA)
5. **Clear upgrade path** to 72GB with third GPU

## Verification

- Run `nvidia-smi` - both GPUs detected
- Run vLLM with `--tensor-parallel-size 2`
- Benchmark TensorRT inference <100μs
- Test 10GbE throughput: 9.4+ Gbps
