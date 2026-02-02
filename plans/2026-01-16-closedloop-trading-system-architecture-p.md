# Closed-Loop Trading System Architecture Plan

## Objective
Deploy a fully closed-loop trading system connecting to real-world financial exchanges with Commonwealth Bank integration, using highly modular low-level engineering for maximum control over every layer.

## Current State Analysis

### What Exists (Strong Foundation)
- **C Core**: Order book (O(1) lookup), lock-free queues, risk manager (<100ns checks)
- **Strategies**: Arbitrage, market making with position tracking
- **Python Connector**: Binance WebSocket/REST with async I/O
- **Tests**: 46 tests passing (20 C, 26 Python)

### Critical Gap: The Feedback Loop is OPEN
```
CURRENT STATE (Broken):
┌─────────────────┐          ┌─────────────────┐
│  Python Layer   │          │    C Layer      │
│  - Exchange API │ ═══╳═══  │  - Strategies   │  ← NO CONNECTION
│  - WebSocket    │          │  - Risk Manager │
│  - Orders       │          │  - Order Book   │
└─────────────────┘          └─────────────────┘
```

## Target Architecture: Closed Loop

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CLOSED-LOOP TRADING ENGINE                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    SHARED MEMORY REGION (mmap)                       │   │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌───────────┐  │   │
│  │  │ Quote Ring  │  │ Order Ring  │  │  Fill Ring  │  │  Control  │  │   │
│  │  │  (SPSC)     │  │   (SPSC)    │  │   (SPSC)    │  │   Block   │  │   │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └───────────┘  │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│           ▲                  │                  ▲                           │
│           │                  ▼                  │                           │
│  ┌────────┴────────┐  ┌─────────────────┐  ┌───┴───────────┐              │
│  │  PYTHON LAYER   │  │    C ENGINE     │  │  PYTHON LAYER │              │
│  │                 │  │                 │  │               │              │
│  │  Quote Writer   │  │  Quote Reader   │  │  Fill Writer  │              │
│  │  ─────────────  │  │  ─────────────  │  │  ───────────  │              │
│  │  WebSocket RX   │  │  Strategy Run   │  │  Order API    │              │
│  │  Binance/OKX    │  │  Risk Check     │  │  Fill Parser  │              │
│  │                 │  │  Order Signal   │  │               │              │
│  └─────────────────┘  │                 │  └───────────────┘              │
│                       │  Order Writer ──┴──► Order Reader                 │
│                       └─────────────────┘                                  │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                      TELEMETRY & MONITORING                          │   │
│  │  - Latency histograms (quote→decision, order→ack, tick→trade)       │   │
│  │  - P&L real-time (realized + unrealized)                            │   │
│  │  - Position reconciliation (local vs exchange)                       │   │
│  │  - Entropy detection (stale quotes, disconnects, partial fills)     │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    BANKING INTEGRATION (AUD)                         │   │
│  │  - CommBank PayTo API (requires customer consent)                    │   │
│  │  - NPP/Osko for instant AUD deposits to exchange                    │   │
│  │  - CDR data access for balance monitoring                           │   │
│  │  - AUSTRAC compliance (>$10K reporting)                             │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Implementation Plan

### Phase 1: Shared Memory IPC Infrastructure (src/core/ipc.h, ipc.c)

