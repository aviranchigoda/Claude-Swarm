# Local AI Cluster Build Plan: Maximum Software Stack Control

## Objective
Build a heterogeneous AI compute cluster combining NVIDIA (Linux) + Apple Silicon (macOS) + M2 MacBook Pro for training and deploying compute-intensive AI models locally, with maximum kernel-level control over the entire software stack.

## Budget Constraints (Immutable)
| Source | Amount (AUD) | Usage |
|--------|--------------|-------|
| Cash | $4,443 | NVIDIA Linux workstation |
| Apple Gift Card | $3,900 | Apple Silicon node |
| Existing | M2 MacBook Pro | Development/inference |

---

## PHASE 1: Hardware Acquisition

### 1.1 NVIDIA Linux Workstation ($4,443 AUD)

**Selected Build: RTX 3090 + 64GB RAM Configuration**

| Component | Model | Price (AUD) |
|-----------|-------|-------------|
| GPU | Used RTX 3090 24GB (Gumtree/eBay) | ~$1,200-1,400 |
| CPU | AMD Ryzen 7 7700 (65W, efficient) | ~$450 |
| Motherboard | Gigabyte B650 Gaming X AX | ~$280 |
| RAM | **64GB DDR5 5600MHz (2x32GB)** | ~$900-1,000 |
| Storage | WD Black SN850X 2TB NVMe | ~$280 |
| PSU | Corsair RM850x (850W 80+ Gold) | ~$200 |
| Case | Corsair 4000D Airflow | ~$130 |
| CPU Cooler | Noctua NH-D15 | ~$170 |
| **TOTAL** | | **~$3,610-3,910** |

**Remaining Budget:** ~$533-833 AUD for:
- 10GbE NIC (~$100-150)
- Additional NVMe for model storage (~$150-200)
- UPS for power protection (~$200-300)

**Why RTX 3090 + 64GB RAM:**
- 24GB VRAM (same as 4090, runs 70B models quantized)
- 285 TFLOPS FP16 tensor performance (80% of 4090)
- **64GB system RAM enables CPU offloading** for 100B+ models
- 2TB NVMe holds multiple large model checkpoints
- Budget for networking and reliability upgrades

### 1.2 Apple Silicon Node ($3,900 AUD Gift Card)

**Recommended: Mac Mini M4 Pro 48GB/1TB**

| Configuration | Price (AUD) |
|---------------|-------------|
| M4 Pro 12-core CPU / 16-core GPU | - |
| 48GB Unified Memory | - |
| 1TB SSD | - |
| **TOTAL** | ~$2,899-3,199 |

**Why M4 Pro 48GB:**
- 273 GB/s memory bandwidth (2x M4 base)
- 38 TOPS Neural Engine (exceeds M2 Ultra)
- Runs Llama 70B quantized in unified memory
- MLX achieves 230+ tok/s on 7B models
- ~$700 remaining for peripherals/accessories

**Alternative: Mac Mini M4 Pro 64GB (~$3,700-4,000)**
- Runs 70B+ models comfortably
- Slightly over budget

### 1.3 Existing Hardware
- **M2 MacBook Pro 16GB**: Development, testing, light inference

---

## PHASE 2: Operating System & Kernel Configuration

### 2.1 Linux (NVIDIA Node) - Maximum Kernel Control

**Base OS:** Ubuntu 24.04 LTS Server (Linux 6.8+)

**Kernel Optimizations:**
```bash
# /etc/default/grub - GRUB_CMDLINE_LINUX
iommu=pt                    # IOMMU passthrough for DMA
hugepagesz=2M hugepages=8192 # 16GB hugepages for GPU
transparent_hugepage=never  # Disable THP
isolcpus=4-7               # Isolate cores for GPU workers
nohz_full=4-7              # Tickless on isolated cores
rcu_nocbs=4-7              # RCU callbacks off isolated cores
```

**NVIDIA Driver Configuration:**
```bash
# Persistence mode (keeps GPU initialized)
nvidia-smi -pm 1

# Set power limit for sustained workloads
nvidia-smi -pl 400

# Enable GPU Direct RDMA (if NIC supports)
modprobe nvidia-peermem
```

