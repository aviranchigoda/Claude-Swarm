# Building Your Own Broker: Full-Stack Low-Level Architecture

## Executive Summary

Transform from broker-dependent trading system to **self-clearing broker-dealer** with complete control over every software layer. This plan builds on the existing ultra-low-latency C engine.

---

## Current State Analysis

### What Exists (Excellent Foundation)
| Component | Status | Latency |
|-----------|--------|---------|
| Custom allocators | ✅ Complete | 0ns hot-path |
| Lock-free queues | ✅ Complete | ~15ns |
| Kernel bypass (ef_vi/DPDK) | ✅ Complete | ~100-500ns |
| FIX 4.2/4.4 parser | ✅ Complete | ~80ns |
| ITCH 5.0 parser | ✅ Complete | ~100ns |
| OUCH 4.2 protocol | ✅ Complete | ~500ns |
| Order book | ✅ Complete | ~5-25ns |
| Risk engine | ✅ Complete | ~55ns |
| IB/Alpaca adapters | ✅ Complete | Variable |

### What's Missing (Broker Infrastructure)
| Component | Status | Priority |
|-----------|--------|----------|
| Direct exchange connectivity | ❌ | Critical |
| Clearing/settlement integration | ❌ | Critical |
| Client management system | ❌ | High |
| Regulatory reporting | ❌ | High |
| Multi-tenant architecture | ❌ | Medium |
| FIX session management | Partial | High |

---

## Architecture: Full-Stack Broker

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLIENT LAYER                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ FIX Gateway │  │ Binary API  │  │ REST/WebSocket Gateway  │  │
│  │   (4.2/4.4) │  │  (Custom)   │  │     (Retail Clients)    │  │
│  └──────┬──────┘  └──────┬──────┘  └────────────┬────────────┘  │
└─────────┼────────────────┼──────────────────────┼───────────────┘
          │                │                      │
          ▼                ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                    ORDER MANAGEMENT SYSTEM                       │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   Order State Machine                     │   │
│  │  NEW → PENDING_ACK → OPEN → PARTIAL → FILLED/CANCELED    │   │
│  └──────────────────────────────────────────────────────────┘   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │ Order Router│  │ Exec Algos  │  │   Position Management   │  │
│  │  (SOR/DMA)  │  │ VWAP/TWAP   │  │   (Real-time P&L)       │  │
│  └──────┬──────┘  └──────┬──────┘  └────────────┬────────────┘  │
└─────────┼────────────────┼──────────────────────┼───────────────┘
          │                │                      │
          ▼                ▼                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                      RISK LAYER (Branch-Free)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │  Pre-Trade  │  │  Real-Time  │  │    Margin Engine        │  │
│  │   Checks    │  │  Exposure   │  │  (Portfolio/Strategy)   │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                    EXCHANGE CONNECTIVITY                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   NASDAQ    │  │    NYSE     │  │         ASX             │  │
│  │ OUCH + ITCH │  │  FIX + XDP  │  │    FIX + ITCH           │  │
│  └──────┬──────┘  └──────┬──────┘  └────────────┬────────────┘  │
│         │                │                      │                │
│  ┌──────▼────────────────▼──────────────────────▼────────────┐  │
│  │              Kernel Bypass Network Layer                   │  │
│  │           (Solarflare ef_vi / DPDK / XDP)                  │  │
│  └────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────────────┐
│                   CLEARING & SETTLEMENT                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │    DTCC     │  │   NSCC      │  │      ASX Clear          │  │
│  │  (US Equi)  │  │ (Clearing)  │  │   (AU Settlement)       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Phase 1: Direct Exchange Connectivity (Bypass Brokers)

### 1.1 FIX Session Manager (New Component)

**Location:** `src/fix/fix_session.h`

```c
// Full FIX session lifecycle management
typedef struct {
    // Session identity
    char sender_comp_id[32];
    char target_comp_id[32];
    uint32_t msg_seq_num_out;
    uint32_t msg_seq_num_in;

    // Connection state
    fix_session_state_t state;  // DISCONNECTED, LOGON_SENT, ACTIVE, etc.

    // Heartbeat management
    uint64_t last_sent_time_ns;
    uint64_t last_recv_time_ns;
    uint32_t heartbeat_interval_sec;

    // Message store (for resend)
    fix_msg_store_t* msg_store;

    // Network (kernel bypass)
    network_interface_t* net;

    // Callbacks
    fix_session_callbacks_t callbacks;
} fix_session_t;

// Key operations
int fix_session_connect(fix_session_t* session);
int fix_session_logon(fix_session_t* session);
int fix_session_send_order(fix_session_t* session, const order_t* order);
int fix_session_process_incoming(fix_session_t* session);  // Non-blocking
```

**Features:**
- Sequence number gap detection and resend requests
- Heartbeat/TestRequest handling
- Session-level encryption (TLS 1.3 optional, adds ~5μs)
- Message store for regulatory compliance

### 1.2 Exchange-Specific Adapters

**NASDAQ Direct (Already have OUCH/ITCH):**
- Enhance OUCH with full session management
- Add SoupBinTCP transport layer
- Implement NASDAQ certification test suite