**File: `src/core/ipc.h`**
```c
// Lock-free shared memory ring buffers
typedef struct {
    uint32_t magic;              // Validation marker
    uint32_t version;
    _Atomic(uint64_t) head;      // Producer writes
    _Atomic(uint64_t) tail;      // Consumer reads
    uint64_t capacity;
    uint64_t element_size;
    uint8_t data[];              // Flexible array member
} shm_ring_t;

// Shared memory region layout
typedef struct {
    shm_ring_t* quote_ring;      // Python → C (quotes)
    shm_ring_t* order_ring;      // C → Python (order signals)
    shm_ring_t* fill_ring;       // Python → C (fills)
    volatile uint64_t* heartbeat;
    volatile uint32_t* kill_switch;
} ipc_context_t;

// API
ipc_context_t* ipc_create(const char* shm_name, size_t quote_capacity,
                          size_t order_capacity, size_t fill_capacity);
ipc_context_t* ipc_attach(const char* shm_name);
bool ipc_push_quote(ipc_context_t* ctx, const quote_t* quote);
bool ipc_pop_quote(ipc_context_t* ctx, quote_t* quote);
bool ipc_push_order(ipc_context_t* ctx, const order_signal_t* order);
bool ipc_pop_order(ipc_context_t* ctx, order_signal_t* order);
bool ipc_push_fill(ipc_context_t* ctx, const fill_t* fill);
bool ipc_pop_fill(ipc_context_t* ctx, fill_t* fill);
```

### Phase 2: Main Trading Engine (src/engine/trading_engine.c)

**File: `src/engine/trading_engine.h`**
```c
typedef struct {
    // IPC
    ipc_context_t* ipc;

    // Core components
    order_book_t* order_books[MAX_SYMBOLS];
    risk_manager_t* risk_manager;
    arbitrageur_t* arbitrageur;
    market_maker_t* market_maker;

    // State
    volatile bool running;
    uint64_t tick_count;
    timestamp_ns_t last_tick;

    // Telemetry
    latency_histogram_t quote_latency;
    latency_histogram_t decision_latency;
    latency_histogram_t order_latency;

    // Config
    engine_config_t config;
} trading_engine_t;

// Main loop (runs on isolated CPU core)
void engine_run(trading_engine_t* engine);
```

**Core Loop Logic:**
```c
void engine_run(trading_engine_t* engine) {
    while (engine->running && !*engine->ipc->kill_switch) {
        timestamp_ns_t tick_start = get_timestamp_ns();

        // 1. DRAIN QUOTE RING (Python → C)
        quote_t quote;
        while (ipc_pop_quote(engine->ipc, &quote)) {
            order_book_update(engine->order_books[quote.symbol_idx], &quote);
            record_latency(&engine->quote_latency, tick_start - quote.local_ts);
        }

        // 2. RUN STRATEGIES
        arb_order_signal_t arb_signals[8];
        int n_arb = arbitrageur_scan(engine->arbitrageur, tick_start,
                                      arb_signals, 8);

        mm_order_signal_t mm_signals[20];
        int n_mm = market_maker_generate_quotes(engine->market_maker, tick_start,
                                                 mm_signals, 20);

        // 3. RISK CHECK & PUSH ORDERS (C → Python)
        for (int i = 0; i < n_arb; i++) {
            if (risk_manager_check_order(engine->risk_manager, ...) == RISK_OK) {
                ipc_push_order(engine->ipc, &arb_signals[i]);
            }
        }

        // 4. DRAIN FILL RING (Python → C)
        fill_t fill;
        while (ipc_pop_fill(engine->ipc, &fill)) {
            risk_manager_on_fill(engine->risk_manager, &fill);
            arbitrageur_on_fill(engine->arbitrageur, &fill);
            market_maker_on_fill(engine->market_maker, &fill);
        }

        // 5. UPDATE TELEMETRY
        record_latency(&engine->decision_latency, get_timestamp_ns() - tick_start);
        engine->tick_count++;
    }
}
```

### Phase 3: Python Orchestrator (src/orchestrator/orchestrator.py)

