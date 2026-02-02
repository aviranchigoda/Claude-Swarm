# HFT Engine Deployment and Data Collection Plan

## Overview
Deploy the HFT trading engine to a Linux server (172.x.x.x) and collect comprehensive performance metrics, system diagnostics, and simulated trading data using a mock exchange.

## Prerequisites
- Server: Linux x86_64 with SSH access (IP to be provided)
- Docker Desktop installed on Mac
- SSH key configured for server access

---

## Phase 1: Build Binary (Mac)

### 1.1 Build Docker Image
```bash
cd /Users/aviranchigoda/Desktop/software/trading/deployment-3
docker build --platform linux/amd64 -t hft-builder:latest -f docker/Dockerfile docker/
```

### 1.2 Compile Binary
```bash
mkdir -p dist
docker run --rm --platform linux/amd64 \
    -v "$(pwd):/src" \
    -e BUILD_TYPE=Release \
    hft-builder:latest
```

### 1.3 Verify Binary
```bash
file dist/hft_engine  # Must show: ELF 64-bit x86-64
```

---

## Phase 2: Create Mock Exchange

### Files to Create

**`tools/mock_exchange/mock_exchange.cpp`** (~400 lines)
- TCP server on port 9000
- Generates market data (10ms tick rate)
- Random walk price simulation with bid/ask spread
- Accepts orders, returns execution reports
- Configurable fill probability (default 80%)
- Logs all activity

**`tools/mock_exchange/CMakeLists.txt`**
- Simple CMake build for mock_exchange

**`tools/mock_exchange/build.sh`**
- Cross-compiles mock exchange using same Docker container

### Protocol (from `include/parser/compile_time_parser.hpp`)
```cpp
// Header: msg_length(u16), msg_type(u16), seq(u32), timestamp(u64)
// MarketData (type=1): symbol_id, num_entries, entries[price,qty,side,level]
// ExecutionReport (type=2): cl_ord_id, order_id, exec_id, fill info
```

---

## Phase 3: Create Data Collection Scripts

### Files to Create

**`scripts/collect_data.sh`** - Master data collection
- Creates timestamped data directory
- Collects system snapshot (kernel cmdline, hugepages, CPU info)
- Starts background monitors (mpstat, vmstat, perf)
- Launches mock exchange and HFT engine
- Runs for specified duration (default 300s)
- Collects all logs on shutdown

**`scripts/verify_system.sh`** - Pre-flight verification
- Checks isolcpus, nohz_full, hugepages
- Verifies IRQ affinity
- Confirms binary exists and is executable

**`scripts/analyze_results.py`** - Data analysis
- Parses engine logs for latency measurements
- Calculates statistics (min, max, mean, p95, p99)
- Generates JSON report

---

## Phase 4: Server Deployment

### 4.1 Set Server IP
```bash
export HFT_SERVER="<IP>"  # User provides 172.x.x.x
```

### 4.2 Initial Server Setup
```bash
ssh root@${HFT_SERVER} << 'EOF'
apt update && apt upgrade -y
apt install -y build-essential linux-headers-$(uname -r) linux-tools-$(uname -r) \
    libbpf-dev libxdp-dev libnuma-dev numactl htop sysstat ethtool python3
mkdir -p /opt/hft/{bin,config,logs,data,scripts}
EOF
```

### 4.3 Copy Files
```bash
scp dist/hft_engine root@${HFT_SERVER}:/opt/hft/bin/
scp tools/mock_exchange/mock_exchange root@${HFT_SERVER}:/opt/hft/bin/
scp scripts/*.sh scripts/*.py root@${HFT_SERVER}:/opt/hft/scripts/
ssh root@${HFT_SERVER} "chmod +x /opt/hft/bin/* /opt/hft/scripts/*"
```

### 4.4 Configure Kernel (REQUIRES REBOOT)
```bash
ssh root@${HFT_SERVER} "/opt/hft/scripts/setup_kernel.sh"
# Adds: isolcpus=6,7 nohz_full=6,7 hugepagesz=1G hugepages=8
# Reboot required
```

### 4.5 Verify After Reboot
```bash
ssh root@${HFT_SERVER} "/opt/hft/scripts/verify_system.sh"
```

---

## Phase 5: Run Data Collection

### 5.1 Manual Test (30 seconds)
```bash
ssh root@${HFT_SERVER} << 'EOF'
/opt/hft/bin/mock_exchange --port 9000 --tick-rate 10 --fill-prob 80 &
sleep 2
timeout 30 /opt/hft/bin/hft_engine --interface lo --network-core 6 --strategy-core 7 -v
pkill mock_exchange
tail -20 /opt/hft/logs/*.log
EOF
```

### 5.2 Full Data Collection (5 minutes)
```bash
ssh root@${HFT_SERVER} "/opt/hft/scripts/collect_data.sh 300"
```

### 5.3 Retrieve and Analyze
```bash
LATEST=$(ssh root@${HFT_SERVER} "ls -td /opt/hft/data/*/ | head -1")
scp -r root@${HFT_SERVER}:${LATEST} ./collected_data/
python3 scripts/analyze_results.py ./collected_data/
```

---

## Data Collected

| Category | Data |
|----------|------|
| **Performance** | CPU usage (cores 6,7), latency stats, throughput |
| **System** | Kernel cmdline, hugepages, IRQ affinity, NIC stats |
| **Trading** | Orders sent, fills received, position tracking |
| **Logs** | Engine output, exchange output, monitor outputs |

---

## Critical Files

| File | Purpose |
|------|---------|
| `docker/Dockerfile` | Cross-compilation environment |
| `include/parser/compile_time_parser.hpp` | Protocol structures for mock exchange |
| `scripts/setup_kernel.sh` | Kernel parameter configuration |
| `src/core/main.cpp` | Command-line argument parsing |

---

## Verification Steps

1. Binary compiled: `file dist/hft_engine` → x86-64 ELF
2. Mock exchange connects: Exchange log shows "Listening on port 9000"
3. Engine connects: Engine log shows "Connected to exchange"
4. Market data flows: Stats show RX packets > 0
5. Orders generated: Stats show Orders > 0
6. Fills received: Stats show Fills > 0
7. Data collected: Data directory contains all expected files
8. Analysis works: JSON report generated with latency statistics

---

## Notes

- **No real exchange**: Using mock exchange on localhost (loopback interface)
- **AF_XDP bypass**: Not used with loopback; standard TCP for testing
- **Server IP**: User will provide the actual 172.x.x.x address
- **Kernel reboot**: Required once after setup_kernel.sh runs
