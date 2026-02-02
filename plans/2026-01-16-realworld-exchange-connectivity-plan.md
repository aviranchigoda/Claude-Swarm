# Real-World Exchange Connectivity Plan

## Objective
Connect the ultra-low-latency trading system to real-world financial exchanges as quickly as possible, integrate banking through proper clearing channels, and establish a closed engineering feedback loop with real market data.

---

## Executive Summary

Based on codebase exploration, the fastest path to live trading is:

1. **Immediate (Days 1-3):** Crypto exchange via existing Binance connector
2. **Short-term (Weeks 1-2):** ASX via ITCH/OUCH protocols (Australian market)
3. **Banking:** Via broker/clearing member (not direct CBA integration)

---

## Phase 1: Crypto Exchange Connectivity (Fastest Path)

### 1.1 Implementation Steps

The codebase already contains a Binance connector at `src/connectors/crypto/`. To activate:

```
Step 1: Create configuration file
  - File: config/binance_live.json
  - Contents: API credentials, trading pairs, risk limits

Step 2: Implement credential management
  - Use environment variables for API_KEY/API_SECRET
  - Never store credentials in code or config files

Step 3: Start with Binance Testnet
  - URL: testnet.binance.vision
  - Free test funds, real order flow
  - Validate full order lifecycle before live

Step 4: Enable live trading
  - Switch endpoint to api.binance.com
  - Start with minimal position sizes
  - Monitor all fills and account state
```

### 1.2 Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `config/binance_testnet.json` | Create | Testnet configuration |
| `config/binance_live.json` | Create | Production configuration |
| `src/connectors/crypto/binance_auth.c` | Extend | HMAC-SHA256 signing |
| `src/tests/test_binance_integration.c` | Create | Integration tests |

### 1.3 Risk Controls Required

- Maximum position size per symbol
- Maximum daily loss limit (hard stop)
- Order rate limiting (Binance: 1200/min)
- Kill switch on connectivity loss

---

## Phase 2: ASX Connectivity (Australian Exchange)

### 2.1 Prerequisites

1. **Broker Relationship**
   - Open account with ASX participant (CommSec, Interactive Brokers AU)
   - Request DMA (Direct Market Access) tier
   - Obtain FIX/ITCH credentials

2. **Regulatory**
   - No individual license required for personal trading
   - Broker handles compliance
   - Must not operate as unlicensed market maker

### 2.2 Implementation Steps

```
Step 1: Implement ASX ITCH 2.0 parser
  - Extend existing protocol.c
  - ASX uses modified NASDAQ ITCH format

Step 2: Implement ASX OUCH for order entry
  - Existing OUCH 4.2 code is compatible
  - Minor field adjustments for ASX

Step 3: Connect via broker gateway
  - Interactive Brokers provides API access
  - CommSec requires institutional tier for DMA

Step 4: Colocation (optional, for latency)
  - ALC (Australian Liquidity Centre) in Sydney
  - ~$5K/month for basic rack space
```

### 2.3 Files to Create/Modify

| File | Action | Purpose |
|------|--------|---------|
| `src/connectors/asx/asx_itch.c` | Create | ASX market data parser |
| `src/connectors/asx/asx_ouch.c` | Create | ASX order entry |
| `src/connectors/asx/asx_session.c` | Create | Session management |
| `config/asx_config.json` | Create | ASX connection config |

---

## Phase 3: Banking Integration

### 3.1 Architecture Reality

**Direct CBA integration is not possible for trading.**

The financial system architecture requires:

```
Your System --> Broker --> Clearing House --> Exchange
                  |
                  v
              Your Bank Account (CBA)
```

### 3.2 Recommended Approach

1. **Interactive Brokers Australia**
   - Supports AUD deposits from CBA
   - Provides API for balance queries
   - Handles settlement automatically
   - API for programmatic deposits/withdrawals

2. **Implementation**

```c
// Balance and funding queries via broker API
typedef struct {
    double available_cash;
    double settled_cash;
    double buying_power;
    double margin_used;
    char currency[4];
} account_balance_t;

// Broker API integration
result_t broker_get_balance(broker_session_t *session, account_balance_t *balance);
result_t broker_request_withdrawal(broker_session_t *session, double amount, const char *bank_ref);
```

3. **Files to Create**

| File | Purpose |
|------|---------|
| `src/connectors/broker/ib_api.c` | Interactive Brokers API client |
| `src/connectors/broker/account_manager.c` | Balance/margin tracking |

---

## Phase 4: Closed Feedback Loop Architecture

### 4.1 Modular Architecture Design