**File: `src/orchestrator/orchestrator.py`**
```python
class TradingOrchestrator:
    """
    Closes the feedback loop by:
    1. Writing quotes to shared memory (WebSocket → SHM)
    2. Reading order signals from shared memory (SHM → Exchange API)
    3. Writing fills to shared memory (Exchange API → SHM)
    """

    def __init__(self, config_path: str):
        self.config = load_config(config_path)
        self.ipc = SharedMemoryIPC(self.config.shm_name)
        self.exchanges: Dict[str, BaseExchange] = {}
        self.running = False

    async def run(self):
        """Main orchestration loop"""
        self.running = True

        # Start C engine in subprocess with CPU isolation
        self.engine_process = await self._start_engine()

        # Connect to exchanges
        for ex_config in self.config.exchanges:
            exchange = create_exchange(ex_config)
            await exchange.connect()
            self.exchanges[ex_config.name] = exchange

        # Run concurrent tasks
        await asyncio.gather(
            self._quote_writer_loop(),    # WebSocket → SHM
            self._order_reader_loop(),    # SHM → Exchange
            self._fill_writer_loop(),     # Exchange → SHM
            self._health_monitor_loop(),  # Watchdog
        )

    async def _quote_writer_loop(self):
        """Push quotes from exchanges to C engine via shared memory"""
        while self.running:
            for exchange in self.exchanges.values():
                for symbol in self.config.symbols:
                    quote = exchange.get_quote(symbol)
                    if quote:
                        self.ipc.push_quote(quote)
            await asyncio.sleep(0)  # Yield to event loop

    async def _order_reader_loop(self):
        """Read order signals from C engine and execute via API"""
        while self.running:
            order_signal = self.ipc.pop_order()
            if order_signal:
                exchange = self.exchanges[order_signal.exchange_id]
                try:
                    result = await exchange.send_order(
                        symbol=order_signal.symbol,
                        side=order_signal.side,
                        order_type=order_signal.order_type,
                        quantity=order_signal.quantity,
                        price=order_signal.price
                    )
                    # Record latency
                    self.telemetry.record_order_latency(
                        get_timestamp_ns() - order_signal.timestamp
                    )
                except Exception as e:
                    self.telemetry.record_error(str(e))
            await asyncio.sleep(0)

    async def _fill_writer_loop(self):
        """Push fills from exchanges to C engine"""
        # Subscribe to fill events from each exchange
        pass
```

### Phase 4: Telemetry System (src/telemetry/)

**File: `src/telemetry/metrics.h`**
```c
// Latency histogram with nanosecond precision
typedef struct {
    uint64_t buckets[64];        // Log-scale buckets: 100ns, 200ns, ..., 10s
    uint64_t count;
    uint64_t sum_ns;
    uint64_t min_ns;
    uint64_t max_ns;
    _Atomic(uint64_t) p50_ns;    // Updated periodically
    _Atomic(uint64_t) p99_ns;
} latency_histogram_t;

// Real-time P&L tracker
typedef struct {
    int64_t realized_pnl;
    int64_t unrealized_pnl;
    int64_t total_fees;
    int64_t gross_profit;
    int64_t max_drawdown;
    int64_t peak_pnl;
} pnl_tracker_t;

// Entropy detector
typedef struct {
    uint64_t stale_quote_count;
    uint64_t reconnect_count;
    uint64_t partial_fill_count;
    uint64_t rejection_count;
    timestamp_ns_t last_quote_time[MAX_EXCHANGES];
    bool exchange_healthy[MAX_EXCHANGES];
} entropy_detector_t;
```

**File: `src/telemetry/metrics.py`**
```python
class TelemetryExporter:
    """Export metrics for monitoring"""

    def __init__(self, port: int = 9090):
        self.metrics = {}

    def export_prometheus(self) -> str:
        """Generate Prometheus-compatible metrics"""
        lines = []
        lines.append(f'quote_latency_p50_ns {self.quote_latency.p50}')
        lines.append(f'quote_latency_p99_ns {self.quote_latency.p99}')
        lines.append(f'order_latency_p50_ns {self.order_latency.p50}')
        lines.append(f'realized_pnl_usd {self.pnl.realized}')
        lines.append(f'unrealized_pnl_usd {self.pnl.unrealized}')
        lines.append(f'stale_quotes_total {self.entropy.stale_count}')
        return '\n'.join(lines)
```

### Phase 5: Commonwealth Bank Integration (src/banking/)

**Important Regulatory Notes:**
- PayTo requires explicit customer consent via CommBank app
- 5-day minimum wait before first debit
- AUSTRAC reporting required for transactions >$10,000 AUD
- CDR accreditation required for third-party data access

