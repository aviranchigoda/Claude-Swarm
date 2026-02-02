# Broker Infrastructure Build Plan

## Configuration
- **Clearing Model**: Correspondent clearing (Wedbush/Vision recommended)
- **Exchange Access**: Direct market access with kernel bypass
- **Client Model**: Proprietary trading only
- **Asset Class**: US Equities
- **Optimization**: Minimum latency (sub-microsecond target)

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CO-LOCATION (Mahwah/NY4)                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  MARKET DATA (UDP)              ORDER ENTRY (TCP)        CLEARING (TCP) │
│  ┌────────────────┐            ┌────────────────┐      ┌──────────────┐ │
│  │ NASDAQ ITCH 5.0│            │ NASDAQ OUCH 4.2│      │ FIX 4.4 Drop │ │
│  │ NYSE XDP       │            │ NYSE Pillar    │      │ Copy Session │ │
│  │ ARCA Integrated│            │ ARCA Direct    │      │              │ │
│  └───────┬────────┘            └───────┬────────┘      └──────┬───────┘ │
│          │ ef_vi/DPDK                  │ ef_vi/Onload         │ TCP     │
│          │ Zero-Copy                   │ TCP_NODELAY          │         │
│          ▼                             ▼                      ▼         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    TRADING ENGINE (Existing C Core)               │  │
│  │  ┌─────────┐  ┌──────────┐  ┌───────────┐  ┌────────────┐        │  │
│  │  │Book Bld │→ │Strategy  │→ │Risk Engine│→ │Order Router│        │  │
│  │  │ ~80ns   │  │          │  │   ~55ns   │  │   ~30ns    │        │  │
│  │  └─────────┘  └──────────┘  └───────────┘  └────────────┘        │  │
│  │                                                                   │  │
│  │  ┌─────────┐  ┌──────────┐  ┌───────────┐  ┌────────────┐        │  │
│  │  │Position │  │CAT       │  │Clearing   │  │Kill Switch │        │  │
│  │  │Manager  │  │Reporter  │  │Interface  │  │  ~15ns     │        │  │
│  │  └─────────┘  └──────────┘  └───────────┘  └────────────┘        │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  TARGET: <500ns wire-to-wire                                           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Phases

### Phase 1: Network & Protocol Layer (Weeks 1-4)

#### 1.1 ef_vi Kernel Bypass Integration
Create `src/broker/efvi_receiver.h`:
- Zero-copy UDP receive for market data
- Hardware timestamp extraction
- Multicast group management

Key structures:
```c
typedef struct {
    ef_driver_handle dh;
    ef_vi vi;
    ef_pd pd;
    uint8_t* dma_pool;          // Huge page backed
    int64_t ts_offset_ns;       // PTP correction
} efvi_receiver_t;
```

Modify: `src/core/network.h` - Add ef_vi backend alongside existing socket fallback

#### 1.2 NYSE Pillar Protocol
Create `src/protocol/nyse_pillar.h`:
- Binary message format (similar pattern to existing OUCH)
- Session management (logon, heartbeat, logout)
- Order entry: New, Modify, Cancel
- Response parsing: Ack, Fill, Reject

Template from: `src/protocol/ouch_builder.h`

#### 1.3 ARCA Direct Protocol
Create `src/protocol/arca_direct.h`:
- Same structure as NYSE Pillar
- Venue-specific message fields

---

### Phase 2: Exchange Gateway Manager (Weeks 5-6)

#### 2.1 Unified Gateway
Create `src/broker/exchange_gateway.h`:
```c
typedef struct {
    nasdaq_session_t nasdaq;     // Existing OUCH
    nyse_pillar_session_t nyse;  // New
    arca_direct_session_t arca;  // New

    venue_id_t primary_venue[MAX_SYMBOLS];
    bool auto_failover;
} exchange_gateway_t;
```

#### 2.2 Session Management
- SoupBinTCP framing for NASDAQ
- Sequence number tracking per venue
- Heartbeat management
- Automatic reconnection

Modify: `src/gateway/order_gateway.h` - Add multi-venue routing

---

### Phase 3: Order Management System (Weeks 7-9)

#### 3.1 Lock-Free Order State Machine
Create `src/broker/order_state.h`:
- Atomic state transitions (CAS-based)
- States: PENDING_NEW → NEW → PARTIAL_FILL → FILLED
- State transition validation matrix

#### 3.2 Crash Recovery Journal
Create `src/broker/order_journal.h`:
- Memory-mapped write-ahead log
- CRC32 integrity validation
- Recovery on startup

#### 3.3 Fill Aggregation
Create `src/broker/fill_aggregator.h`:
- VWAP calculation (O(1) per fill)
- Per-venue fill tracking
- Multi-fill order reconstruction

---

### Phase 4: Clearing Firm Integration (Weeks 10-12)

#### 4.1 FIX Drop Copy Session
Create `src/broker/clearing_fix.h`:
- FIX 4.4 session management
- Additional tags: Account(1), ExecBroker(76), ClearingFirm(439)
- Execution report parsing

Modify: `src/protocol/fix_parser.h` - Add clearing-specific tags

#### 4.2 Position Reconciliation
Create `src/broker/position_recon.h`:
- SOD position file parsing (DTCC format)
- Real-time vs clearing firm comparison
- Discrepancy alerting

#### 4.3 Buying Power Integration
Create `src/broker/buying_power.h`:
- Real-time BP tracking from clearing firm
- Pre-trade BP check integration with risk engine
- Margin requirement calculation

Modify: `src/risk/risk_engine.h` - Add buying power check to hot path

---

### Phase 5: Regulatory Compliance (Weeks 13-16)

