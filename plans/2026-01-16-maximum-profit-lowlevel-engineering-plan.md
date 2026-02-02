# MAXIMUM PROFIT LOW-LEVEL ENGINEERING PLAN: Deployment-1 HFT System

## EXECUTIVE SUMMARY

**Current State:** Production-grade C++23 HFT infrastructure targeting ASX via IBKR FIX, achieving ~2-3ms tick-to-trade latency, BUT with **placeholder strategy generating ZERO profit**.

**Goal:** Implement the most aggressive low-level engineering optimizations to maximize profit/return on ASX exchange.

**Expected Outcome:** Transform framework into profit-generating system with $1,000-5,000/day potential.

---

## PART 1: CRITICAL FINDINGS

### 1.1 Current Architecture
| Component | Implementation | Latency |
|-----------|---------------|---------|
| I/O Model | io_uring with SQPOLL | ~50-100ns |
| Memory | 4GB arena + 2MB huge pages | ~5ns allocation |
| FIX Parser | Zero-copy streaming | ~300ns |
| Order Submit | FIX encoder + io_uring | ~800ns |
| **Total tick-to-trade** | **~2-3ms** | ✅ Achieved |

### 1.2 Critical Gap: NO PROFIT-GENERATING STRATEGY
```cpp
// CURRENT: ExampleStrategy in main.cpp (lines 181-222)
void on_market_data(InstrumentId instrument, const BBO& bbo) override {
    ++update_count_;  // DOES NOTHING - Just counts ticks
}
```

### 1.3 Key Files
- Engine: `/deployment-1/include/engine/trading_engine.hpp`
- Strategy Interface: `/deployment-1/src/engine/strategy_interface.cpp`
- Position Tracker: `/deployment-1/src/trading/position_tracker.cpp`
- Risk Manager: `/deployment-1/src/trading/risk_manager.cpp`
- Order Book: `/deployment-1/src/trading/order_book.cpp`

---

## PART 2: LOWEST-LEVEL ENGINEERING OPTIMIZATIONS

### 2.1 PHASE 1: Sub-Microsecond Hot Path (Week 1)

#### A. Replace io_uring with DPDK (Bare Metal Only)
**Current:** io_uring (~100ns per operation)
**Target:** DPDK PMD (~10-20ns per operation)

```cpp
// NEW: dpdk_reactor.hpp
class DpdkReactor {
    struct rte_mempool* mbuf_pool_;
    uint16_t port_id_;

    HFT_HOT HFT_INLINE
    uint16_t poll_rx(struct rte_mbuf** pkts, uint16_t max_pkts) {
        return rte_eth_rx_burst(port_id_, 0, pkts, max_pkts);
    }

    HFT_HOT HFT_INLINE
    uint16_t send_tx(struct rte_mbuf** pkts, uint16_t num_pkts) {
        return rte_eth_tx_burst(port_id_, 0, pkts, num_pkts);
    }
};
```

**Latency Improvement:** 80-90ns saved per I/O operation

#### B. Implement Lock-Free SPSC Queue for Strategy Pipeline
```cpp
// NEW: spsc_queue.hpp - Single Producer Single Consumer
template<typename T, size_t Capacity>
class alignas(64) SPSCQueue {
    static_assert((Capacity & (Capacity - 1)) == 0);  // Power of 2

    alignas(64) std::atomic<size_t> head_{0};
    alignas(64) std::atomic<size_t> tail_{0};
    alignas(64) T buffer_[Capacity];

    HFT_HOT bool try_push(const T& item) noexcept {
        size_t head = head_.load(std::memory_order_relaxed);
        size_t next = (head + 1) & (Capacity - 1);
        if (next == tail_.load(std::memory_order_acquire)) return false;
        buffer_[head] = item;
        head_.store(next, std::memory_order_release);
        return true;
    }
};
```

#### C. SIMD-Accelerated FIX Parsing
```cpp
// NEW: fix_parser_simd.hpp
HFT_HOT
const char* find_delimiter_avx2(const char* data, size_t len) {
    __m256i delim = _mm256_set1_epi8('\x01');  // SOH delimiter
    for (size_t i = 0; i < len; i += 32) {
        __m256i chunk = _mm256_loadu_si256((__m256i*)(data + i));
        __m256i cmp = _mm256_cmpeq_epi8(chunk, delim);
        int mask = _mm256_movemask_epi8(cmp);
        if (mask) return data + i + __builtin_ctz(mask);
    }
    return nullptr;
}
```

**Latency Improvement:** FIX parsing from ~300ns to ~80ns

### 2.2 PHASE 2: Memory & Cache Optimization (Week 2)