**File: `src/banking/commbank.py`**
```python
class CommBankIntegration:
    """
    Commonwealth Bank integration for trading system funding.

    Workflow:
    1. User authorizes PayTo agreement via CommBank app
    2. System can then request debits (with 5-day initial wait)
    3. Funds sent via NPP/Osko to crypto exchange (instant)
    4. CDR API for balance monitoring (requires consent)
    """

    def __init__(self, config: BankingConfig):
        self.config = config
        self.payto_client = PayToClient(
            client_id=config.client_id,
            client_secret=config.client_secret,
            api_url="https://api.commbank.com.au/payto"
        )

    async def create_payment_agreement(
        self,
        customer_bsb: str,
        customer_account: str,
        max_amount: Decimal,
        frequency: str = "daily"
    ) -> PayToAgreement:
        """
        Create a PayTo agreement (customer must approve in CommBank app)
        """
        agreement = await self.payto_client.create_agreement(
            creditor_id=self.config.creditor_id,
            debtor_bsb=customer_bsb,
            debtor_account=customer_account,
            max_amount=str(max_amount),
            frequency=frequency
        )
        return agreement

    async def request_debit(
        self,
        agreement_id: str,
        amount: Decimal,
        description: str
    ) -> PaymentResult:
        """
        Request a debit under an approved PayTo agreement.
        Funds transferred via NPP (instant settlement).
        """
        # AUSTRAC compliance check
        if amount >= Decimal("10000"):
            await self._report_to_austrac(amount, description)

        result = await self.payto_client.initiate_payment(
            agreement_id=agreement_id,
            amount=str(amount),
            description=description
        )
        return result

    async def get_balance(self) -> Decimal:
        """
        Get account balance via CDR API (requires customer consent).
        """
        # CDR-compliant balance inquiry
        pass
```

**File: `src/banking/exchange_funding.py`**
```python
class ExchangeFundingManager:
    """
    Manages fund flow: CommBank → Exchange → Trading
    """

    async def fund_exchange(
        self,
        exchange: str,
        amount_aud: Decimal
    ) -> FundingResult:
        """
        Transfer AUD from CommBank to crypto exchange.

        Flow:
        1. PayTo debit from CommBank
        2. NPP transfer to exchange's Australian bank
        3. Exchange credits trading account
        """
        # Get exchange's deposit details
        deposit_info = await self.exchanges[exchange].get_aud_deposit_info()

        # Initiate PayTo transfer
        result = await self.commbank.request_debit(
            agreement_id=self.config.payto_agreement_id,
            amount=amount_aud,
            description=f"Trading deposit to {exchange}"
        )

        # Monitor for credit on exchange
        await self._wait_for_deposit(exchange, amount_aud)

        return FundingResult(
            amount=amount_aud,
            exchange=exchange,
            status="completed"
        )
```

### Phase 6: Entropy Handling System (src/entropy/)

**File: `src/entropy/handler.h`**
```c
typedef struct {
    // Quote freshness
    uint32_t quote_stale_threshold_us;
    uint64_t last_quote_time[MAX_EXCHANGES][MAX_SYMBOLS];

    // Connection health
    bool exchange_connected[MAX_EXCHANGES];
    uint64_t last_heartbeat[MAX_EXCHANGES];
    uint32_t reconnect_count[MAX_EXCHANGES];

    // Order tracking
    uint32_t pending_orders;
    uint32_t partial_fills;
    uint32_t rejections;

    // Circuit breaker
    bool circuit_open;
    uint64_t circuit_open_time;
    uint32_t circuit_breach_count;
} entropy_handler_t;

// Entropy detection functions
bool entropy_is_quote_stale(entropy_handler_t* eh, uint32_t exchange_id,
                            uint32_t symbol_id, timestamp_ns_t now);
bool entropy_is_exchange_healthy(entropy_handler_t* eh, uint32_t exchange_id);
void entropy_on_disconnect(entropy_handler_t* eh, uint32_t exchange_id);
void entropy_on_reconnect(entropy_handler_t* eh, uint32_t exchange_id);
void entropy_on_partial_fill(entropy_handler_t* eh, order_ref_t order_ref);
void entropy_on_rejection(entropy_handler_t* eh, order_ref_t order_ref);

// Circuit breaker
bool entropy_should_halt(entropy_handler_t* eh);
void entropy_trigger_circuit_breaker(entropy_handler_t* eh, const char* reason);
```

