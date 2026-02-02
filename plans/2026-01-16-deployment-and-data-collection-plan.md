# Deployment and Data Collection Plan

## Objective
Deploy the ultra-low-latency trading system and collect comprehensive performance data.

## Configuration
- **Server**: root@[USER_PROVIDED_IP]
- **Interface**: eth0
- **Deployment Mode**: Full deployment validation

---

## Execution Steps

### Step 1: Build the Trading System (Local Docker)
```bash
cd /Users/aviranchigoda/Desktop/software/trading/deployment-5
./docker/build.sh dev
```

### Step 2: Run PGO-Optimized Build
```bash
./docker/build.sh pgo
```

### Step 3: Deploy to Server
```bash
./scripts/deploy/deploy.sh --host root@[IP_ADDRESS] \
  --binary build-pgo-final/trading_engine \
  --setup-kernel \
  --interface eth0
```

### Step 4: Validate System Configuration
```bash
ssh root@[IP_ADDRESS] 'sudo /opt/ultra_trading/scripts/deploy/validate.sh --verbose'
```

### Step 5: Run Trading Engine and Collect Data
```bash
ssh root@[IP_ADDRESS] 'sudo systemctl start ultra-trading'
ssh root@[IP_ADDRESS] 'sudo tail -f /opt/ultra_trading/logs/trading.log'
```

---

## Phase 1: Local Build and Benchmarking (No Server Required)

### 1.1 Build the Trading System
```bash
cd /Users/aviranchigoda/Desktop/software/trading/deployment-5
./docker/build.sh dev
```

### 1.2 Run Latency Benchmarks Locally
```bash
./docker/build.sh benchmark
```

**Data Collected:**
- TSC read overhead (nanoseconds)
- Ring buffer push/pop latency
- FIX message encoding latency
- Pool allocator performance
- Statistics: Min, Max, Mean, P50, P99, P999, StdDev

### 1.3 Generate PGO Profile Data
```bash
./docker/build.sh pgo
```

**Data Collected:**
- Market data processing rate (updates/second)
- Order management throughput
- FIX protocol encoding rate (messages/second)
- Ring buffer operation rate

---

## Phase 2: Remote Deployment (Requires Server Credentials)

### 2.1 Prerequisites Needed
- **SSH Access**: `USER@HOST` format (e.g., `ubuntu@sydney-linode.example.com`)
- **Root/Sudo Access**: Required for kernel tuning
- **Network Interface Name**: Usually `eth0` but may vary

### 2.2 Kernel Tuning and Deployment
```bash
./scripts/deploy/deploy.sh --host USER@HOST \
  --binary build-pgo-final/trading_engine \
  --setup-kernel \
  --interface eth0
```

### 2.3 System Validation
```bash
ssh USER@HOST 'sudo /opt/ultra_trading/scripts/deploy/validate.sh --verbose'
```

**Data Collected:**
- CPU isolation status
- IRQ affinity configuration
- HugePages allocation
- Memory lock limits
- Network busy-poll status
- Kernel parameters

---

## Phase 3: Live Data Collection (Requires Broker Connection)

### 3.1 Trading Engine Startup
```bash
ssh USER@HOST 'sudo systemctl start ultra-trading'
```

### 3.2 Real-Time Monitoring
```bash
ssh USER@HOST 'sudo tail -f /opt/ultra_trading/logs/trading.log'
```

**Data Collected:**
- Packets received/sent
- Polling statistics
- Order acknowledgments
- Fill notifications
- Latency measurements (tick-to-trade)

---

## Data to Be Collected

### From Local Benchmarks:
1. **Latency Metrics** (nanoseconds)
   - TSC read overhead: ~20-40 cycles expected
   - Ring buffer push/pop: ~10-30 cycles expected
   - FIX encoding: ~500-2000 cycles expected
   - Pool allocator: ~10-20 cycles expected

2. **Throughput Metrics**
   - Market data processing rate (updates/sec)
   - FIX message encoding rate (messages/sec)
   - Ring buffer operations rate (ops/sec)

### From Server Validation:
3. **System Configuration**
   - CPU isolation status (cores 4-7)
   - IRQ affinity configuration
   - HugePages allocation (2GB target)
   - Memory lock limits
   - CPU governor (performance mode)
   - C-state status (disabled)

### From Live Trading:
4. **Runtime Metrics**
   - Packets received/sent per second
   - Polling efficiency (empty polls ratio)
   - Order acknowledgment latency
   - Fill notification latency

---

## Data Collection Summary

| Phase | Data Type | Requirements |
|-------|-----------|--------------|
| Local Build | Compile metrics | Docker only |
| Benchmarks | Latency stats | Docker only |
| PGO Profile | Throughput data | Docker only |
| Deployment | System config | SSH + sudo |
| Validation | Kernel tuning | SSH + sudo |
| Live Trading | Trading metrics | Broker connection |

---

## Verification Steps

1. **Build Verification**: Check for `build/trading_engine` binary
2. **Benchmark Verification**: Review latency percentiles in output
3. **Deployment Verification**: Run `validate.sh` on target server
4. **Live Verification**: Monitor log output for packet statistics
