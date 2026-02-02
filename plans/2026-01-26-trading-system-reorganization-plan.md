# Trading System Reorganization Plan

## Current State Analysis

### Problems Identified

| Issue | Details |
|-------|---------|
| **Root clutter** | 17 .md files in project root |
| **Empty directories** | `src/kernel`, `src/fpga`, `src/broker`, `src/core`, `tests/`, `benchmarks/`, `docs/`, `trading_system/` subdirs |
| **Header scatter** | Headers in `src/include/`, `src/risk/`, `src/live/`, `src/protocol/` |
| **Duplicate headers** | `src/live/trading_engine.h` duplicates `src/include/trading_engine.h` |
| **Build artifacts in root** | `trading_engine` binary file |
| **No proper test organization** | Tests in `src/tests/` instead of `tests/` |
| **Abandoned Python project** | `trading_system/` has empty structure |

### Current File Inventory

**Source Files (.c):**
- `src/common.c`
- `src/main.c`
- `src/main_trader.c`
- `src/engine/trading_engine.c`
- `src/datastructures/spsc_queue.c`
- `src/datastructures/orderbook.c`
- `src/network/protocol.c`
- `src/risk/risk_engine.c`
- `src/connectors/crypto/binance_auth.c`
- `src/connectors/crypto/binance_connector.c`
- `src/feedback/metrics_collector.c`

**Header Files (.h):**
- `src/include/` - 6 core headers
- `src/protocol/` - 5 protocol headers
- `src/risk/` - 2 headers
- `src/live/` - 3 headers (duplicates exist)
- `src/gateway/` - 1 header
- `src/strategy/` - 1 header
- `src/feedback/` - 1 header
- `src/connectors/crypto/` - 2 headers

**Test Files:**
- `src/tests/test_main.c`
- `src/tests/test_binance_integration.c`

**Python Scripts:**
- `scripts/binance_trader.py`
- `scripts/polymarket_trader.py`

**Config Files:**
- `config/multi_exchange.json`
- `config/credentials.env`

---

## Proposed Professional Structure

```
trading/
├── Makefile                            # Updated with new paths
├── .gitignore                          # Updated
│
├── docs/                               # All documentation consolidated
│   ├── architecture/
│   │   └── *.md                        # Architecture docs
│   ├── deployment/
│   │   └── *.md                        # Deployment guides
│   ├── engineering/
│   │   └── *.md                        # Engineering guides
│   └── archive/                        # Archived/abandoned code
│       ├── main.c
│       └── live/                       # Old live trading module
│
├── include/                            # Public headers (flat or namespaced)
│   └── trading/
│       ├── common.h
│       ├── orderbook.h
│       ├── protocol.h
│       ├── risk_engine.h
│       ├── spsc_queue.h
│       ├── trading_engine.h
│       ├── protocol/
│       │   ├── fix_parser.h
│       │   ├── itch_parser.h
│       │   ├── ouch_builder.h
│       │   ├── nyse_pillar.h
│       │   └── arca_direct.h
│       ├── connectors/
│       │   ├── binance_auth.h
│       │   ├── binance_connector.h
│       │   └── broker_interface.h
│       ├── risk/
│       │   └── kill_switch.h
│       ├── gateway/
│       │   └── order_gateway.h
│       ├── strategy/
│       │   └── stat_arb.h
│       └── metrics/
│           └── metrics_collector.h
│
├── src/                                # Implementation files
│   ├── core/
│   │   ├── common.c
│   │   ├── spsc_queue.c
│   │   └── orderbook.c
│   ├── engine/
│   │   └── trading_engine.c
│   ├── protocol/
│   │   └── protocol.c
│   ├── risk/
│   │   └── risk_engine.c
│   ├── connectors/
│   │   ├── binance_auth.c
│   │   └── binance_connector.c
│   ├── metrics/
│   │   └── metrics_collector.c
│   └── main_trader.c
│
├── tests/                              # All tests
│   ├── test_main.c
│   └── test_binance_integration.c
│
├── scripts/                            # Utility scripts
│   ├── binance_trader.py
│   └── polymarket_trader.py
│
├── config/                             # Configuration
│   ├── multi_exchange.json
│   └── credentials.env.example         # Renamed (no real creds in repo)
│
├── build/                              # Build artifacts (gitignored)
└── bin/                                # Binaries (gitignored)
```

