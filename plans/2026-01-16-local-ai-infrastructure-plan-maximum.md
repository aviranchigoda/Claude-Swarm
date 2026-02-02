# Local AI Infrastructure Plan: Maximum Software Stack Control

## Executive Summary

Your codebase already contains a comprehensive engineering specification (`LOCAL_AI_CLUSTER_ENGINEERING.md`) that perfectly matches your budget and objectives. This plan validates and distills those findings.

**The Single Most Important Setup:**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           OPTIMAL LOCAL AI CLUSTER                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   M2 MacBook Pro ◄──Thunderbolt──► Mac Mini M4 Pro ◄──10GbE──► NVIDIA Node │
│   (Orchestrator)                    (Apple Silicon)              (RTX 3090) │
│                                                                              │
│   • Code development                • 48GB unified memory        • 24GB VRAM │
│   • Model deployment                • MLX Framework              • CUDA 12.6 │
│   • Inference routing               • 70B models (4-bit)        • Training  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Critical Finding: Mac Mini vs Mac Pro

**Answer: Mac Mini M4 Pro (NOT Mac Pro)**

| Option | Price (AUD) | Within Budget? | Rationale |
|--------|-------------|----------------|-----------|
| Mac Pro M2 Ultra | $11,499+ | NO | Way over budget |
| Mac Studio M2 Ultra | $6,499+ | NO | Over budget |
| Mac Studio M2 Max | $3,499 | Marginal | Less memory than M4 Pro |
| **Mac Mini M4 Pro 48GB** | **$3,299** | **YES** | **Optimal choice** |

The Mac Mini M4 Pro 48GB is the correct choice because:
1. **Fits Apple Gift Card** ($3,299 < $3,900)
2. **48GB unified memory** - sufficient for 70B 4-bit models (~38GB)
3. **Built-in 10GbE** - no adapter needed
4. **273 GB/s memory bandwidth** - excellent for LLM inference
5. **20-core GPU** - hardware ML acceleration

---

## Budget Allocation

### Apple Gift Card: $3,900 AUD

| Item | Price |
|------|-------|
| Mac Mini M4 Pro 48GB | $3,299 |
| Thunderbolt 5 Cable (0.8m) | $49 |
| External USB Fan | $30 |
| SFP+ DAC Cable (2m) | $40 |
| **Subtotal** | **$3,418** |
| **Remaining** | **$482** |

### Cash: $4,443 AUD

| Item | Price |
|------|-------|
| RTX 3090 24GB (Used) | $1,500 |
| AMD Ryzen 7 5700X | $280 |
| Noctua NH-U12S Cooler | $109 |
| ASUS TUF B550-PLUS | $189 |
| G.Skill 64GB DDR4-3600 | $210 |
| Samsung 980 Pro 500GB | $89 |
| WD Black SN850X 2TB | $249 |
| Corsair RM850x PSU | $189 |
| Fractal Meshify 2 Case | $189 |
| Intel X520-DA1 10GbE NIC | $80 |
| CyberPower 1000VA UPS | $229 |
| **Subtotal** | **$3,313** |
| **Remaining** | **$1,130** |

### Total Investment

| Source | Spent | Reserve |
|--------|-------|---------|
| Apple Gift Card | $3,418 | $482 |
| Cash | $3,313 | $1,130 |
| **TOTAL** | **$6,731** | **$1,612** |

---

## Maximum Software Stack Control

### Control Layers Achieved

```
LEVEL 0: HARDWARE (Physical Control)
├── M4 Pro: 14-core CPU, 20-core GPU, 48GB unified memory
├── RTX 3090: 10,496 CUDA cores, 24GB GDDR6X, 936 GB/s bandwidth
├── 10GbE DAC: <1μs latency, 1.25 GB/s throughput
└── NVMe Gen4: 7+ GB/s read/write

LEVEL 1: KERNEL (System Call Interface)
├── macOS Sequoia: Metal 3, MLX native support
├── Ubuntu 24.04: CUDA 12.6, kernel bypass (io_uring)
├── CPU isolation, hugepages, real-time scheduling
└── Direct hardware timing (RDTSC on x86, mach_absolute_time on ARM)

LEVEL 2: MEMORY (Zero-Allocation Critical Path)
├── Existing: Pool allocators, arena allocators in trading codebase
├── Apple: Unified memory - zero-copy CPU↔GPU
├── NVIDIA: Pre-allocated CUDA buffers, pinned memory
└── Cache-line aligned data structures (64-byte boundaries)

LEVEL 3: ML FRAMEWORKS (Maximum Control)
├── MLX: Apple's framework - direct Metal GPU access
├── PyTorch: Full CUDA control, custom kernels
├── TensorRT: Hardware-optimized inference (<100μs)
└── vLLM: KV-cache optimization, continuous batching

LEVEL 4: APPLICATION (Full Source Control)
├── 79,791 lines of C/C++23 trading system
├── Custom Unix socket integration for ML inference
├── Wire-format structures for <1ms latency
└── Non-blocking I/O, zero-allocation hot path
```