#### 5.1 CAT Reporting
Create `src/regulatory/cat_reporter.h`:
- Event types: MENO, MEOR, MEOA, MEOM, MEOC, MEOT
- firmDesignatedID linkage
- Millisecond timestamp formatting
- Async file output (non-blocking)

Integration points:
- `gateway_submit_order()` → MENO event
- `gateway_on_executed()` → MEOT event
- `gateway_on_canceled()` → MEOC event

#### 5.2 SEC Rule 15c3-5 Enhancements
Modify `src/risk/risk_engine.h`:
```c
// Add to risk_limits_t:
int64_t max_price_deviation_pct;    // Fat finger prevention
qty_t unusual_size_threshold;       // Erroneous order detection
bool luld_halted[MAX_SYMBOLS];      // LULD integration
bool restricted_symbols[MAX_SYMBOLS];
```

Create `src/risk/erroneous_order.h`:
- Reference price tracking
- Price deviation check
- Unusual size detection

Create `src/risk/market_halt.h`:
- LULD halt status per symbol
- Market-wide circuit breaker state

#### 5.3 Short Sale Locate Tracking
Create `src/broker/locate_manager.h`:
- Easy-to-borrow list management
- Locate reservation tracking
- REG SHO threshold list integration

---

### Phase 6: High Availability (Weeks 17-18)

#### 6.1 Hot Standby Synchronization
Create `src/ha/standby_sync.h`:
- Shared memory position sync
- Heartbeat-based primary detection
- Sub-second failover target

#### 6.2 Audit Trail
Create `src/audit/trade_log.h`:
- 17a-4 compliant record keeping
- WORM-compatible output format
- 6-year retention structure

---

## Files to Create

| File | Description | LOC Est. |
|------|-------------|----------|
| `src/broker/efvi_receiver.h` | ef_vi kernel bypass RX | 400 |
| `src/broker/efvi_sender.h` | ef_vi kernel bypass TX | 300 |
| `src/protocol/nyse_pillar.h` | NYSE Pillar protocol | 600 |
| `src/protocol/arca_direct.h` | ARCA Direct protocol | 400 |
| `src/broker/exchange_gateway.h` | Multi-venue gateway | 500 |
| `src/broker/order_state.h` | Lock-free OMS | 400 |
| `src/broker/order_journal.h` | Crash recovery | 300 |
| `src/broker/fill_aggregator.h` | Fill aggregation | 200 |
| `src/broker/clearing_fix.h` | Clearing FIX session | 500 |
| `src/broker/position_recon.h` | Position reconciliation | 300 |
| `src/broker/buying_power.h` | BP management | 250 |
| `src/regulatory/cat_reporter.h` | CAT reporting | 400 |
| `src/risk/erroneous_order.h` | Fat finger prevention | 150 |
| `src/risk/market_halt.h` | LULD/MWCB tracking | 200 |
| `src/broker/locate_manager.h` | Short sale locates | 250 |
| `src/ha/standby_sync.h` | HA synchronization | 350 |
| `src/audit/trade_log.h` | 17a-4 audit trail | 300 |

## Files to Modify

| File | Changes |
|------|---------|
| `src/core/network.h` | Add ef_vi backend |
| `src/protocol/fix_parser.h` | Add clearing tags (1, 76, 439, 440) |
| `src/risk/risk_engine.h` | Add 15c3-5 checks, BP integration |
| `src/gateway/order_gateway.h` | Multi-venue routing, CAT hooks |
| `src/risk/kill_switch.h` | Regulatory audit trail |

---

## Latency Budget

| Component | Target | Notes |
|-----------|--------|-------|
| NIC RX (ef_vi) | 50ns | Zero-copy DMA |
| ITCH parse | 60ns | Existing ~80ns |
| Book update | 80ns | |
| Strategy | 100ns | User-defined |
| Risk check | 55ns | Existing ~55ns |
| Order build | 25ns | OUCH existing |
| NIC TX | 50ns | ef_vi |
| **Total** | **<450ns** | Target <500ns |

---

## Regulatory Parallel Track

While engineering proceeds, these business/legal tasks run in parallel:

### Immediate (Month 1)
- [ ] Entity formation (Delaware LLC)
- [ ] Legal counsel engagement (securities specialist)
- [ ] Clearing firm outreach (Wedbush, Vision, Apex)

### Month 2-3
- [ ] Clearing agreement negotiation
- [ ] WSP (Written Supervisory Procedures) drafting
- [ ] BCP (Business Continuity Plan) drafting
- [ ] Net capital allocation ($500K-$1M)

### Month 4-5
- [ ] Form BD filing
- [ ] FINRA NMA (New Member Application)
- [ ] Principal registration (Series 7/24/27)

### Month 6-10
- [ ] FINRA review process
- [ ] Exchange connectivity certification
- [ ] CAT reporter ID registration

---

## Verification Strategy

### Unit Tests
- Each protocol builder: Latency benchmark (<30ns)
- Risk checks: Boundary condition validation
- State machine: Transition matrix coverage

### Integration Tests
- Exchange simulator (mock OUCH/Pillar responders)
- Clearing firm simulator (FIX drop copy)
- Market data replay (historical ITCH)

### Production Simulation
- 100K orders/second burst test
- 8-hour memory leak detection
- Failover scenario testing
- Wire-to-wire latency profiling

### Compliance Testing
- CAT file format validation
- 15c3-5 control verification
- Kill switch activation test
- Position reconciliation accuracy

---

## First Implementation Target

**Start with NYSE Pillar protocol** (`src/protocol/nyse_pillar.h`):
1. Mirrors existing OUCH structure
2. Opens NYSE/ARCA access (60%+ of US equity volume)
3. Self-contained module (no dependencies on other new code)
4. Can be tested against NYSE's market simulator