---

## Reorganization Actions

### Phase 1: Create New Directory Structure
```bash
mkdir -p include/trading/{protocol,connectors,risk,gateway,strategy,metrics}
mkdir -p src/{core,engine,protocol,risk,connectors,metrics}
mkdir -p docs/{architecture,deployment,engineering}
mkdir -p tests
```

### Phase 2: Move Documentation
- Move `DEPLOYMENT.md` → `docs/deployment/`
- Move `Claude-Software-Architecture*.md` → `docs/architecture/`
- Move `Claude-Engineering*.md` → `docs/engineering/`
- Move `deployment-*.md` → `docs/deployment/`
- Move `Engineering-Solutions-1.md` → `docs/engineering/`

### Phase 3: Move Headers to include/trading/
- `src/include/*.h` → `include/trading/`
- `src/protocol/*.h` → `include/trading/protocol/`
- `src/connectors/crypto/*.h` → `include/trading/connectors/`
- `src/live/broker_interface.h` → `include/trading/connectors/`
- `src/risk/kill_switch.h` → `include/trading/risk/`
- `src/gateway/*.h` → `include/trading/gateway/`
- `src/strategy/*.h` → `include/trading/strategy/`
- `src/feedback/*.h` → `include/trading/metrics/`

### Phase 4: Reorganize Source Files
- `src/common.c` → `src/core/common.c`
- `src/datastructures/*.c` → `src/core/`
- `src/network/protocol.c` → `src/protocol/protocol.c`
- `src/connectors/crypto/*.c` → `src/connectors/`
- `src/feedback/*.c` → `src/metrics/`
- Keep `src/engine/`, `src/risk/` as-is

### Phase 5: Move Tests
- `src/tests/*.c` → `tests/`

### Phase 6: Cleanup
- Remove empty directories
- Remove duplicate headers (`src/live/trading_engine.h`)
- Remove stray binary (`trading_engine` in root)
- Remove `trading_system/` (empty scaffold)
- Rename `config/credentials.env` → `config/credentials.env.example`

### Phase 7: Update Makefile
- Update include paths: `-I./include`
- Update source paths to new locations
- Update .gitignore

---

## Files to Archive (to docs/archive/)

| Path | Reason |
|------|--------|
| `src/main.c` | **Abandoned** - references `core/types.h`, `core/timing.h` etc. that don't exist |
| `src/live/` directory | **Abandoned** - headers reference non-existent `../core/*.h` files |

## Files/Directories to Delete

| Path | Reason |
|------|--------|
| `trading_engine` (root) | Stray binary |
| `src/kernel/` | Empty |
| `src/fpga/` | Empty |
| `src/broker/` | Empty |
| `src/core/` | Empty (will recreate) |
| `src/scripts/` | Empty |
| `src/config/` | Empty |
| `trading_system/` | Empty scaffold |
| `tests/` (root) | Empty |
| `benchmarks/` | Empty |
| `docs/` | Empty (will recreate) |
| `firebase-debug.log` | Debug artifact |

---

## Verification Steps

After running the script:
1. Run `make clean && make trader` - should compile successfully
2. Run `./bin/trader --help` - should show usage
3. Verify all headers resolve with `-I./include`
4. Check no broken include paths

---

## Script Safety Features

The `reorganize.sh` script will:
1. Create a backup in `backup_TIMESTAMP/`
2. Perform dry-run first (show what would happen)
3. Ask for confirmation before executing
4. Update include paths in all .c and .h files
5. Generate an updated Makefile

---

## reorganize.sh Script

