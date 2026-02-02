# Trading System Deployment Plan

## Goal
Deploy trading software to financial exchanges starting with paper trading, then expand to multiple exchanges including Polymarket for automated market making.

## Current State
- **C Trading System** (`/home/ai_dev/workspace/trading/`): Ultra-low-latency HFT framework with Binance + IBKR integrations
- **Polymarket Bot** (`/home/ai_dev/workspace/polymarket-bot/`): Production-ready Python async system for prediction markets
- **User Status**: Has MetaMask wallet, starting from scratch on infrastructure

---

## Phase 1: Binance Paper Trading (Fastest Path)

### Step 1.1: Create Binance Account & API Keys
1. Sign up at https://testnet.binancefuture.com (testnet)
2. Generate API key and secret for testnet
3. Fund testnet account (free test funds available)

### Step 1.2: Configure Trading System
**Files to modify:**
- `config/binance_testnet.json` - Add API credentials
- `src/main_trader.c` - Verify paper trading mode

```bash
# Build the system
cd /home/ai_dev/workspace/trading
make trader

# Run in paper mode
./bin/trader --mode paper --exchange binance --config config/binance_testnet.json
```

### Step 1.3: Validate Paper Trading
- Monitor order submission latency
- Verify risk limits are enforced
- Check P&L tracking accuracy

---

## Phase 2: Polymarket Setup (Market Making)

### Step 2.1: Wallet & Funding Setup
1. Export MetaMask private key (for bot signing)
2. Bridge USDC to Polygon network
3. Approve USDC spending for Polymarket contracts

### Step 2.2: Configure Polymarket Bot
**Files to configure:**
- `/home/ai_dev/workspace/polymarket-bot/.env`

```env
POLYMARKET_API_URL=https://clob.polymarket.com
POLYMARKET_WS_URL=wss://ws-subscriptions-clob.polymarket.com/ws
WALLET_PRIVATE_KEY=0x<your-key>
POLYGON_RPC_URL=https://polygon-rpc.com
DATABASE_URL=postgresql://localhost/polymarket
REDIS_URL=redis://localhost:6379
```

### Step 2.3: Infrastructure Setup
```bash
# Install PostgreSQL and Redis
sudo apt install postgresql redis-server

# Create database
createdb polymarket

# Install Python dependencies
cd /home/ai_dev/workspace/polymarket-bot
pip install -r requirements.txt
```

### Step 2.4: Run in Dry-Run Mode
```bash
# Start with dry-run (no real orders)
python -m src.main --mode dry-run

# Graduate to paper trading
python -m src.main --mode paper
```

---

## Phase 3: Multi-Exchange Expansion

### Priority Order for Additional Exchanges

| Exchange | Type | Effort | Notes |
|----------|------|--------|-------|
| Coinbase | Crypto | Low | Similar REST/WebSocket API to Binance |
| Kraken | Crypto | Low | Well-documented API |
| Interactive Brokers | Traditional | Medium | Already have connector code |
| Alpaca | US Stocks | Low | REST API, commission-free |
| dYdX | Crypto Derivatives | Medium | Similar to Polymarket (blockchain) |

### Step 3.1: Add Coinbase Connector
- Reuse Binance connector pattern
- Implement HMAC-SHA256 authentication
- Add WebSocket market data handler

### Step 3.2: Add Alpaca Connector (US Stocks)
- REST API for orders
- WebSocket for market data
- Paper trading available

---

## Phase 4: IPC Bridge (C + Python Integration)

For unified risk management across both systems:

### New Files to Create
```
src/connectors/polymarket/
├── ipc_client.c          # Unix socket client
├── ipc_client.h
├── polymarket_types.h    # Data structures
└── polymarket_gateway.c  # Order gateway adapter
```

### Python IPC Server
```
polymarket-bot/src/ipc/
├── server.py             # Unix socket listener
├── protocol.py           # Message format
└── integration.py        # Request handlers
```

---

## Verification Steps

### Binance Paper Trading
- [ ] API keys configured and tested
- [ ] Build succeeds with `make trader`
- [ ] Can connect to testnet WebSocket
- [ ] Order submission works
- [ ] Risk limits block oversized orders
- [ ] P&L tracking shows accurate numbers

### Polymarket
- [ ] MetaMask wallet funded with MATIC (gas) + USDC
- [ ] Database and Redis running
- [ ] Can fetch market data via API
- [ ] Dry-run mode shows correct order calculations
- [ ] Paper trading executes without errors

### Integration
- [ ] IPC bridge connects C and Python systems
- [ ] Signals flow from C strategy to Polymarket
- [ ] Risk limits enforced across both systems

---

## Critical Files

### C Trading System
- `src/main_trader.c` - Entry point
- `src/connectors/crypto/binance_connector.c` - Binance integration
- `src/risk/risk_engine.c` - Risk management
- `config/binance_testnet.json` - Configuration

### Polymarket Bot
- `src/api/polymarket.py` - API client
- `src/execution/engine.py` - Execution logic
- `src/risk/manager.py` - Risk management
- `.env` - Credentials

---

## Estimated Timeline (Effort, Not Calendar)

| Phase | Effort |
|-------|--------|
| Phase 1: Binance Paper | 1-2 hours setup |
| Phase 2: Polymarket | 2-4 hours setup |
| Phase 3: Multi-exchange | 1-2 days per exchange |
| Phase 4: IPC Bridge | 2-3 days development |

---

## Risk Considerations

1. **Never use real funds until paper trading is stable**
2. **Start with small position sizes** ($10-50 orders)
3. **Monitor gas costs on Polymarket** (can eat profits on small trades)
4. **Keep kill switch enabled** at all times
5. **Blockchain latency** means Polymarket strategies must operate at second/minute scale, not microseconds
