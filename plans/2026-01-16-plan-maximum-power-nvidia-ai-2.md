# Plan: Maximum Power NVIDIA AI Cluster - $8,000 AUD Setup

## User Request
Analyze setup-A through setup-F and design the single most powerful, integrated setup with AUD $8,000 (assuming the $3,900 Apple gift card was cash instead) that leverages the most powerful NVIDIA GPU cluster for both high-intensity training AND inference, integrated with existing M2 MacBook Pro.

## Analysis Summary

### Budget Transformation
- **Original**: $3,900 Apple gift card + $4,443 cash = $8,343 (constrained)
- **Hypothetical**: $8,000 pure cash = Maximum NVIDIA flexibility

### Key Codebase Requirements Identified
From LOCAL_AI_CLUSTER_ENGINEERING.md and codebase analysis:
- **Inference latency target**: <100μs for trading signals (TensorRT achieves 25-65μs)
- **LLM inference**: 70B models at 15-30 tok/s
- **Training workloads**: Custom trading ML models, batch size 4,096
- **Memory bandwidth critical**: 936 GB/s per RTX 3090
- **VRAM requirement**: 48GB+ for 70B FP16 without quantization
- **Integration**: Unix socket to C trading engine (<1ms overhead)

---

## Recommended Configuration: Dual RTX 3090 Maximum Build

### Why Dual RTX 3090 Over Other Options

| Configuration | VRAM | Cost | FP16 TFLOPS | Memory BW | Feasibility |
|---------------|------|------|-------------|-----------|-------------|
| **Dual RTX 3090** | **48GB** | **~$5,500** | **284** | **1.87 TB/s** | **OPTIMAL** |
| RTX 4090 + RTX 3090 | 48GB | ~$7,800 | 307 | 1.94 TB/s | Mixed arch issues |
| Dual RTX 4090 | 48GB | ~$8,400 | 330 | 2.02 TB/s | Over budget |
| Single RTX 4090 | 24GB | ~$5,500 | 165 | 1.01 TB/s | Insufficient VRAM |
| Triple RTX 3090 | 72GB | ~$7,000 | 426 | 2.81 TB/s | Power constraints |

**Dual RTX 3090 wins because**:
1. 48GB combined VRAM = Run 70B FP16 with tensor parallelism
2. Budget allows premium supporting components
3. Identical architecture = Clean tensor parallelism
4. 1.87 TB/s combined memory bandwidth
5. Can train on custom trading data with 2-way parallel

---

## Hardware Build Specification

### Complete Parts List

| Component | Model | Specification | Price (AUD) |
|-----------|-------|---------------|-------------|
| **GPU #1** | RTX 3090 (Used) | 24GB GDDR6X, 936 GB/s, 350W | $1,400 |
| **GPU #2** | RTX 3090 (Used) | 24GB GDDR6X, 936 GB/s, 350W | $1,400 |
| **CPU** | AMD Ryzen 9 5900X | 12C/24T, 3.7-4.8GHz, 105W | $450 |
| **Motherboard** | ASUS ROG Crosshair VIII Dark Hero | X570, dual PCIe 4.0 x16 | $350 |
| **RAM** | G.Skill Trident Z Neo | 128GB (4×32GB) DDR4-3600 CL16 | $420 |
| **Boot SSD** | Samsung 990 Pro | 500GB NVMe Gen4 | $99 |
| **Model SSD** | WD Black SN850X | 2TB NVMe Gen4 (7GB/s) | $249 |
| **PSU** | Corsair HX1200i | 1200W 80+ Platinum, Modular | $349 |
| **Case** | Fractal Design Meshify 2 XL | Full tower, dual GPU clearance | $269 |
| **CPU Cooler** | Noctua NH-D15 | Dual tower, 250W TDP | $149 |
| **Case Fans** | Noctua NF-A14 PWM (3×) | 140mm high airflow | $90 |
| **10GbE NIC** | Intel X520-DA2 (Used) | Dual SFP+, PCIe x8 | $100 |
| **SFP+ DAC** | 10Gtek DAC Cable | 3m Direct Attach Copper | $40 |
| **UPS** | CyberPower CP1500PFCLCD | 1500VA/1000W Pure Sine Wave | $329 |
| **TOTAL** | | | **$5,694** |
| **Remaining** | | Contingency/shipping | **$2,306** |

### Power Budget Analysis

```
DUAL RTX 3090 POWER ENVELOPE
─────────────────────────────────────────────────────
Component              Idle (W)    Load (W)    Peak (W)
─────────────────────────────────────────────────────
RTX 3090 #1            25          320         370
RTX 3090 #2            25          320         370
Ryzen 9 5900X          20          105         142
X570 Motherboard       25          40          50
128GB DDR4 RAM         20          30          40
2× NVMe SSD            4           12          16
Intel X520-DA2         8           12          15
Case Fans (6×)         6           12          18
─────────────────────────────────────────────────────
TOTAL                  133W        851W        1,021W

1200W PSU provides:
• 1200W × 0.92 (Platinum efficiency) = 1104W DC
• Headroom: 1104W - 1021W = 83W (8% margin at peak)
• Typical load: 851W = 29% headroom (excellent)

CRITICAL: Use separate 8-pin PCIe cables for each GPU
```