```
┌─────────────────────────────────────────────────────────────┐
│                    FEEDBACK LOOP MODULES                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │ Market Data  │──▶│   Strategy   │──▶│  Execution   │    │
│  │   Ingress    │   │    Engine    │   │    Engine    │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│         │                  │                  │             │
│         ▼                  ▼                  ▼             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │   Metrics    │   │    Risk      │   │    Fill      │    │
│  │  Collector   │   │   Monitor    │   │   Tracker    │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│         │                  │                  │             │
│         └──────────────────┼──────────────────┘             │
│                            ▼                                │
│                   ┌──────────────┐                          │
│                   │  Feedback    │                          │
│                   │  Aggregator  │                          │
│                   └──────────────┘                          │
│                            │                                │
│         ┌──────────────────┼──────────────────┐             │
│         ▼                  ▼                  ▼             │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐    │
│  │   Strategy   │   │    Risk      │   │   Alert      │    │
│  │   Tuning     │   │  Adjustment  │   │   System     │    │
│  └──────────────┘   └──────────────┘   └──────────────┘    │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### 4.2 Implementation Files

| Module | File | Purpose |
|--------|------|---------|
| Metrics Collector | `src/feedback/metrics_collector.c` | Latency, fill rate, slippage |
| Feedback Aggregator | `src/feedback/aggregator.c` | Combine all feedback streams |
| Strategy Tuner | `src/feedback/strategy_tuner.c` | Parameter adjustment |
| Risk Adjuster | `src/feedback/risk_adjuster.c` | Dynamic risk limits |
| Alert System | `src/feedback/alerts.c` | Real-time notifications |

### 4.3 Key Metrics to Track

```c
typedef struct {
    // Latency metrics
    latency_stats_t order_to_ack;      // Order submission to exchange ACK
    latency_stats_t order_to_fill;     // Order submission to fill
    latency_stats_t market_data_delay; // Exchange timestamp vs local receipt

    // Execution quality
    double fill_rate;                  // % of orders filled
    double cancel_rate;                // % of orders cancelled
    double reject_rate;                // % of orders rejected
    double slippage_bps;               // Average slippage in basis points

    // PnL tracking
    double realized_pnl;
    double unrealized_pnl;
    double fees_paid;

    // Risk metrics
    double max_drawdown;
    double sharpe_ratio;
    double var_95;                     // Value at Risk 95%
} trading_metrics_t;
```

---

## Phase 5: Real-World Testing Framework

### 5.1 Testing Levels

```
Level 1: Unit Tests (existing)
  └── Test individual components in isolation

Level 2: Integration Tests (to build)
  └── Test component interactions with mock exchange

Level 3: Testnet Trading (to build)
  └── Real order flow, fake money (Binance testnet)

Level 4: Paper Trading (to build)
  └── Real market data, simulated execution

Level 5: Live Trading (final)
  └── Real money, real execution, minimal size
```

### 5.2 Files to Create

| File | Purpose |
|------|---------|
| `src/tests/test_integration.c` | Component integration tests |
| `src/tests/test_exchange_mock.c` | Mock exchange for testing |
| `src/tests/test_testnet.c` | Binance testnet integration |
| `src/tests/test_paper.c` | Paper trading harness |

---

## Implementation Priority Order

### Week 1: Crypto Testnet (Immediate Value)

1. Create Binance testnet configuration
2. Implement credential management (env vars)
3. Write integration test for order lifecycle
4. Test full buy/sell cycle on testnet
5. Monitor and log all responses

### Week 2: Live Crypto Trading

1. Switch to live Binance endpoint
2. Trade with minimal position sizes ($10-50)
3. Implement real-time metrics collection
4. Build feedback dashboard

### Week 3: Feedback Loop

1. Implement metrics collector
2. Build feedback aggregator
3. Create alerting system
4. Test parameter adjustment

### Week 4+: ASX Integration

1. Open Interactive Brokers AU account
2. Implement ASX ITCH parser
3. Connect to IB API
4. Paper trade on ASX
5. Go live with minimal positions

---

## Risk Warnings

1. **Start Small:** Begin with $100-500, scale only after proving profitability
2. **Test Extensively:** Every change must pass testnet before live
3. **Monitor Constantly:** Never leave live system unattended initially
4. **Kill Switch Ready:** Always have manual kill switch accessible
5. **Regulatory:** Do not operate as unlicensed market maker or provide services to others

---

## Success Criteria

- [ ] Execute round-trip trade on Binance testnet
- [ ] Execute round-trip trade on Binance live
- [ ] Achieve <1ms order-to-ack latency
- [ ] Process real market data for 24h without crash
- [ ] Positive PnL over 1 week of live trading
- [ ] Feedback loop adjusting parameters automatically

---

## Summary

The fastest path to real-world trading:

1. **Day 1-3:** Binance testnet (existing connector)
2. **Day 4-7:** Binance live with minimal capital
3. **Week 2:** Full feedback loop operational
4. **Week 3+:** Expand to ASX via broker API

Banking integration happens through the broker (IB Australia), not directly with CBA. The broker handles all settlement and provides API access to account balances.