**Memory Management:**
```bash
# Lock GPU memory
echo 1 > /proc/sys/vm/overcommit_memory
echo 0 > /proc/sys/kernel/numa_balancing
mlockall(MCL_CURRENT | MCL_FUTURE)  # In application code
```

### 2.2 macOS (Apple Silicon) - Limited but Optimized

**System Configuration:**
```bash
# Disable Spotlight indexing on AI directories
sudo mdutil -i off /path/to/models

# Network tuning
sudo sysctl -w net.inet.tcp.delayed_ack=0
sudo sysctl -w kern.ipc.maxsockbuf=8388608

# Disable power nap during training
sudo pmset -a powernap 0
sudo pmset -a sleep 0
```

**Note:** macOS does not allow kernel modifications (SIP). Control is at application/framework level via MLX and Metal.

---

## PHASE 3: Software Stack Installation

### 3.1 NVIDIA Linux Node

```bash
# CUDA Toolkit 12.x
wget https://developer.download.nvidia.com/compute/cuda/12.4.0/local_installers/cuda_12.4.0_550.54.14_linux.run
sudo sh cuda_12.4.0_550.54.14_linux.run

# cuDNN 9.x
sudo apt install libcudnn9-cuda-12

# Python environment
python3 -m venv ~/ai-cluster
source ~/ai-cluster/bin/activate

# PyTorch with CUDA
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124

# vLLM for high-throughput serving
pip install vllm

# Ray for distributed computing
pip install "ray[default]"

# Triton for custom GPU kernels
pip install triton
```

### 3.2 Apple Silicon Nodes (Mac Mini M4 Pro + M2 MacBook)

```bash
# Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Python environment
python3 -m venv ~/ai-cluster
source ~/ai-cluster/bin/activate

# MLX (Apple's native ML framework)
pip install mlx mlx-lm

# llama.cpp with Metal backend
brew install llama.cpp

# Ray for cluster membership
pip install "ray[default]"

# PyTorch with MPS backend (alternative to MLX)
pip install torch torchvision torchaudio
```

---

## PHASE 4: Cluster Networking & Orchestration

### 4.1 Network Topology

```
┌─────────────────────────────────────────────────────────────┐
│                    Home Network (1Gbps+)                     │
│                     Router/Switch                            │
└─────────────┬─────────────┬─────────────┬───────────────────┘
              │             │             │
     ┌────────▼────┐ ┌──────▼──────┐ ┌────▼────────┐
     │ NVIDIA Linux│ │ Mac Mini    │ │ M2 MacBook  │
     │ RTX 4090    │ │ M4 Pro 48GB │ │ Pro 16GB    │
     │ 192.168.1.10│ │ 192.168.1.11│ │ 192.168.1.12│
     │ (Head Node) │ │ (Worker)    │ │ (Dev/Worker)│
     └─────────────┘ └─────────────┘ └─────────────┘
```

**Recommended:** 2.5GbE or 10GbE switch for faster model weight transfers.

### 4.2 Ray Cluster Configuration

**On NVIDIA Linux (Head Node):**
```bash
# Start Ray head node
ray start --head --port=6379 --dashboard-host=0.0.0.0

# Verify
ray status
```

**On Mac Mini M4 Pro (Worker):**
```bash
# Join Ray cluster
ray start --address='192.168.1.10:6379'
```

**On M2 MacBook Pro (Worker):**
```bash
# Join Ray cluster (when needed)
ray start --address='192.168.1.10:6379'
```

### 4.3 Shared Storage (NFS)

**On NVIDIA Linux (NFS Server):**
```bash
sudo apt install nfs-kernel-server
sudo mkdir -p /srv/ai-models
sudo chown nobody:nogroup /srv/ai-models

# /etc/exports
/srv/ai-models 192.168.1.0/24(rw,sync,no_subtree_check)

sudo exportfs -a
sudo systemctl restart nfs-kernel-server
```