## Files to Create/Modify

### New Files (C)
1. `src/core/ipc.h` - Shared memory IPC definitions
2. `src/core/ipc.c` - Shared memory IPC implementation
3. `src/engine/trading_engine.h` - Engine definitions
4. `src/engine/trading_engine.c` - Main trading loop
5. `src/telemetry/metrics.h` - Telemetry structures
6. `src/telemetry/metrics.c` - Telemetry implementation
7. `src/entropy/handler.h` - Entropy handling definitions
8. `src/entropy/handler.c` - Entropy handling implementation

### New Files (Python)
1. `src/orchestrator/orchestrator.py` - Main Python orchestrator
2. `src/orchestrator/shm_ipc.py` - Python shared memory interface
3. `src/banking/commbank.py` - CommBank PayTo integration
4. `src/banking/exchange_funding.py` - Exchange funding manager
5. `src/telemetry/exporter.py` - Prometheus metrics exporter

### Modified Files
1. `Makefile` - Add new targets for engine, ipc, telemetry
2. `config/trading_config.json` - Add IPC and banking config
3. `src/exchange/crypto/exchange_connector.py` - Add fill callbacks

## Verification Plan

### Unit Tests
```bash
# Build all components
make all

# Run C tests
./bin/test_ipc
./bin/test_trading_engine
./bin/test_entropy_handler

# Run Python tests
pytest tests/test_orchestrator.py -v
pytest tests/test_commbank.py -v
```

### Integration Test (Testnet)
```bash
# 1. Start the system
python3 src/orchestrator/orchestrator.py --config config/testnet_config.json

# 2. Verify quote flow
# Check shared memory quote ring is receiving data
# Verify latency metrics: quote_latency_p99 < 1ms

# 3. Verify order flow
# Send manual test order through C engine
# Verify order appears on Binance testnet
# Verify fill propagates back through fill ring

# 4. Verify closed loop
# Place arbitrage opportunity (requires 2 exchanges on testnet)
# Verify automatic detection → order → fill → position update
```

### Performance Validation
```
Target Metrics:
- Quote to C engine: < 100 microseconds (via shared memory)
- Strategy decision: < 1 microsecond
- Order signal to API: < 1 millisecond
- Total tick-to-trade: < 5 milliseconds (without kernel bypass)
- Total tick-to-trade: < 50 microseconds (with io_uring, future)
```

## Deployment Sequence

### Day 1-2: IPC Infrastructure
- Implement `src/core/ipc.h` and `ipc.c`
- Python shared memory binding
- Unit tests for ring buffer operations

### Day 3-4: Trading Engine
- Implement `src/engine/trading_engine.c`
- Wire up existing strategies and risk manager
- CPU isolation configuration

### Day 5: Python Orchestrator
- Implement orchestrator with quote/order/fill loops
- Connect to existing exchange connector
- End-to-end flow test

### Day 6-7: Telemetry & Entropy
- Implement metrics collection
- Implement entropy detection
- Prometheus exporter

### Day 8-9: Banking Integration
- CommBank PayTo integration
- NPP transfer testing
- AUSTRAC compliance

### Day 10: Production Hardening
- Position reconciliation
- Graceful shutdown
- Kill switch testing

## Risk Mitigations

1. **Start on Testnet**: All initial deployment uses Binance testnet
2. **Small Position Limits**: Initial limits at 10% of target
3. **Kill Switch Ready**: Both manual and automatic triggers
4. **Position Reconciliation**: Regular sync between local and exchange state
5. **Entropy Detection**: Automatic halt on anomalies