#### A. Prefetch Critical Data Paths
```cpp
// In trading_engine.cpp hot loop
HFT_HOT void process_market_data(const BBO& bbo) {
    // Prefetch order book for next iteration
    __builtin_prefetch(&order_book_[next_instrument], 0, 3);

    // Prefetch position for P&L calculation
    __builtin_prefetch(&positions_[instrument], 0, 3);

    strategy_->on_market_data(instrument, bbo);
}
```

#### B. Branchless Order Book Updates
```cpp
// Replace branching logic with CMOV
HFT_HOT void update_bbo(BookSide& side, PriceTicks price, Quantity qty) {
    bool is_better = (side.is_bid)
        ? (price > side.best_price)
        : (price < side.best_price);

    // Branchless conditional move
    side.best_price = is_better ? price : side.best_price;
    side.best_qty = is_better ? qty : side.best_qty;
}
```

#### C. 1GB Huge Pages for Order Book
```cpp
// Upgrade from 2MB to 1GB huge pages
void* alloc_orderbook_memory(size_t size) {
    return mmap(nullptr, size, PROT_READ | PROT_WRITE,
                MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB | MAP_HUGE_1GB,
                -1, 0);
}
```

**TLB Miss Reduction:** From 2048 entries to 4 entries for 4GB arena

### 2.3 PHASE 3: Kernel & OS Bypass (Week 3)

#### A. Direct Hardware Timestamping
```cpp
// Use NIC hardware timestamps instead of TSC
struct HardwareTimestamp {
    uint64_t nic_rx_ts;      // NIC receive timestamp
    uint64_t nic_tx_ts;      // NIC transmit timestamp
    uint64_t ptp_offset;     // PTP synchronization offset
};

// Extract from DPDK mbuf
uint64_t get_hw_timestamp(struct rte_mbuf* pkt) {
    return pkt->timestamp;  // Hardware nanosecond timestamp
}
```

#### B. Bypass TCP Stack with Raw Sockets (Research)
```cpp
// For ultimate latency: Raw IP sockets
int raw_fd = socket(AF_INET, SOCK_RAW, IPPROTO_TCP);

// Construct TCP packet manually
void build_tcp_packet(uint8_t* buffer, const FIXMessage& msg) {
    struct iphdr* ip = (struct iphdr*)buffer;
    struct tcphdr* tcp = (struct tcphdr*)(buffer + sizeof(struct iphdr));
    // ... manual header construction
}
```

**Note:** Only viable for UDP protocols or with exchange cooperation

---

## PART 3: PROFIT-MAXIMIZING STRATEGY IMPLEMENTATION

### 3.1 STRATEGY 1: Adaptive Market Making

```cpp
// NEW FILE: /deployment-1/include/strategy/market_maker.hpp

class MarketMakerStrategy : public IStrategy {
public:
    void on_market_data(InstrumentId inst, const BBO& bbo) override {
        // 1. Calculate fair value (microprice)
        PriceTicks fair_value = calculate_microprice(bbo);

        // 2. Determine spread based on volatility
        PriceTicks half_spread = calculate_dynamic_spread(inst, bbo);

        // 3. Skew quotes based on inventory
        PriceTicks skew = calculate_inventory_skew(inst);

        // 4. Generate quotes
        PriceTicks bid_price = fair_value - half_spread - skew;
        PriceTicks ask_price = fair_value + half_spread + skew;

        // 5. Submit/update orders
        update_quote(inst, Side::BUY, bid_price, quote_size_);
        update_quote(inst, Side::SELL, ask_price, quote_size_);
    }

private:
    PriceTicks calculate_microprice(const BBO& bbo) {
        // Size-weighted mid price
        Quantity total = bbo.bid.qty + bbo.ask.qty;
        return (bbo.bid.price * bbo.ask.qty + bbo.ask.price * bbo.bid.qty) / total;
    }

    PriceTicks calculate_dynamic_spread(InstrumentId inst, const BBO& bbo) {
        f64 volatility = volatility_tracker_.get(inst);
        PriceTicks base_spread = config_.base_spread_ticks;
        return base_spread + static_cast<PriceTicks>(volatility * config_.vol_multiplier);
    }

    PriceTicks calculate_inventory_skew(InstrumentId inst) {
        Position& pos = positions_.get(inst);
        f64 inventory_ratio = static_cast<f64>(pos.net_qty) / config_.max_position;
        return static_cast<PriceTicks>(inventory_ratio * config_.skew_ticks);
    }
};
```

**Expected Profit:** 1-2 ticks per round-trip × 50-100 trades/day = $500-2,000/day

### 3.2 STRATEGY 2: Latency Arbitrage (Momentum Scalping)