**On Mac Mini / MacBook (NFS Clients):**
```bash
sudo mkdir -p /Volumes/ai-models
sudo mount -t nfs 192.168.1.10:/srv/ai-models /Volumes/ai-models
```

---

## PHASE 5: Heterogeneous AI Workload Distribution

### 5.1 Architecture Pattern

```python
# cluster_config.py - Ray heterogeneous resource allocation

import ray

# Initialize cluster connection
ray.init(address="auto")

# CUDA worker for training (lands on NVIDIA node)
@ray.remote(num_gpus=1, resources={"CUDA": 1})
class CUDATrainer:
    def __init__(self, model_name):
        import torch
        self.device = torch.device("cuda")
        self.model = load_model(model_name).to(self.device)

    def train_batch(self, batch):
        # Full CUDA training with maximum control
        return self.model.train_step(batch)

# MLX worker for inference (lands on Apple Silicon)
@ray.remote(num_cpus=4, resources={"Apple": 1})
class MLXInference:
    def __init__(self, model_path):
        import mlx.core as mx
        from mlx_lm import load, generate
        self.model, self.tokenizer = load(model_path)

    def generate(self, prompt, max_tokens=100):
        return generate(self.model, self.tokenizer, prompt, max_tokens)
```

### 5.2 Workload Distribution Strategy

| Workload | Target Hardware | Framework | Rationale |
|----------|-----------------|-----------|-----------|
| Model Training | NVIDIA RTX 4090 | PyTorch + CUDA | 660 TFLOPS, NCCL support |
| Fine-tuning (LoRA) | NVIDIA RTX 4090 | PyTorch + PEFT | Gradient computation |
| Batch Inference (high throughput) | NVIDIA RTX 4090 | vLLM | PagedAttention optimization |
| Interactive Inference | Mac Mini M4 Pro | MLX | 230+ tok/s, low latency |
| Light Inference | M2 MacBook Pro | llama.cpp | Portable, energy efficient |
| Development/Testing | M2 MacBook Pro | MLX / PyTorch MPS | Rapid iteration |

### 5.3 Model Serving Stack

**NVIDIA Node - vLLM Server:**
```bash
# High-throughput LLM serving
python -m vllm.entrypoints.openai.api_server \
    --model meta-llama/Llama-2-70b-chat-hf \
    --tensor-parallel-size 1 \
    --host 0.0.0.0 \
    --port 8000
```

**Mac Mini - MLX Server:**
```bash
# Apple Silicon optimized serving
mlx_lm.server --model mlx-community/Llama-3.2-3B-Instruct-4bit --port 8001
```

---

## PHASE 6: Maximum Low-Level Control Points

### 6.1 NVIDIA/Linux (Full Kernel Control)

| Layer | Control Level | How |
|-------|---------------|-----|
| Kernel | Full | Custom kernel compilation, RT_PREEMPT patches |
| Memory | Full | Hugepages, NUMA, mlock, custom allocators |
| GPU | Full | CUDA driver API, custom kernels, Triton |
| Network | Full | XDP, DPDK, io_uring bypass |
| Scheduling | Full | SCHED_FIFO, CPU isolation, cgroups |
| I/O | Full | io_uring, direct I/O, custom schedulers |

**Custom CUDA Kernel Example (Triton):**
```python
import triton
import triton.language as tl

@triton.jit
def custom_matmul_kernel(a_ptr, b_ptr, c_ptr, M, N, K, ...):
    # Direct GPU programming without CUDA boilerplate
    pid = tl.program_id(0)
    # ... custom memory access patterns
```

### 6.2 Apple Silicon/macOS (Application-Level Control)

| Layer | Control Level | How |
|-------|---------------|-----|
| Kernel | None | SIP blocks modifications |
| Memory | Limited | Unified memory (automatic), MLX lazy eval |
| GPU | Medium | Metal shaders, MLX custom ops |
| Network | Limited | sysctl tuning only |
| Scheduling | Limited | QoS classes |