**NYSE/Arca:**
- NYSE Pillar gateway (binary protocol)
- XDP market data feed
- FIX 4.2 order entry

**ASX (Australian Securities Exchange):**
- ASX Trade gateway (FIX 5.0)
- ASX ITCH market data
- Chi-X Australia (alternative venue)

### 1.3 Smart Order Router (SOR)

**Location:** `src/router/smart_order_router.h`

```c
typedef struct {
    // Venue scoring
    venue_score_t venue_scores[MAX_VENUES];

    // Routing strategies
    routing_strategy_t strategy;  // BEST_PRICE, MINIMIZE_IMPACT, SWEEP, etc.

    // Order splitting
    split_config_t split_config;

    // Latency tracking per venue
    latency_stats_t venue_latency[MAX_VENUES];

    // Fill probability model
    fill_model_t* fill_model;
} smart_order_router_t;

// Route decision in <100ns
venue_id_t sor_route_order(smart_order_router_t* sor, const order_t* order);
```

---

## Phase 2: Multi-Tenant Client Infrastructure

### 2.1 Client Session Management

```c
typedef struct {
    uint64_t client_id;
    char api_key[64];

    // Rate limits (per client)
    rate_limiter_t order_rate;
    rate_limiter_t msg_rate;

    // Position limits
    int64_t max_position_per_symbol;
    int64_t max_gross_position;
    int64_t max_notional;

    // Connection
    connection_type_t conn_type;  // FIX, BINARY, WEBSOCKET
    void* conn_handle;

    // Account state (lock-free updates)
    _Atomic int64_t cash_balance;
    _Atomic int64_t buying_power;
    _Atomic int64_t equity;
} client_session_t;
```

### 2.2 Binary Protocol (Ultra-Low Latency Clients)

Custom binary protocol for institutional clients:

```c
// 32-byte order message (cache-line friendly)
typedef struct __attribute__((packed)) {
    uint8_t  msg_type;        // 1: NewOrder, 2: Cancel, 3: Replace
    uint8_t  side;            // 1: Buy, 2: Sell
    uint16_t symbol_id;       // Internal symbol ID
    uint32_t quantity;
    int64_t  price;           // Fixed-point (8 decimals)
    uint64_t client_order_id;
    uint64_t timestamp_ns;
} binary_order_msg_t;
_Static_assert(sizeof(binary_order_msg_t) == 32, "Must be 32 bytes");
```

### 2.3 WebSocket Gateway (Retail/Web Clients)

- JSON-based messaging for ease of integration
- Real-time market data streaming
- Order status push notifications
- Rate limited appropriately

---

## Phase 3: Clearing & Settlement Integration

### 3.1 Clearing Options

| Option | Control Level | Capital Req | Complexity |
|--------|---------------|-------------|------------|
| Self-clearing | Maximum | $10M+ | Extreme |
| Correspondent clearing | High | $1M+ | High |
| Fully disclosed | Medium | $100K+ | Medium |
| Omnibus | Low | $50K+ | Low |

**Recommendation:** Start with correspondent clearing (use clearing firm), build toward self-clearing.

### 3.2 DTCC/NSCC Integration (US Markets)

```c
// Trade reporting interface
typedef struct {
    // Connection to DTCC
    fix_session_t* dtcc_session;

    // Trade submission
    int (*submit_trade)(trade_report_t* trade);

    // Settlement instructions
    int (*submit_settlement)(settlement_instr_t* instr);

    // Reconciliation
    int (*reconcile_positions)(date_t settle_date);
} clearing_interface_t;
```

### 3.3 Position Reconciliation Engine

```c
// End-of-day reconciliation
typedef struct {
    // Internal position state
    position_t internal_positions[MAX_SYMBOLS];

    // Clearing firm reported positions
    position_t clearing_positions[MAX_SYMBOLS];

    // Breaks
    position_break_t breaks[MAX_BREAKS];
    int num_breaks;

    // Auto-resolution rules
    break_resolution_rule_t rules[MAX_RULES];
} reconciliation_engine_t;
```

---

## Phase 4: Regulatory Compliance Layer

### 4.1 Audit Trail (SEC Rule 17a-4 / ASIC)

```c
// Immutable audit log (append-only)
typedef struct {
    // Write-ahead log
    int fd;
    void* mmap_base;
    size_t mmap_size;
    _Atomic uint64_t write_offset;

    // Checksums for tamper detection
    uint64_t running_checksum;

    // Timestamps (hardware if available)
    bool hw_timestamps;
} audit_log_t;

// Every order action logged with <1μs overhead
void audit_log_order(audit_log_t* log, const order_t* order,
                     order_action_t action, uint64_t timestamp_ns);
```

### 4.2 Regulatory Reporting

- **CAT (Consolidated Audit Trail)** - US equities
- **OATS** - FINRA reporting
- **ASIC Market Integrity Rules** - Australian reporting
- **MiFID II** - European reporting (if applicable)

### 4.3 Best Execution Analysis