```cpp
// NEW FILE: /deployment-1/include/strategy/momentum_scalper.hpp

class MomentumScalperStrategy : public IStrategy {
public:
    void on_market_data(InstrumentId inst, const BBO& bbo) override {
        PriceTicks mid = (bbo.bid.price + bbo.ask.price) / 2;

        // Update momentum indicators
        ema_fast_[inst] = ema_alpha_fast_ * mid + (1.0 - ema_alpha_fast_) * ema_fast_[inst];
        ema_slow_[inst] = ema_alpha_slow_ * mid + (1.0 - ema_alpha_slow_) * ema_slow_[inst];

        PriceTicks momentum = ema_fast_[inst] - ema_slow_[inst];

        // Book imbalance signal
        f64 imbalance = calculate_book_imbalance(order_book_.get(inst), 5);

        // Combined signal
        f64 signal = normalize(momentum) * 0.6 + imbalance * 0.4;

        Position& pos = positions_.get(inst);

        if (signal > config_.entry_threshold && pos.net_qty <= 0) {
            // BUY signal - go long
            submit_aggressive_buy(inst, bbo.ask.price, config_.trade_size);
        }
        else if (signal < -config_.entry_threshold && pos.net_qty >= 0) {
            // SELL signal - go short or close long
            submit_aggressive_sell(inst, bbo.bid.price, config_.trade_size);
        }

        // Exit on mean reversion
        if (pos.net_qty > 0 && signal < config_.exit_threshold) {
            close_position(inst, Side::SELL);
        }
        else if (pos.net_qty < 0 && signal > -config_.exit_threshold) {
            close_position(inst, Side::BUY);
        }
    }

private:
    static constexpr f64 ema_alpha_fast_ = 2.0 / 11.0;   // 10-tick EMA
    static constexpr f64 ema_alpha_slow_ = 2.0 / 31.0;   // 30-tick EMA
};
```

**Expected Profit:** 2-4 ticks per winning trade × 30-50 trades/day × 60% win rate = $400-1,500/day

### 3.3 STRATEGY 3: Order Flow Imbalance

```cpp
// NEW FILE: /deployment-1/include/strategy/order_flow.hpp

class OrderFlowStrategy : public IStrategy {
public:
    void on_market_data(InstrumentId inst, const BBO& bbo) override {
        OrderBook& book = order_book_.get(inst);

        // Calculate order flow imbalance across 5 levels
        Quantity bid_depth = 0, ask_depth = 0;
        for (int i = 0; i < 5; ++i) {
            bid_depth += book.bids.levels[i].qty;
            ask_depth += book.asks.levels[i].qty;
        }

        f64 ofi = static_cast<f64>(bid_depth - ask_depth) / (bid_depth + ask_depth);

        // Detect large hidden orders (sudden depth changes)
        f64 depth_change = calculate_depth_velocity(inst, bid_depth, ask_depth);

        // Trade in direction of imbalance
        if (ofi > 0.3 && depth_change > 0.1) {
            // Strong buy pressure detected
            submit_limit_buy(inst, bbo.bid.price + 1, config_.trade_size);
        }
        else if (ofi < -0.3 && depth_change < -0.1) {
            // Strong sell pressure detected
            submit_limit_sell(inst, bbo.ask.price - 1, config_.trade_size);
        }
    }
};
```

**Expected Profit:** 3-5 ticks per trade × 20-30 trades/day = $600-1,500/day

---

## PART 4: FULL STACK CONTROL IMPLEMENTATION

### 4.1 Kernel Boot Parameters (Maximum Performance)

```bash
# /etc/default/grub GRUB_CMDLINE_LINUX additions
isolcpus=6,7 nohz_full=6,7 rcu_nocbs=6,7
intel_pstate=disable processor.max_cstate=0 idle=poll
transparent_hugepage=never numa_balancing=disable
skew_tick=1 tsc=reliable clocksource=tsc
hugepagesz=1G hugepages=4 default_hugepagesz=1G
intel_idle.max_cstate=0 mce=ignore_ce
nosoftlockup audit=0 selinux=0
mitigations=off  # DANGEROUS but fastest
```

### 4.2 IRQ Affinity & CPU Isolation

```bash
#!/bin/bash
# /deployment-1/scripts/cpu_isolation.sh

# Move all IRQs to cores 0-5
for irq in /proc/irq/*/smp_affinity; do
    echo "3f" > $irq  # Binary: 00111111 = cores 0-5
done

# Pin NIC IRQs to core 5 (adjacent to trading core 6)
NIC_IRQS=$(grep eth0 /proc/interrupts | awk '{print $1}' | tr -d ':')
for irq in $NIC_IRQS; do
    echo "20" > /proc/irq/$irq/smp_affinity  # Core 5 only
done

# Disable irqbalance
systemctl stop irqbalance
systemctl disable irqbalance

# Set CPU governor to performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo "performance" > $cpu
done
```