**MLX Custom Operation Example:**
```python
import mlx.core as mx

# Custom metal kernel via MLX
@mx.custom_function
def custom_attention(q, k, v):
    # MLX handles Metal compilation
    return mx.fast.scaled_dot_product_attention(q, k, v)
```

---

## PHASE 7: Integration with Trading Codebase

The existing trading system remains pure C++ for <500ns latency. AI predictions operate on a **slower timescale** (seconds to minutes) and feed into the trading strategy as signals.

### 7.1 AI-Trading Integration Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           AI CLUSTER (Python/Ray)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │ Price Predictor │  │ Sentiment Model │  │ Anomaly Detector│         │
│  │ (NVIDIA RTX3090)│  │ (Mac Mini MLX)  │  │ (NVIDIA RTX3090)│         │
│  │                 │  │                 │  │                 │         │
│  │ LSTM/Transformer│  │ Llama-3 8B      │  │ Autoencoder     │         │
│  │ 1-min lookahead │  │ News/Twitter    │  │ Order flow      │         │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘         │
│           │                    │                    │                   │
│           └────────────────────┼────────────────────┘                   │
│                                │                                        │
│                    ┌───────────▼───────────┐                           │
│                    │   Signal Aggregator   │                           │
│                    │   (Ray Actor)         │                           │
│                    │                       │                           │
│                    │  Weighted ensemble:   │                           │
│                    │  - Price: 0.4         │                           │
│                    │  - Sentiment: 0.3     │                           │
│                    │  - Anomaly: 0.3       │                           │
│                    └───────────┬───────────┘                           │
│                                │                                        │
└────────────────────────────────┼────────────────────────────────────────┘
                                 │ ZeroMQ PUB/SUB
                                 │ (every 100ms - 1s)
                                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                     TRADING ENGINE (C++, <500ns hot path)               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  src/strategy/ai_signal_receiver.hpp  ◄── New component                 │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  class AISignalReceiver {                                        │   │
│  │      void poll_signals();  // Non-blocking ZMQ recv             │   │
│  │      double get_price_bias();  // -1.0 to +1.0                  │   │
│  │      double get_sentiment_score();                               │   │
│  │      bool is_anomaly_detected();                                 │   │
│  │  };                                                              │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                 │                                       │
│                                 ▼                                       │
│  src/strategy/arbitrage_strategy.cpp                                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  // Existing arbitrage logic UNCHANGED                          │   │
│  │  if (profit_bps >= min_profit_bps) {                            │   │
│  │      // NEW: AI bias adjustment                                  │   │
│  │      double ai_bias = ai_receiver.get_price_bias();             │   │
│  │      if (ai_bias > 0.5) position_size *= 1.2;  // Confident     │   │
│  │      if (ai_bias < -0.5) position_size *= 0.8; // Cautious      │   │
│  │                                                                  │   │
│  │      // NEW: Anomaly kill switch                                 │   │
│  │      if (ai_receiver.is_anomaly_detected()) {                   │   │
│  │          risk_manager.trigger_soft_pause();                      │   │
│  │      }                                                           │   │
│  │                                                                  │   │
│  │      execute_arbitrage(buy_exchange, sell_exchange);            │   │
│  │  }                                                               │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

### 7.2 AI Models for Trading

| Model | Hardware | Framework | Input | Output | Latency |
|-------|----------|-----------|-------|--------|---------|
| **Price Predictor** | NVIDIA RTX 3090 | PyTorch | OHLCV, order book depth | Direction + confidence | ~50-100ms |
| **Sentiment Analyzer** | Mac Mini M4 Pro | MLX (Llama-3 8B) | News headlines, tweets | Sentiment score -1 to +1 | ~200-500ms |
| **Anomaly Detector** | NVIDIA RTX 3090 | PyTorch | Order flow, spread patterns | Anomaly probability | ~10-50ms |
| **Strategy Optimizer** | NVIDIA RTX 3090 | PyTorch (RL) | Backtest episodes | Optimal parameters | Offline (hours) |

### 7.3 New Files to Create