### What You Control (99%)

- CPU cycle-level timing (RDTSC/mach_absolute_time)
- Memory allocation patterns (custom pools, hugepages)
- GPU compute (Metal shaders, CUDA kernels)
- Network driver selection (io_uring, kernel bypass)
- Protocol parsing (custom JSON, HTTP, binary formats)
- ML inference (local models, no API dependencies)
- Trading execution (SPSC queues, 0-allocation critical path)

### What You Don't Control (1%)

- Internet routing to exchanges (~50ms RTT to Binance)
- TLS encryption overhead (required by exchanges)
- Cloud exchange server locations

---

## Software Stack

### Apple Node (Mac Mini M4 Pro)

```bash
# Operating System
macOS Sequoia 15.x (ARM64)

# ML Framework
pip3 install mlx mlx-lm
pip3 install huggingface_hub transformers

# Models (stored locally)
- Llama 3.1 70B (4-bit): ~38GB - code assistance
- Qwen2.5 32B (INT8): ~32GB - trading research
- BGE-M3: ~2GB - embeddings

# Network Tuning
sudo sysctl -w net.inet.tcp.sendspace=2097152
sudo sysctl -w net.inet.tcp.recvspace=2097152
```

### NVIDIA Node (Custom PC)

```bash
# Operating System
Ubuntu 24.04 LTS Server

# GPU Stack
nvidia-driver-560
cuda-toolkit-12-6
libcudnn9-cuda-12

# ML Stack
pip install torch --index-url https://download.pytorch.org/whl/cu126
pip install vllm tensorrt transformers accelerate bitsandbytes
pip install flash-attn xformers

# Models
- Llama 3.1 8B (FP16): ~16GB - fast inference
- Custom trading ML: <1GB - <100μs inference
```

---

## Integration with Trading System

### Unix Socket Interface (Existing Design)

```c
// From LOCAL_AI_CLUSTER_ENGINEERING.md
typedef struct __attribute__((packed)) {
    uint64_t timestamp_ns;
    uint16_t symbol_id;
    int64_t  bid_price, ask_price;
    int64_t  bid_size, ask_size;
    int64_t  book_imbalance;
    // ... market features
} ml_request_t;

typedef struct __attribute__((packed)) {
    int8_t   direction;      // -1=sell, 0=flat, +1=buy
    uint8_t  confidence;     // 0-100
    int64_t  target_price;
    uint64_t inference_latency_ns;
} ml_response_t;
```

### Performance Targets

| Component | Target Latency |
|-----------|---------------|
| Trading signal ML (TensorRT) | <100μs |
| LLM inference (8B model) | ~50ms |
| LLM inference (70B 4-bit) | ~500ms first token |
| Network overhead (10GbE) | <1μs |

---

## Critical Files

| File | Purpose |
|------|---------|
| `LOCAL_AI_CLUSTER_ENGINEERING.md` | Complete hardware/software spec (2087 lines) |
| `low-level-engineering-real-world.md` | Control level spectrum documentation |
| `src/core/pool_allocator.h` | Memory management (zero-allocation path) |
| `src/core/timing.h` | RDTSC timing implementation |
| `src/core/spsc_queue.h` | Lock-free queues |
| `deployment-*/` | 5 production trading system variants |

---

## Verification Plan

### Phase 1: Hardware Acquisition
- [ ] Order Mac Mini M4 Pro 48GB from Apple Store
- [ ] Source RTX 3090 from eBay/Gumtree/Facebook ($1,400-$1,700)
- [ ] Order PC components from PCCaseGear/Scorptec

### Phase 2: NVIDIA Node Build
- [ ] Assemble PC (2 hours)
- [ ] Install Ubuntu 24.04 + NVIDIA drivers
- [ ] Run `nvidia-smi` - verify RTX 3090 detected
- [ ] Run `python -c "import torch; print(torch.cuda.is_available())"`

### Phase 3: Apple Node Setup
- [ ] Configure macOS ML settings
- [ ] Run `python -c "import mlx.core as mx; print(mx.default_device())"`
- [ ] Download Llama 3.1 70B 4-bit model (~38GB)

### Phase 4: Cluster Integration
- [ ] Configure 10GbE static IPs (10.0.0.1, 10.0.0.2)
- [ ] Run `iperf3` - verify 9.4+ Gbps throughput
- [ ] Test inference API latency between nodes

### Phase 5: Trading Integration
- [ ] Implement Unix socket server
- [ ] Connect to existing trading system
- [ ] Benchmark end-to-end signal generation latency

---

## Questions Requiring Clarification

1. **Proceed with existing specification?** The `LOCAL_AI_CLUSTER_ENGINEERING.md` document is comprehensive - should this serve as the implementation blueprint?

2. **Primary use case priority?**
   - Development/code assistance → prioritize Apple (larger models)
   - Training/fast inference → prioritize NVIDIA (CUDA)
   - Trading signals → prioritize NVIDIA (TensorRT)

3. **Timeline constraints?** The document estimates 4 weeks for full deployment.
