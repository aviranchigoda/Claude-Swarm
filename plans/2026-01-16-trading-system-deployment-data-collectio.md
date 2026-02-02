# Trading System Deployment & Data Collection Plan

## System Context
- **Platform**: macOS Darwin 24.5.0 (Apple Silicon ARM64 - T6020)
- **Compiler**: Clang 17.0.0 (C++23 capable)
- **OpenSSL**: 3.0.15 ✓
- **CMake**: NOT INSTALLED (required)

## Deployment Strategy

Since we're on macOS, AF_XDP (kernel bypass) is unavailable. The system will run in **simulation mode** which is fully functional for:
- Latency benchmarking (TSC timing, memory access patterns)
- Order book operations
- Strategy signal generation
- Performance metrics collection

---

## Phase 1: Install Dependencies

```bash
# Install CMake (required, currently missing)
brew install cmake
```

## Phase 2: Build the Trading System

```bash
cd /Users/aviranchigoda/Desktop/software/trading/deployment-4

# Create build directory
mkdir -p build && cd build

# Configure with CMake (use clang for macOS)
cmake .. \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER=clang

# Build all targets
make -j8
```

**Expected Binaries:**
- `bin/trading_engine` - Main trading engine
- `bin/latency_bench` - Latency benchmark tool
- `bin/kernel_tuner` - System verification tool

## Phase 3: Data Collection

### 3.1 System Hardware Data
```bash
# CPU info
sysctl -a | grep -E "cpu|cache|machdep"

# Memory info
sysctl hw.memsize
vm_stat

# System profiler
system_profiler SPHardwareDataType
```

### 3.2 Latency Benchmarks
```bash
cd build/bin

# Run latency benchmark
./latency_bench

# Collect:
# - TSC read latency (cycles)
# - clock_gettime latency (cycles)
# - L1/L2/L3 cache access latency
# - Memory access patterns
```

### 3.3 Trading Simulation
```bash
# Run trading engine in dry-run mode (default)
./trading_engine --interface lo --core 0

# Let run for ~60 seconds to collect:
# - Iterations per second
# - Signal generation rate
# - Simulated opportunity detection
# - Memory usage patterns
```

### 3.4 Memory Performance
```bash
# Monitor during execution
vm_stat 1
top -l 10 -s 1 -stats pid,command,mem,cpu
```

## Phase 4: Generate Performance Report

Collect and aggregate:
1. **System specs** - CPU, memory, cache sizes
2. **TSC frequency** - Calibrated nanosecond timing
3. **Latency percentiles** - P50, P99, P999 for operations
4. **Throughput** - Iterations/second, signals/second
5. **Memory efficiency** - Arena allocator usage
6. **Cache performance** - L1/L2/L3 hit estimates

---

## Critical Files to Monitor

| File | Purpose |
|------|---------|
| `src/main.cpp:258-303` | Simulation loop |
| `include/core/timestamp.hpp` | TSC timing |
| `src/tools/latency_benchmark.cpp` | Benchmarks |
| `include/core/arena_allocator.hpp` | Memory tracking |

## Expected Output Data

```
Session Statistics:
  Total iterations:    [X]
  Total time:          [Y] seconds
  Iterations/second:   [Z]
  Opportunities found: [N]
  Trades executed:     [M]
  Avg latency:         [L] ns
  TSC Frequency:       [F] MHz
  Memory used:         [B] bytes
```

## Verification

1. ✓ Build completes without errors
2. ✓ `latency_bench` runs and produces timing data
3. ✓ `trading_engine` runs in simulation mode
4. ✓ Statistics are printed every 10K iterations
5. ✓ No crashes or memory leaks (use sanitizers in debug mode)

---

## Limitations on macOS

| Feature | Status | Impact |
|---------|--------|--------|
| AF_XDP | ❌ Linux-only | Uses simulation instead |
| CPU isolation | ❌ Linux-only | No guaranteed latency |
| SCHED_FIFO | ❌ Linux-only | Standard scheduling |
| Huge pages | ⚠️ Limited | Uses regular pages |
| IRQ affinity | ❌ Linux-only | N/A |

The simulation mode provides **accurate algorithmic benchmarking** but not real-world network latency measurements.