```
trading/
├── src/
│   ├── ai/                          # NEW: AI integration layer
│   │   ├── ai_signal_receiver.hpp   # ZeroMQ subscriber (C++)
│   │   ├── ai_signal_receiver.cpp
│   │   ├── signal_types.hpp         # Shared message formats
│   │   └── CMakeLists.txt
│   └── strategy/
│       └── arbitrage_strategy.cpp   # MODIFY: Add AI bias
│
├── ai_cluster/                      # NEW: Python AI code
│   ├── models/
│   │   ├── price_predictor.py       # LSTM/Transformer
│   │   ├── sentiment_analyzer.py    # LLM-based
│   │   └── anomaly_detector.py      # Autoencoder
│   ├── training/
│   │   ├── train_price_model.py
│   │   ├── train_anomaly_model.py
│   │   └── rl_strategy_optimizer.py
│   ├── serving/
│   │   ├── signal_publisher.py      # ZeroMQ publisher
│   │   └── ray_cluster_config.py
│   └── data/
│       ├── historical_fetcher.py    # Binance/exchange data
│       └── feature_engineering.py
```

### 7.4 ZeroMQ Message Protocol

```cpp
// signal_types.hpp - Shared between C++ and Python
struct AISignal {
    uint64_t timestamp_ns;
    char symbol[16];

    // Price prediction
    float price_direction;     // -1.0 (down) to +1.0 (up)
    float price_confidence;    // 0.0 to 1.0

    // Sentiment
    float sentiment_score;     // -1.0 (bearish) to +1.0 (bullish)

    // Anomaly
    float anomaly_probability; // 0.0 to 1.0
    uint8_t anomaly_type;      // 0=none, 1=spread, 2=volume, 3=flash

    // Meta
    uint32_t model_version;
};
```

```python
# signal_publisher.py - Python side
import zmq
import struct

context = zmq.Context()
socket = context.socket(zmq.PUB)
socket.bind("tcp://*:5555")

def publish_signal(signal: AISignal):
    # Pack to binary (matches C++ struct)
    msg = struct.pack(
        "Q16sffff B I",
        signal.timestamp_ns,
        signal.symbol.encode(),
        signal.price_direction,
        signal.price_confidence,
        signal.sentiment_score,
        signal.anomaly_probability,
        signal.anomaly_type,
        signal.model_version
    )
    socket.send(msg)
```

### 7.5 Training Data Pipeline

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Binance    │     │  Historical  │     │   Feature    │
│  WebSocket   │────►│   Database   │────►│  Engineering │
│  (Live data) │     │  (TimescaleDB│     │  (Python)    │
└──────────────┘     │   or Parquet)│     └──────┬───────┘
                     └──────────────┘            │
                                                 ▼
                     ┌──────────────────────────────────────┐
                     │        Training Pipeline (Ray)       │
                     │                                      │
                     │  ┌────────────┐  ┌────────────┐     │
                     │  │ GPU Worker │  │ GPU Worker │     │
                     │  │ (RTX 3090) │  │ (if added) │     │
                     │  └────────────┘  └────────────┘     │
                     └──────────────────────────────────────┘
```

### 7.6 Implementation Priority

| Phase | Task | Estimated Effort |
|-------|------|------------------|
| 1 | Build AI cluster hardware | Hardware assembly |
| 2 | Set up Ray cluster + ZeroMQ | Software configuration |
| 3 | Create ai_signal_receiver.hpp/cpp | C++ integration |
| 4 | Train anomaly detector (simplest) | Model development |
| 5 | Integrate anomaly signals into risk manager | Trading modification |
| 6 | Train price predictor | Model development |
| 7 | Train sentiment analyzer on Mac Mini | MLX development |
| 8 | Build signal aggregator | Ensemble logic |
| 9 | Full integration + backtesting | Testing |

**Critical Path:** The trading hot path remains untouched (<500ns). AI signals are consumed asynchronously and only affect position sizing and risk thresholds, not the core arbitrage detection logic.

---

## Verification & Testing

### Hardware Verification
```bash
# NVIDIA node
nvidia-smi                    # GPU detected
ray status                    # Ray cluster healthy
python -c "import torch; print(torch.cuda.is_available())"