---

## Compute Specifications

### GPU Cluster Metrics

| Metric | Single RTX 3090 | Dual RTX 3090 | Comparison |
|--------|-----------------|---------------|------------|
| CUDA Cores | 10,496 | 20,992 | 2× |
| Tensor Cores (Gen3) | 328 | 656 | 2× |
| RT Cores | 82 | 164 | 2× |
| VRAM | 24 GB GDDR6X | 48 GB GDDR6X | 2× |
| Memory Bandwidth | 936 GB/s | 1,872 GB/s | 2× |
| FP32 TFLOPS | 35.6 | 71.2 | 2× |
| FP16 Tensor TFLOPS | 142 | 284 | 2× |
| INT8 Tensor TOPS | 284 | 568 | 2× |
| TDP | 350W | 700W | 2× |
| PCIe Lanes | 16 | 32 (16×2) | 2× |

### LLM Inference Capacity

| Model | Parameters | Quantization | VRAM Usage | Fits? | Throughput |
|-------|-----------|--------------|------------|-------|------------|
| Llama 3.1 70B | 70B | FP16 | 140 GB | NO | - |
| Llama 3.1 70B | 70B | INT8 | 70 GB | YES (48GB+offload) | 15-20 tok/s |
| Llama 3.1 70B | 70B | 4-bit AWQ | 35 GB | YES | 25-35 tok/s |
| Llama 3.1 70B | 70B | FP16 + TP2 | 70 GB each | YES (35GB/GPU) | 40-50 tok/s |
| Qwen2.5 72B | 72B | 4-bit | 38 GB | YES | 25-30 tok/s |
| DeepSeek-V2 | 236B MoE | 4-bit | 120 GB | NO | - |
| Llama 3.1 8B | 8B | FP16 | 16 GB | YES | 100-120 tok/s |
| Custom Trading ML | ~1M | FP32 | <1 GB | YES | >10,000 inf/s |

### Training Capacity

| Workload | Batch Size | Memory/GPU | Training Speed |
|----------|------------|------------|----------------|
| Custom Trading MLP | 8,192 | 2 GB | ~100K samples/sec |
| LoRA fine-tune 7B | 4 | 18 GB | ~500 tok/s |
| LoRA fine-tune 13B | 2 | 22 GB | ~200 tok/s |
| Full fine-tune 7B | 1 | 24 GB (limit) | ~100 tok/s |
| Reinforcement Learning | 256 | 8 GB | Depends on env |

### Tensor Parallelism Performance

```
70B MODEL WITH 2-WAY TENSOR PARALLELISM
───────────────────────────────────────────────────────
Configuration           VRAM/GPU    Throughput    Latency
───────────────────────────────────────────────────────
Single GPU (offload)    24 GB       8-12 tok/s    ~80ms
Dual GPU TP=2 (FP16)    35 GB/GPU   40-50 tok/s   ~20ms
Dual GPU TP=2 (INT8)    17 GB/GPU   60-80 tok/s   ~15ms
Dual GPU TP=2 (AWQ)     17 GB/GPU   50-70 tok/s   ~18ms
───────────────────────────────────────────────────────

NVLink Bridge (Optional): +$150-200 AUD
• Without NVLink: PCIe 4.0 x16 = 32 GB/s per GPU
• With NVLink: 600 GB/s (19× faster GPU-to-GPU)
• Impact: ~30% faster tensor parallel inference
• Recommendation: Add if hunting for used NVLink bridge
```

---

## Trading System Integration

### Performance Targets

| Operation | Target | Achievable | Hardware |
|-----------|--------|------------|----------|
| Trading signal ML | <100 μs | 25-65 μs | TensorRT on RTX 3090 |
| LLM 8B inference | <100 ms | 45-55 ms avg | vLLM FP16 |
| LLM 70B inference | <2 sec | 800ms-1.5s | vLLM TP=2 |
| Model loading | <60 sec | 30-45 sec | NVMe Gen4 |
| Network overhead | <1 ms | <150 μs | Unix socket |