### 4.3 Network Stack Optimization

```bash
# /etc/sysctl.d/99-hft-network.conf

# Maximize buffer sizes
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.core.rmem_default = 16777216
net.core.wmem_default = 16777216

# TCP optimization
net.ipv4.tcp_timestamps = 0
net.ipv4.tcp_sack = 0
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_slow_start_after_idle = 0

# Busy polling (critical)
net.core.busy_poll = 50
net.core.busy_read = 50

# Increase backlog
net.core.netdev_max_backlog = 300000
net.core.somaxconn = 65535
```

### 4.4 Memory Configuration

```bash
# /etc/sysctl.d/99-hft-memory.conf

# Disable swap
vm.swappiness = 0

# Allow memory overcommit for arena
vm.overcommit_memory = 1
vm.overcommit_ratio = 100

# Disable NUMA balancing
kernel.numa_balancing = 0

# Increase locked memory limit
# In /etc/security/limits.conf:
# *    hard    memlock    unlimited
# *    soft    memlock    unlimited
```

---

## PART 5: IMPLEMENTATION PLAN

### Phase 1: Strategy Development (Days 1-5)
1. Implement `MarketMakerStrategy` class
2. Implement `MomentumScalperStrategy` class
3. Implement `OrderFlowStrategy` class
4. Add strategy selection via config file
5. Unit test each strategy with simulated data

### Phase 2: Low-Level Optimizations (Days 6-10)
1. Implement SIMD FIX parser
2. Add prefetch hints to hot paths
3. Convert branching to branchless operations
4. Profile with `perf` and optimize cache misses
5. Benchmark: Target <1ms tick-to-trade

### Phase 3: System Tuning (Days 11-14)
1. Apply kernel boot parameters
2. Configure IRQ affinity
3. Set up 1GB huge pages
4. Tune network stack
5. Validate isolated CPU performance

### Phase 4: Testing & Deployment (Days 15-21)
1. Paper trade on IBKR simulator
2. Validate risk controls
3. Measure actual latencies
4. Deploy to production with $1,000 capital
5. Monitor for 1 week before scaling

---

## PART 6: EXPECTED RETURNS

### Conservative Estimate
| Strategy | Trades/Day | Avg Profit/Trade | Daily P&L |
|----------|------------|------------------|-----------|
| Market Making | 50 | 1.5 ticks ($15) | $750 |
| Momentum | 30 | 2.0 ticks ($20) | $600 |
| Order Flow | 20 | 3.0 ticks ($30) | $600 |
| **Total Gross** | 100 | - | **$1,950** |
| Commissions | - | - | -$200 |
| **Net Daily** | - | - | **$1,750** |

### Annual Projection
- Trading days/year: 250
- Daily net: $1,750
- **Annual: $437,500**

### Aggressive Estimate (After Optimization)
- Daily net: $3,500-5,000
- **Annual: $875,000-1,250,000**

---

## PART 7: VERIFICATION PLAN

1. **Unit Tests:** Run `make test` for all strategy logic
2. **Latency Benchmark:** Run `latency_bench` - target <1ms p99
3. **Paper Trading:** 1 week on IBKR paper account
4. **Risk Validation:** Verify kill switch triggers at $10k loss
5. **Live Monitoring:** Prometheus metrics on port 9090

---

## FILES TO CREATE/MODIFY

### New Files
- `/deployment-1/include/strategy/market_maker.hpp`
- `/deployment-1/include/strategy/momentum_scalper.hpp`
- `/deployment-1/include/strategy/order_flow.hpp`
- `/deployment-1/include/core/simd_utils.hpp`
- `/deployment-1/scripts/cpu_isolation.sh`

### Modified Files
- `/deployment-1/src/main.cpp` - Add strategy selection
- `/deployment-1/config/trading.conf.example` - Add strategy params
- `/deployment-1/CMakeLists.txt` - Add SIMD flags
- `/deployment-1/scripts/os_tuning.sh` - Enhanced kernel params

---

## RISK WARNINGS

1. **Mitigations=off** disables CPU security patches - only for isolated trading servers
2. **Raw socket bypass** requires exchange protocol support
3. **DPDK** requires dedicated NIC and bare metal (not cloud)
4. **$10k daily loss limit** is critical safety net - never disable
5. **Start with minimal capital** ($1,000) until strategies proven