```c
typedef struct {
    // Per-order execution quality
    int64_t arrival_price;
    int64_t exec_price;
    int64_t midpoint_at_exec;
    uint64_t time_to_fill_ns;

    // Venue analysis
    venue_execution_stats_t venue_stats[MAX_VENUES];

    // Slippage tracking
    int64_t total_slippage;
    int64_t avg_slippage_bps;
} best_execution_analyzer_t;
```

---

## Phase 5: Operational Infrastructure

### 5.1 Disaster Recovery

- **Primary:** Co-located at exchange data center (NY4/NY5 for US)
- **Secondary:** Geographically separate warm standby
- **Failover:** <30 second RTO (Recovery Time Objective)

### 5.2 Monitoring & Alerting

```c
typedef struct {
    // System health
    _Atomic uint64_t orders_processed;
    _Atomic uint64_t latency_p99_ns;
    _Atomic uint64_t latency_max_ns;

    // Risk metrics
    _Atomic int64_t gross_exposure;
    _Atomic int64_t net_exposure;
    _Atomic int64_t daily_pnl;

    // Alerts
    alert_threshold_t thresholds[MAX_ALERTS];
    alert_callback_t on_alert;
} system_monitor_t;
```

### 5.3 Kill Switch Infrastructure

```c
// Multi-level kill switch
typedef struct {
    _Atomic bool global_kill;           // Kill everything
    _Atomic bool new_orders_disabled;   // No new orders, allow cancels
    _Atomic uint64_t symbol_kills;      // Bitmask per symbol
    _Atomic uint64_t client_kills;      // Bitmask per client
    _Atomic uint64_t venue_kills;       // Bitmask per venue
} kill_switch_t;

// <10ns check
static inline bool is_trading_allowed(kill_switch_t* ks,
                                       uint16_t symbol_id,
                                       uint64_t client_id,
                                       uint8_t venue_id) {
    uint64_t global = atomic_load_explicit(&ks->global_kill, memory_order_relaxed);
    if (UNLIKELY(global)) return false;
    // ... branch-free checks for other levels
}
```

---

## Implementation Priority

### Critical Path (Must Have)
1. **FIX Session Manager** - Full session lifecycle
2. **Direct Exchange Adapter** (pick one: ASX or NASDAQ)
3. **Correspondent Clearing Integration**
4. **Audit Trail System**
5. **Client Session Management**

### High Priority
6. Smart Order Router
7. Multi-venue support
8. Regulatory reporting
9. Best execution analysis
10. Binary client protocol

### Future
11. Self-clearing capability
12. Additional exchanges
13. Options/derivatives support
14. Cross-border settlement

---

## Regulatory Requirements by Jurisdiction

### Australia (ASX)
- **AFSL** (Australian Financial Services License)
- **ASX Market Participant** status
- **ASIC Market Integrity Rules** compliance
- Capital adequacy: ~$500K-$1M minimum

### United States (NASDAQ/NYSE)
- **Broker-Dealer Registration** (SEC/FINRA)
- **SRO Membership** (FINRA, exchange memberships)
- **Net Capital Rule** (SEC Rule 15c3-1): $250K minimum
- **Customer Protection Rule** (SEC Rule 15c3-3)

---

## Key Files to Create/Modify

### New Files
| File | Purpose |
|------|---------|
| `src/fix/fix_session.h` | FIX session management |
| `src/fix/fix_session.c` | FIX session implementation |
| `src/router/smart_order_router.h` | SOR interface |
| `src/router/smart_order_router.c` | SOR implementation |
| `src/clearing/clearing_interface.h` | Clearing abstraction |
| `src/clearing/dtcc_adapter.c` | DTCC integration |
| `src/audit/audit_log.h` | Audit trail |
| `src/client/client_session.h` | Client management |
| `src/client/binary_protocol.h` | Binary client protocol |
| `src/gateway/websocket_gateway.c` | WebSocket for retail |

### Modify Existing
| File | Changes |
|------|---------|
| `src/live/broker_interface.h` | Add direct exchange type |
| `src/protocol/ouch_protocol.h` | Add SoupBinTCP session |
| `src/core/order_gateway.h` | Multi-venue routing |
| `src/risk/risk_engine.h` | Per-client limits |

---

## Verification Plan

### Unit Tests
- FIX session state machine transitions
- Order routing logic
- Clearing message formatting
- Audit log integrity

### Integration Tests
- FIX session with exchange simulator
- End-to-end order flow
- Position reconciliation

### Performance Tests
- FIX session throughput (target: >100K msg/sec)
- Order routing latency (target: <100ns)
- Multi-client concurrent load

### Compliance Tests
- Audit trail completeness
- Regulatory report accuracy
- Best execution analysis

---

## Open Questions for User

1. **Jurisdiction Priority:** ASX (Australia) or US (NASDAQ/NYSE) first?
2. **Clearing Model:** Correspondent clearing initially, or direct clearing?
3. **Client Types:** Institutional only (FIX/Binary) or also retail (WebSocket)?
4. **Capital Available:** Determines regulatory pathway
5. **Timeline Constraints:** Regulatory approval can take 6-18 months