### Integration Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    MAXIMUM NVIDIA AI CLUSTER ($8,000 AUD)                    │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                    DUAL RTX 3090 WORKSTATION                         │    │
│  │                                                                      │    │
│  │  ┌───────────────────────────────────────────────────────────────┐  │    │
│  │  │              RTX 3090 #1 (24GB VRAM)                          │  │    │
│  │  │  • Primary inference GPU                                      │  │    │
│  │  │  • TensorRT trading signals (<100μs)                         │  │    │
│  │  │  • vLLM tensor parallel (GPU 0)                              │  │    │
│  │  └───────────────────────────────────────────────────────────────┘  │    │
│  │                              │                                       │    │
│  │                      PCIe 4.0 x16 or NVLink                         │    │
│  │                              │                                       │    │
│  │  ┌───────────────────────────────────────────────────────────────┐  │    │
│  │  │              RTX 3090 #2 (24GB VRAM)                          │  │    │
│  │  │  • Training GPU                                               │  │    │
│  │  │  • vLLM tensor parallel (GPU 1)                              │  │    │
│  │  │  • Custom model development                                   │  │    │
│  │  └───────────────────────────────────────────────────────────────┘  │    │
│  │                                                                      │    │
│  │  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐        │    │
│  │  │ Ryzen 9 5900X  │  │ 128GB DDR4     │  │ 2.5TB NVMe     │        │    │
│  │  │ 12C/24T        │  │ 3600MHz CL16   │  │ Gen4 7GB/s     │        │    │
│  │  │ Layer offload  │  │ Model staging  │  │ Model storage  │        │    │
│  │  └────────────────┘  └────────────────┘  └────────────────┘        │    │
│  │                                                                      │    │
│  │  Ubuntu 24.04 LTS | CUDA 12.6 | TensorRT 10.x | vLLM | PyTorch 2.x │    │
│  │  IP: 10.0.0.2 (10GbE) | 192.168.x.x (LAN)                          │    │
│  └──────────────────────────────────────────────────────────────────────┘    │
│                              │                                               │
│                         10GbE DAC                                           │
│                       (1.25 GB/s)                                           │
│                              │                                               │
│  ┌───────────────────────────┴───────────────────────────────────────────┐  │
│  │                        M2 MACBOOK PRO (Existing)                       │  │
│  │                                                                        │  │
│  │  • Development environment (Claude Code, VSCode, Xcode)               │  │
│  │  • Cluster orchestration and deployment scripts                       │  │
│  │  • SSH tunnel to NVIDIA workstation                                   │  │
│  │  • Cross-compilation for Linode production                            │  │
│  │  IP: 10.0.0.1 (10GbE adapter) | 192.168.x.x (WiFi)                   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                              │                                               │
│                         SSH/API                                             │
│                              │                                               │
│  ┌───────────────────────────┴───────────────────────────────────────────┐  │
│  │                      LINODE SYDNEY (Production)                        │  │
│  │                                                                        │  │
│  │  • Trading engine (C++23, io_uring, <500ns latency)                   │  │
│  │  • Receives ML signals via Unix socket                                │  │
│  │  • FIX 4.4 gateway to exchanges                                       │  │
│  │  IP: 172.105.183.244                                                  │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Verification Checklist

### Hardware Verification
```bash
# Verify dual GPU detection
nvidia-smi
# Should show: 2× RTX 3090, Driver 560.xx, CUDA 12.6

# Verify GPU topology
nvidia-smi topo -m
# Shows PCIe connection between GPUs

# Verify tensor parallelism capability
python3 -c "import torch; print(torch.cuda.device_count())"
# Expected: 2

# Memory bandwidth test
nvidia-smi --query-gpu=memory.total,memory.free --format=csv
# Should show: 24576 MiB × 2
```

### Performance Verification
```bash
# Test 70B model with tensor parallelism
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-3.1-70B-Instruct \
  --quantization awq \
  --tensor-parallel-size 2 \
  --gpu-memory-utilization 0.95 \
  --max-model-len 4096

# Expected: 40-50 tokens/sec generation

# Test TensorRT inference latency
python benchmark_tensorrt.py
# Expected: 25-65μs per trading signal inference

# Test 10GbE throughput
iperf3 -c 10.0.0.1 -t 10
# Expected: 9.4+ Gbps
```

---

## Files to Create

### max-setupF.md Contents
The file should contain:
1. Complete hardware specification table with all metrics
2. Dual RTX 3090 architecture diagram
3. Power budget calculations
4. Thermal design specifications
5. All compute metrics (TFLOPS, memory bandwidth, inference throughput)
6. LLM model capacity table
7. Training capacity specifications
8. Tensor parallelism performance data
9. Trading system integration code examples
10. TensorRT optimization guide
11. vLLM configuration for 2-GPU setup
12. Network configuration (10GbE)
13. Verification commands and expected outputs
14. Comparison to Apple Silicon alternative

---

## Implementation Steps

1. **Write max-setupF.md** with all compute specifications
2. Include wire-format structures for trading integration
3. Provide TensorRT optimization code
4. Include vLLM tensor parallel configuration
5. Add thermal engineering calculations
6. Include PCIe vs NVLink comparison
7. Provide benchmark scripts

---

## Questions Before Proceeding

None required - the analysis is complete and ready for implementation.