```bash
#!/bin/bash
#
# Trading System Reorganization Script
# Creates a clean, professional project structure
#
# Safety features:
# - Creates timestamped backup before any changes
# - Dry-run mode by default (use --execute to run)
# - Validates changes after execution
#

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="${PROJECT_ROOT}/backup_${TIMESTAMP}"
DRY_RUN=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }
log_dry()   { echo -e "${YELLOW}[DRY-RUN]${NC} Would: $*"; }

# Parse arguments
for arg in "$@"; do
    case $arg in
        --execute)
            DRY_RUN=false
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--execute]"
            echo "  --execute  Actually perform the reorganization (default is dry-run)"
            exit 0
            ;;
    esac
done

#=============================================================================
# STEP 0: Pre-flight checks
#=============================================================================
preflight_checks() {
    log_info "Running pre-flight checks..."

    cd "$PROJECT_ROOT"

    # Check we're in the right directory
    if [[ ! -f "Makefile" ]] || [[ ! -d "src" ]]; then
        log_error "Must be run from trading project root (Makefile and src/ must exist)"
        exit 1
    fi

    # Check for uncommitted changes
    if git status --porcelain | grep -q '^[MADRC]'; then
        log_warn "You have staged changes. Consider committing first."
    fi

    log_ok "Pre-flight checks passed"
}

#=============================================================================
# STEP 1: Create backup
#=============================================================================
create_backup() {
    log_info "Creating backup at ${BACKUP_DIR}..."

    if $DRY_RUN; then
        log_dry "mkdir -p ${BACKUP_DIR}"
        log_dry "cp -r src/ docs/ config/ scripts/ Makefile ${BACKUP_DIR}/"
        return
    fi

    mkdir -p "$BACKUP_DIR"

    # Backup key directories and files
    for item in src config scripts Makefile; do
        if [[ -e "$item" ]]; then
            cp -r "$item" "$BACKUP_DIR/"
        fi
    done

    # Backup root .md files
    cp -f *.md "$BACKUP_DIR/" 2>/dev/null || true

    log_ok "Backup created at ${BACKUP_DIR}"
}

#=============================================================================
# STEP 2: Create new directory structure
#=============================================================================
create_directories() {
    log_info "Creating new directory structure..."

    local dirs=(
        "include/trading/protocol"
        "include/trading/connectors"
        "include/trading/risk"
        "include/trading/gateway"
        "include/trading/strategy"
        "include/trading/metrics"
        "src/core"
        "src/engine"
        "src/protocol"
        "src/risk"
        "src/connectors"
        "src/metrics"
        "docs/architecture"
        "docs/deployment"
        "docs/engineering"
        "docs/archive/live"
        "tests"
    )

    for dir in "${dirs[@]}"; do
        if $DRY_RUN; then
            log_dry "mkdir -p $dir"
        else
            mkdir -p "$dir"
        fi
    done

    log_ok "Directory structure created"
}

#=============================================================================
# STEP 3: Move documentation files
#=============================================================================
move_documentation() {
    log_info "Moving documentation files..."

    # Architecture docs
    for f in Claude-Software-Architecture*.md; do
        [[ -f "$f" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $f docs/architecture/"
        else
            mv "$f" docs/architecture/
        fi
    done

    # Engineering docs
    for f in Claude-Engineering*.md Engineering-Solutions*.md; do
        [[ -f "$f" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $f docs/engineering/"
        else
            mv "$f" docs/engineering/
        fi
    done

    # Deployment docs
    for f in DEPLOYMENT.md deployment-*.md; do
        [[ -f "$f" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $f docs/deployment/"
        else
            mv "$f" docs/deployment/
        fi
    done

    log_ok "Documentation moved"
}

#=============================================================================
# STEP 4: Move headers to include/trading/
#=============================================================================
move_headers() {
    log_info "Moving header files to include/trading/..."

    # Core headers from src/include/
    for h in src/include/*.h; do
        [[ -f "$h" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $h include/trading/"
        else
            mv "$h" include/trading/
        fi
    done

    # Protocol headers
    for h in src/protocol/*.h; do
        [[ -f "$h" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $h include/trading/protocol/"
        else
            mv "$h" include/trading/protocol/
        fi
    done

    # Connector headers
    for h in src/connectors/crypto/*.h; do
        [[ -f "$h" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $h include/trading/connectors/"
        else
            mv "$h" include/trading/connectors/
        fi
    done

    # Risk headers
    if [[ -f "src/risk/kill_switch.h" ]]; then
        if $DRY_RUN; then
            log_dry "mv src/risk/kill_switch.h include/trading/risk/"
        else
            mv src/risk/kill_switch.h include/trading/risk/
        fi
    fi

    # Also move risk_engine.h if it exists in src/risk/
    if [[ -f "src/risk/risk_engine.h" ]]; then
        if $DRY_RUN; then
            log_dry "mv src/risk/risk_engine.h include/trading/risk/"
        else
            mv src/risk/risk_engine.h include/trading/risk/
        fi
    fi

    # Gateway headers
    for h in src/gateway/*.h; do
        [[ -f "$h" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $h include/trading/gateway/"
        else
            mv "$h" include/trading/gateway/
        fi
    done

    # Strategy headers
    for h in src/strategy/*.h; do
        [[ -f "$h" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $h include/trading/strategy/"
        else
            mv "$h" include/trading/strategy/
        fi
    done

    # Metrics headers
    for h in src/feedback/*.h; do
        [[ -f "$h" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $h include/trading/metrics/"
        else
            mv "$h" include/trading/metrics/
        fi
    done

    log_ok "Headers moved"
}

#=============================================================================
# STEP 5: Reorganize source files
#=============================================================================
move_sources() {
    log_info "Reorganizing source files..."

    # Core sources
    local core_files=("src/common.c" "src/datastructures/spsc_queue.c" "src/datastructures/orderbook.c")
    for f in "${core_files[@]}"; do
        if [[ -f "$f" ]]; then
            if $DRY_RUN; then
                log_dry "mv $f src/core/"
            else
                mv "$f" src/core/
            fi
        fi
    done

    # Protocol source
    if [[ -f "src/network/protocol.c" ]]; then
        if $DRY_RUN; then
            log_dry "mv src/network/protocol.c src/protocol/"
        else
            mv src/network/protocol.c src/protocol/
        fi
    fi

    # Connector sources
    for f in src/connectors/crypto/*.c; do
        [[ -f "$f" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $f src/connectors/"
        else
            mv "$f" src/connectors/
        fi
    done

    # Metrics source
    for f in src/feedback/*.c; do
        [[ -f "$f" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $f src/metrics/"
        else
            mv "$f" src/metrics/
        fi
    done

    log_ok "Sources reorganized"
}

#=============================================================================
# STEP 6: Move tests
#=============================================================================
move_tests() {
    log_info "Moving test files..."

    for f in src/tests/*.c; do
        [[ -f "$f" ]] || continue
        if $DRY_RUN; then
            log_dry "mv $f tests/"
        else
            mv "$f" tests/
        fi
    done

    log_ok "Tests moved"
}

#=============================================================================
# STEP 7: Archive abandoned code
#=============================================================================
archive_abandoned() {
    log_info "Archiving abandoned code..."

    # Archive src/main.c
    if [[ -f "src/main.c" ]]; then
        if $DRY_RUN; then
            log_dry "mv src/main.c docs/archive/"
        else
            mv src/main.c docs/archive/
        fi
    fi

    # Archive src/live/ directory
    if [[ -d "src/live" ]] && [[ -n "$(ls -A src/live 2>/dev/null)" ]]; then
        if $DRY_RUN; then
            log_dry "mv src/live/* docs/archive/live/"
        else
            mv src/live/* docs/archive/live/
        fi
    fi

    log_ok "Abandoned code archived"
}

#=============================================================================
# STEP 8: Clean up empty directories and artifacts
#=============================================================================
cleanup() {
    log_info "Cleaning up empty directories and artifacts..."

    # Remove stray binary
    if [[ -f "trading_engine" ]]; then
        if $DRY_RUN; then
            log_dry "rm trading_engine"
        else
            rm trading_engine
        fi
    fi

    # Remove firebase debug log
    if [[ -f "firebase-debug.log" ]]; then
        if $DRY_RUN; then
            log_dry "rm firebase-debug.log"
        else
            rm firebase-debug.log
        fi
    fi

    # Remove empty directories
    local empty_dirs=(
        "src/kernel"
        "src/fpga"
        "src/broker"
        "src/core"  # old empty one before we populated it
        "src/scripts"
        "src/config"
        "src/include"
        "src/datastructures"
        "src/network"
        "src/live"
        "src/connectors/crypto"
        "src/connectors/broker"
        "src/connectors"
        "src/feedback"
        "src/gateway"
        "src/protocol"
        "src/strategy"
        "src/tests"
        "trading_system"
        "tests"  # old empty one at root
        "benchmarks"
        "docs"  # old empty one
    )

    for dir in "${empty_dirs[@]}"; do
        if [[ -d "$dir" ]] && [[ -z "$(ls -A "$dir" 2>/dev/null)" ]]; then
            if $DRY_RUN; then
                log_dry "rmdir $dir"
            else
                rmdir "$dir" 2>/dev/null || true
            fi
        fi
    done

    # Rename credentials.env to credentials.env.example
    if [[ -f "config/credentials.env" ]]; then
        if $DRY_RUN; then
            log_dry "mv config/credentials.env config/credentials.env.example"
        else
            mv config/credentials.env config/credentials.env.example
        fi
    fi

    log_ok "Cleanup complete"
}

#=============================================================================
# STEP 9: Update include paths in source files
#=============================================================================
update_includes() {
    log_info "Updating include paths in source files..."

    if $DRY_RUN; then
        log_dry "Update #include paths in all .c and .h files"
        log_dry "  - '../include/X.h' -> <trading/X.h>"
        log_dry "  - '\"include/X.h\"' -> <trading/X.h>"
        log_dry "  - '\"X.h\"' (for headers in same old dir) -> <trading/X.h>"
        return
    fi

    # Find all .c and .h files in new locations
    find src include tests -name '*.c' -o -name '*.h' 2>/dev/null | while read -r file; do
        # Skip if file doesn't exist
        [[ -f "$file" ]] || continue

        # Update various include patterns
        sed -i \
            -e 's|#include "../include/\([^"]*\)"|#include <trading/\1>|g' \
            -e 's|#include "include/\([^"]*\)"|#include <trading/\1>|g' \
            -e 's|#include "\.\./\.\./include/\([^"]*\)"|#include <trading/\1>|g' \
            -e 's|#include "common\.h"|#include <trading/common.h>|g' \
            -e 's|#include "spsc_queue\.h"|#include <trading/spsc_queue.h>|g' \
            -e 's|#include "orderbook\.h"|#include <trading/orderbook.h>|g' \
            -e 's|#include "protocol\.h"|#include <trading/protocol.h>|g' \
            -e 's|#include "risk_engine\.h"|#include <trading/risk_engine.h>|g' \
            -e 's|#include "trading_engine\.h"|#include <trading/trading_engine.h>|g' \
            -e 's|#include "binance_auth\.h"|#include <trading/connectors/binance_auth.h>|g' \
            -e 's|#include "binance_connector\.h"|#include <trading/connectors/binance_connector.h>|g' \
            -e 's|#include "metrics_collector\.h"|#include <trading/metrics/metrics_collector.h>|g' \
            "$file"
    done

    log_ok "Include paths updated"
}

#=============================================================================
# STEP 10: Generate new Makefile
#=============================================================================
generate_makefile() {
    log_info "Generating new Makefile..."

    if $DRY_RUN; then
        log_dry "Generate new Makefile with updated paths"
        return
    fi

    cat > Makefile << 'MAKEFILE_EOF'
# Ultra-Low-Latency Trading System
# Build System (Reorganized)

CC = gcc
CFLAGS = -Wall -Wextra -O3 -ffast-math
CFLAGS += -std=c11 -D_GNU_SOURCE
CFLAGS += -I./include

# Debug build flags
DEBUG_CFLAGS = -Wall -Wextra -O0 -g
DEBUG_CFLAGS += -std=c11 -D_GNU_SOURCE -DDEBUG
DEBUG_CFLAGS += -I./include

# Linker flags
LDFLAGS = -pthread -lm

# Directories
SRCDIR = src
BUILDDIR = build
BINDIR = bin
TESTDIR = tests

# Core source files
CORE_SRC = $(SRCDIR)/core/common.c \
           $(SRCDIR)/core/spsc_queue.c \
           $(SRCDIR)/core/orderbook.c

PROTOCOL_SRC = $(SRCDIR)/protocol/protocol.c
RISK_SRC = $(SRCDIR)/risk/risk_engine.c
ENGINE_SRC = $(SRCDIR)/engine/trading_engine.c

# Connector source files
CONNECTOR_SRC = $(SRCDIR)/connectors/binance_auth.c \
                $(SRCDIR)/connectors/binance_connector.c

# Metrics source files
METRICS_SRC = $(SRCDIR)/metrics/metrics_collector.c

# Test source files
TEST_SRC = $(TESTDIR)/test_main.c
BINANCE_TEST_SRC = $(TESTDIR)/test_binance_integration.c

# Main executable
TRADER_SRC = $(SRCDIR)/main_trader.c

ALL_SRC = $(CORE_SRC) $(PROTOCOL_SRC) $(RISK_SRC) $(ENGINE_SRC)

# Object files
CORE_OBJ = $(BUILDDIR)/common.o \
           $(BUILDDIR)/spsc_queue.o \
           $(BUILDDIR)/orderbook.o

PROTOCOL_OBJ = $(BUILDDIR)/protocol.o
RISK_OBJ = $(BUILDDIR)/risk_engine.o
ENGINE_OBJ = $(BUILDDIR)/trading_engine.o

CONNECTOR_OBJ = $(BUILDDIR)/binance_auth.o \
                $(BUILDDIR)/binance_connector.o

METRICS_OBJ = $(BUILDDIR)/metrics_collector.o

TEST_OBJ = $(BUILDDIR)/test_main.o
BINANCE_TEST_OBJ = $(BUILDDIR)/test_binance_integration.o
TRADER_OBJ = $(BUILDDIR)/main_trader.o

ALL_OBJ = $(CORE_OBJ) $(PROTOCOL_OBJ) $(RISK_OBJ) $(ENGINE_OBJ)

# Targets
.PHONY: all clean test debug release dirs trader binance-test

all: dirs $(BINDIR)/test_trading

trader: dirs $(BINDIR)/trader

release: CFLAGS += -DNDEBUG
release: all

debug: CFLAGS = $(DEBUG_CFLAGS)
debug: dirs $(BINDIR)/test_trading_debug

# Create directories
dirs:
	@mkdir -p $(BUILDDIR) $(BINDIR) logs

# Main test executable
$(BINDIR)/test_trading: $(ALL_OBJ) $(TEST_OBJ)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "Build complete: $@"

# Binance integration test executable
$(BINDIR)/test_binance: $(ALL_OBJ) $(CONNECTOR_OBJ) $(METRICS_OBJ) $(BINANCE_TEST_OBJ)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "Build complete: $@"

# Debug executable
$(BINDIR)/test_trading_debug: $(ALL_OBJ) $(TEST_OBJ)
	$(CC) $(DEBUG_CFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "Debug build complete: $@"

# Main trading executable
$(BINDIR)/trader: $(ALL_OBJ) $(CONNECTOR_OBJ) $(METRICS_OBJ) $(TRADER_OBJ)
	$(CC) $(CFLAGS) -o $@ $^ $(LDFLAGS)
	@echo "Trader build complete: $@"

# Core compile rules
$(BUILDDIR)/common.o: $(SRCDIR)/core/common.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/spsc_queue.o: $(SRCDIR)/core/spsc_queue.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/orderbook.o: $(SRCDIR)/core/orderbook.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/protocol.o: $(SRCDIR)/protocol/protocol.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/risk_engine.o: $(SRCDIR)/risk/risk_engine.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/trading_engine.o: $(SRCDIR)/engine/trading_engine.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/binance_auth.o: $(SRCDIR)/connectors/binance_auth.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/binance_connector.o: $(SRCDIR)/connectors/binance_connector.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/metrics_collector.o: $(SRCDIR)/metrics/metrics_collector.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/test_main.o: $(TESTDIR)/test_main.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/test_binance_integration.o: $(TESTDIR)/test_binance_integration.c
	$(CC) $(CFLAGS) -c -o $@ $<

$(BUILDDIR)/main_trader.o: $(SRCDIR)/main_trader.c
	$(CC) $(CFLAGS) -c -o $@ $<

# Clean
clean:
	rm -rf $(BUILDDIR)/*.o $(BINDIR)/*

# Run tests
test: $(BINDIR)/test_trading
	./$(BINDIR)/test_trading

binance-test: $(BINDIR)/test_binance
	./$(BINDIR)/test_binance
MAKEFILE_EOF

    log_ok "Makefile generated"
}

#=============================================================================
# STEP 11: Verify the reorganization
#=============================================================================
verify() {
    log_info "Verifying reorganization..."

    if $DRY_RUN; then
        log_dry "Would verify: directory structure, file locations, build"
        return
    fi

    local errors=0

    # Check key directories exist
    for dir in include/trading src/core src/engine tests docs; do
        if [[ ! -d "$dir" ]]; then
            log_error "Missing directory: $dir"
            ((errors++))
        fi
    done

    # Check key files exist
    local key_files=(
        "include/trading/common.h"
        "include/trading/trading_engine.h"
        "src/core/common.c"
        "src/engine/trading_engine.c"
        "tests/test_main.c"
        "Makefile"
    )

    for f in "${key_files[@]}"; do
        if [[ ! -f "$f" ]]; then
            log_error "Missing file: $f"
            ((errors++))
        fi
    done

    if ((errors > 0)); then
        log_error "Verification failed with $errors errors"
        return 1
    fi

    log_ok "Verification passed"

    # Try to build
    log_info "Attempting test build..."
    if make clean && make trader; then
        log_ok "Build successful!"
    else
        log_error "Build failed - check include paths"
        return 1
    fi
}

#=============================================================================
# MAIN
#=============================================================================
main() {
    echo ""
    echo "==========================================="
    echo "  Trading System Reorganization Script"
    echo "==========================================="
    echo ""

    if $DRY_RUN; then
        log_warn "DRY-RUN MODE - No changes will be made"
        log_warn "Use --execute to perform actual reorganization"
        echo ""
    else
        log_warn "EXECUTE MODE - Changes will be made!"
        echo ""
        read -p "Are you sure you want to proceed? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    preflight_checks
    create_backup
    create_directories
    move_documentation
    move_headers
    move_sources
    move_tests
    archive_abandoned
    cleanup
    update_includes
    generate_makefile
    verify

    echo ""
    log_ok "Reorganization complete!"

    if $DRY_RUN; then
        echo ""
        log_info "This was a dry run. To execute, run:"
        echo "  ./reorganize.sh --execute"
    else
        echo ""
        log_info "Backup saved at: ${BACKUP_DIR}"
        log_info "To restore: rm -rf src include tests docs && cp -r ${BACKUP_DIR}/* ."
    fi
}

main "$@"
```