# Mac Mini
system_profiler SPHardwareDataType  # M4 Pro confirmed
python -c "import mlx.core as mx; print(mx.default_device())"

# Cluster test
ray status  # Shows all 3 nodes
```

### Performance Benchmarks
```bash
# NVIDIA - vLLM benchmark
python -m vllm.entrypoints.benchmark --model meta-llama/Llama-2-7b-hf

# Mac Mini - MLX benchmark
python -c "from mlx_lm import load, generate; ..."

# Cross-cluster - Ray distributed task
python test_heterogeneous_cluster.py
```

---

## Summary: Control Hierarchy

| Hardware | OS | Kernel Control | GPU Control | Best For |
|----------|-----|----------------|-------------|----------|
| NVIDIA Linux | Ubuntu 24.04 | **FULL** | **FULL** (CUDA) | Training, batch inference |
| Mac Mini M4 Pro | macOS | Limited | Medium (MLX) | Interactive inference |
| M2 MacBook Pro | macOS | Limited | Medium (MLX) | Development |

**Maximum control achieved on NVIDIA Linux node** - this is your "AI powerhouse" for training and heavy compute. Apple Silicon nodes excel at inference with unified memory advantages.

---

## Total Investment

| Item | Cost (AUD) | Source |
|------|------------|--------|
| NVIDIA Linux Workstation (RTX 3090 + 64GB) | ~$3,610-3,910 | Cash |
| 10GbE NIC + extras | ~$300-500 | Cash (remaining) |
| Mac Mini M4 Pro 48GB/1TB | ~$3,199 | Gift Card |
| Peripherals/accessories | ~$700 | Gift Card (remaining) |
| **TOTAL HARDWARE** | **~$7,809-8,309** | |

### Cluster Specifications Summary

| Node | CPU | RAM | GPU/Accelerator | Storage | Role |
|------|-----|-----|-----------------|---------|------|
| NVIDIA Linux | Ryzen 7 7700 | 64GB DDR5 | RTX 3090 24GB | 2TB NVMe | Training, batch inference |
| Mac Mini M4 Pro | 12-core M4 Pro | 48GB unified | 16-core GPU | 1TB SSD | Interactive inference, sentiment |
| M2 MacBook Pro | 10-core M2 Pro | 16GB unified | 16-core GPU | 512GB+ | Development, testing |
| **TOTAL CLUSTER** | **30 cores** | **128GB** | **24GB VRAM + 64GB unified** | **3.5TB+** | |

### Software Stack Summary

| Layer | NVIDIA Linux | Apple Silicon |
|-------|--------------|---------------|
| OS | Ubuntu 24.04 LTS | macOS Sequoia |
| Kernel Control | **FULL** (custom params, isolation) | Limited (SIP) |
| ML Framework | PyTorch + CUDA 12.x | MLX + Metal |
| Serving | vLLM, Triton | vllm-mlx, llama.cpp |
| Distributed | Ray + NCCL | Ray + Gloo |
| IPC | ZeroMQ (PUB/SUB) | ZeroMQ (SUB) |

### Maximum Control Points Achieved

1. **Kernel-level memory management** - Hugepages, mlock, NUMA (Linux)
2. **GPU-level control** - Custom CUDA kernels via Triton, driver API
3. **Network bypass** - io_uring, potentially XDP for data feeds (Linux)
4. **CPU isolation** - isolcpus, nohz_full, SCHED_FIFO (Linux)
5. **Unified memory optimization** - MLX lazy evaluation (Apple)
6. **Heterogeneous orchestration** - Ray cluster across all hardware
7. **Zero-copy IPC** - ZeroMQ with binary struct packing

This setup provides **maximum control on the NVIDIA Linux node** (true kernel-level) while leveraging Apple Silicon's unified memory advantages for interactive inference and LLM-based sentiment analysis.
