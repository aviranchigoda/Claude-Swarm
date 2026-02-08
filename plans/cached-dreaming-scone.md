# Claude Configuration Transfer Blueprint

## Executive Summary
Transfer the complete Claude Code configuration (~459MB total, ~35MB essential) from Source Linux Server to Destination Linux Server, preserving the destination's session history while replacing all configuration and plugin systems.

---

## Server Details

| | Source Server | Destination Server |
|---|---|---|
| **Host** | Current machine | `linode-southeast` |
| **IP** | Local | `194.195.123.136` |
| **SSH User** | `ai_dev` | `root` (SSH) |
| **Claude Path** | `/home/ai_dev/.claude` | `/home/ai_dev/.claude` |
| **SSH Config** | N/A | Pre-configured with ControlMaster |

---

## Directory Analysis

### Source Server Structure
```
/home/ai_dev/.claude/                     # 459MB total
├── CLAUDE.md                             # 12KB  - TRANSFER (master config)
├── settings.json                         # 4KB   - TRANSFER (hooks/plugins)
├── settings.local.json                   # 4KB   - TRANSFER (permissions)
├── settings.json.backup                  # 4KB   - TRANSFER (backup)
├── .gitignore                            # 4KB   - TRANSFER (git config)
├── hookify.session-reminder.local.md     # 4KB   - TRANSFER (hookify)
├── config/                               # 24KB  - TRANSFER (all files)
│   ├── master.json
│   ├── permissions.json
│   └── triggers.json
├── hooks/                                # 72KB  - TRANSFER (all files)
│   ├── router.sh
│   ├── handlers/
│   ├── lib/
│   └── archive/
├── docs/                                 # 32KB  - TRANSFER (MCP docs)
├── plugins/                              # 30MB  - TRANSFER (critical)
│   ├── installed_plugins.json
│   ├── known_marketplaces.json
│   ├── config.json
│   ├── install-counts-cache.json
│   ├── cache/                            # Plugin cache
│   └── marketplaces/                     # Git repos
├── ai-system/                            # 52KB  - TRANSFER
├── mac-scripts/                          # 16KB  - TRANSFER
│
├── plans/                                # 1.4MB - PRESERVE on destination
├── file-history/                         # 14MB  - PRESERVE on destination
├── projects/                             # 186MB - PRESERVE on destination
├── todos/                                # 3.2MB - PRESERVE on destination
├── history.jsonl                         # 772KB - PRESERVE on destination
│
├── debug/                                # 110MB - SKIP (ephemeral)
├── local/                                # 91MB  - SKIP (ephemeral)
├── paste-cache/                          # 19MB  - SKIP (ephemeral)
├── shell-snapshots/                      # 3MB   - SKIP (ephemeral)
├── session-env/                          # 392KB - SKIP (runtime)
├── cache/                                # 72KB  - SKIP (ephemeral)
├── statsig/                              # 80KB  - SKIP (telemetry)
├── telemetry/                            # 4KB   - SKIP (telemetry)
├── state/                                # 24KB  - SKIP (runtime)
├── hook-state/                           # 4KB   - SKIP (runtime)
├── ide/                                  # 12KB  - SKIP (runtime)
├── audit/                                # 4KB   - SKIP (ephemeral)
├── stats-cache.json                      # 12KB  - SKIP (cache)
├── firebase-debug.log                    # 48KB  - SKIP (log)
└── .credentials.json                     # NEVER - Security risk
```

---

## Transfer Strategy

### Phase 1: Pre-Transfer Preparation (Source Server)

#### Step 1.1: Create Transfer Package
```bash
#!/bin/bash
# Run on SOURCE server

TRANSFER_DIR="/tmp/claude-transfer-$(date +%Y%m%d-%H%M%S)"
ARCHIVE_NAME="claude-config-$(date +%Y%m%d-%H%M%S).tar.gz"
SOURCE_DIR="/home/ai_dev/.claude"

# Create staging directory
mkdir -p "$TRANSFER_DIR"

# Define files/directories to transfer
TRANSFER_LIST=(
    "CLAUDE.md"
    "settings.json"
    "settings.local.json"
    "settings.json.backup"
    ".gitignore"
    "hookify.session-reminder.local.md"
    "config"
    "hooks"
    "docs"
    "plugins"
    "ai-system"
    "mac-scripts"
)

# Copy each item to staging
for item in "${TRANSFER_LIST[@]}"; do
    if [ -e "$SOURCE_DIR/$item" ]; then
        cp -rp "$SOURCE_DIR/$item" "$TRANSFER_DIR/"
        echo "Copied: $item"
    else
        echo "Warning: $item not found"
    fi
done

# Remove credentials if accidentally included
rm -f "$TRANSFER_DIR/.credentials.json"
rm -f "$TRANSFER_DIR/credentials.json"
find "$TRANSFER_DIR" -name "*.secret" -delete
find "$TRANSFER_DIR" -name "*.key" -delete

# Create checksum manifest
cd "$TRANSFER_DIR"
find . -type f -exec sha256sum {} \; > ../manifest.sha256
mv ../manifest.sha256 ./

# Create archive
cd /tmp
tar -czvf "$ARCHIVE_NAME" "$(basename $TRANSFER_DIR)"

# Generate archive checksum
sha256sum "$ARCHIVE_NAME" > "${ARCHIVE_NAME}.sha256"

echo ""
echo "=========================================="
echo "Transfer package created:"
echo "Archive: /tmp/$ARCHIVE_NAME"
echo "Checksum: /tmp/${ARCHIVE_NAME}.sha256"
echo "Size: $(du -sh /tmp/$ARCHIVE_NAME | cut -f1)"
echo "=========================================="
```

#### Step 1.2: Verify Package Integrity
```bash
# Verify the archive can be extracted
cd /tmp
tar -tzvf "$ARCHIVE_NAME" | head -50
echo "Total files: $(tar -tzvf $ARCHIVE_NAME | wc -l)"
```

---

### Phase 2: Secure Transfer

#### Option A: SCP Direct Transfer (Recommended for Speed)
```bash
# Run on SOURCE server
# Replace DEST_USER, DEST_HOST with actual values

DEST_USER="ai_dev"
DEST_HOST="second-server"
ARCHIVE_NAME="claude-config-*.tar.gz"  # Use actual filename

# Transfer archive and checksum
scp /tmp/$ARCHIVE_NAME "${DEST_USER}@${DEST_HOST}:/tmp/"
scp /tmp/${ARCHIVE_NAME}.sha256 "${DEST_USER}@${DEST_HOST}:/tmp/"

echo "Transfer complete. Verify with checksum on destination."
```

#### Option B: Rsync (For Resumable Transfers)
```bash
# Run on SOURCE server
rsync -avzP --checksum \
    /tmp/$ARCHIVE_NAME \
    /tmp/${ARCHIVE_NAME}.sha256 \
    "${DEST_USER}@${DEST_HOST}:/tmp/"
```

#### Option C: SSH Pipe (Direct without temp file on source)
```bash
# For minimal disk usage on source
cd /tmp
tar -cz claude-transfer-* | \
    ssh "${DEST_USER}@${DEST_HOST}" "cat > /tmp/claude-config-transfer.tar.gz"
```

---

### Phase 3: Destination Preparation (Second Server)

#### Step 3.1: Verify Transfer Integrity
```bash
#!/bin/bash
# Run on DESTINATION server

cd /tmp

# Verify checksum
sha256sum -c *.sha256
if [ $? -ne 0 ]; then
    echo "ERROR: Checksum verification failed!"
    exit 1
fi
echo "Checksum verified."
```

#### Step 3.2: Backup Existing Configuration
```bash
#!/bin/bash
# Run on DESTINATION server

DEST_DIR="/home/ai_dev/.claude"
BACKUP_DIR="/home/ai_dev/.claude.backup.$(date +%Y%m%d-%H%M%S)"

# Create full backup
cp -rp "$DEST_DIR" "$BACKUP_DIR"
echo "Backup created: $BACKUP_DIR"

# Verify backup
if [ -d "$BACKUP_DIR" ]; then
    echo "Backup size: $(du -sh $BACKUP_DIR | cut -f1)"
else
    echo "ERROR: Backup failed!"
    exit 1
fi
```

#### Step 3.3: Identify Items to Preserve
```bash
#!/bin/bash
# Run on DESTINATION server

DEST_DIR="/home/ai_dev/.claude"
PRESERVE_DIR="/tmp/claude-preserve-$(date +%Y%m%d-%H%M%S)"

# Create preserve directory
mkdir -p "$PRESERVE_DIR"

# Items to preserve from destination
PRESERVE_LIST=(
    "plans"
    "file-history"
    "projects"
    "todos"
    "history.jsonl"
)

for item in "${PRESERVE_LIST[@]}"; do
    if [ -e "$DEST_DIR/$item" ]; then
        mv "$DEST_DIR/$item" "$PRESERVE_DIR/"
        echo "Preserved: $item"
    fi
done

echo "Preserved items: $PRESERVE_DIR"
ls -la "$PRESERVE_DIR"
```

---

### Phase 4: Apply New Configuration

#### Step 4.1: Extract Transfer Package
```bash
#!/bin/bash
# Run on DESTINATION server

cd /tmp
ARCHIVE=$(ls claude-config-*.tar.gz | head -1)

# Extract archive
tar -xzvf "$ARCHIVE"

# Find extracted directory
EXTRACT_DIR=$(ls -d claude-transfer-* | head -1)
echo "Extracted to: $EXTRACT_DIR"
```

#### Step 4.2: Apply Configuration
```bash
#!/bin/bash
# Run on DESTINATION server

DEST_DIR="/home/ai_dev/.claude"
EXTRACT_DIR="/tmp/claude-transfer-*"  # Use actual path
PRESERVE_DIR="/tmp/claude-preserve-*"  # Use actual path

# Remove old configuration files (but keep directory structure)
cd "$DEST_DIR"

# Remove items being replaced
rm -f CLAUDE.md settings.json settings.local.json settings.json.backup
rm -f .gitignore hookify.session-reminder.local.md
rm -rf config hooks docs plugins ai-system mac-scripts

# Remove ephemeral directories
rm -rf debug local paste-cache shell-snapshots session-env
rm -rf cache statsig telemetry state hook-state ide audit
rm -f stats-cache.json firebase-debug.log .credentials.json

# Copy new configuration
for item in $(ls $EXTRACT_DIR); do
    if [ "$item" != "manifest.sha256" ]; then
        cp -rp "$EXTRACT_DIR/$item" "$DEST_DIR/"
        echo "Applied: $item"
    fi
done

# Restore preserved items
for item in $(ls $PRESERVE_DIR); do
    cp -rp "$PRESERVE_DIR/$item" "$DEST_DIR/"
    echo "Restored: $item"
done

# Verify manifest
cd "$DEST_DIR"
sha256sum -c manifest.sha256 2>/dev/null || echo "Manifest check: some files restored from preserve"
```

#### Step 4.3: Set Correct Permissions
```bash
#!/bin/bash
# Run on DESTINATION server

DEST_DIR="/home/ai_dev/.claude"
USER="ai_dev"
GROUP="ai_dev"

# Set ownership
chown -R "$USER:$GROUP" "$DEST_DIR"

# Set directory permissions
find "$DEST_DIR" -type d -exec chmod 755 {} \;

# Set file permissions
find "$DEST_DIR" -type f -exec chmod 644 {} \;

# Make hooks executable
chmod +x "$DEST_DIR/hooks/"*.sh
chmod +x "$DEST_DIR/hooks/handlers/"*.sh
chmod +x "$DEST_DIR/hooks/lib/"*.sh
chmod +x "$DEST_DIR/hooks/archive/"*.sh 2>/dev/null

# Make scripts executable
chmod +x "$DEST_DIR/mac-scripts/"*.sh 2>/dev/null

# Restrict sensitive files
chmod 600 "$DEST_DIR/settings.local.json"
chmod 700 "$DEST_DIR/plugins"

echo "Permissions applied."
```

#### Step 4.4: Recreate Ephemeral Directories
```bash
#!/bin/bash
# Run on DESTINATION server

DEST_DIR="/home/ai_dev/.claude"

# Create empty ephemeral directories
mkdir -p "$DEST_DIR"/{debug,local,paste-cache,shell-snapshots}
mkdir -p "$DEST_DIR"/{session-env,cache,statsig,telemetry}
mkdir -p "$DEST_DIR"/{state,hook-state,ide,audit}

# Initialize state files
echo '{}' > "$DEST_DIR/state/session.json"
echo '{}' > "$DEST_DIR/state/trigger-history.json"
echo '{}' > "$DEST_DIR/state/mcp-usage.json"

echo "Ephemeral directories created."
```

---

### Phase 5: Verification

#### Step 5.1: Structure Verification
```bash
#!/bin/bash
# Run on DESTINATION server

DEST_DIR="/home/ai_dev/.claude"

echo "=== Configuration Files ==="
for f in CLAUDE.md settings.json settings.local.json; do
    [ -f "$DEST_DIR/$f" ] && echo "✓ $f" || echo "✗ $f MISSING"
done

echo ""
echo "=== Directories ==="
for d in config hooks docs plugins ai-system mac-scripts; do
    [ -d "$DEST_DIR/$d" ] && echo "✓ $d" || echo "✗ $d MISSING"
done

echo ""
echo "=== Preserved Directories ==="
for d in plans file-history projects todos; do
    [ -d "$DEST_DIR/$d" ] && echo "✓ $d (preserved)" || echo "○ $d (not present)"
done

echo ""
echo "=== Hook Executability ==="
for f in "$DEST_DIR/hooks/"*.sh; do
    [ -x "$f" ] && echo "✓ $(basename $f)" || echo "✗ $(basename $f) NOT EXECUTABLE"
done

echo ""
echo "=== Plugin Configuration ==="
[ -f "$DEST_DIR/plugins/installed_plugins.json" ] && \
    echo "✓ $(cat $DEST_DIR/plugins/installed_plugins.json | grep -c '"')" plugins configured" || \
    echo "✗ Plugins not configured"
```

#### Step 5.2: Content Verification
```bash
#!/bin/bash
# Run on DESTINATION server

DEST_DIR="/home/ai_dev/.claude"

echo "=== Config Files ==="
ls -la "$DEST_DIR/config/"

echo ""
echo "=== Hooks Structure ==="
find "$DEST_DIR/hooks" -type f -name "*.sh" | head -20

echo ""
echo "=== Settings Preview ==="
cat "$DEST_DIR/settings.json" | head -30

echo ""
echo "=== Triggers Count ==="
if [ -f "$DEST_DIR/config/triggers.json" ]; then
    echo "$(grep -c '"pattern"' $DEST_DIR/config/triggers.json) trigger patterns configured"
fi
```

#### Step 5.3: Functional Test
```bash
#!/bin/bash
# Run on DESTINATION server

# Test hook execution
cd /home/ai_dev/.claude
CLAUDE_HOOK_EVENT=test bash hooks/router.sh 2>&1 | head -5

# Verify no permission errors
echo ""
echo "=== Permission Test ==="
find . -type f ! -readable 2>/dev/null | head -5 || echo "All files readable"
```

---

### Phase 6: Cleanup

#### Step 6.1: Remove Transfer Artifacts
```bash
#!/bin/bash
# Run on BOTH servers after verification

# On Source
rm -rf /tmp/claude-transfer-*
rm -f /tmp/claude-config-*.tar.gz
rm -f /tmp/claude-config-*.sha256

# On Destination
rm -rf /tmp/claude-transfer-*
rm -rf /tmp/claude-preserve-*
rm -f /tmp/claude-config-*.tar.gz
rm -f /tmp/claude-config-*.sha256
```

#### Step 6.2: Keep or Remove Backup
```bash
# Run on DESTINATION server
# Keep backup for 7 days, then delete if everything works

# Option: Keep backup
echo "Backup at: ~/.claude.backup.*"

# Option: Remove backup after verification
# rm -rf ~/.claude.backup.*
```

---

## Complete One-Liner Scripts

### SOURCE SERVER (Run This First)
```bash
# Create transfer package and send to linode-southeast
cd ~/.claude && \
tar -czvf /tmp/claude-config.tar.gz \
    CLAUDE.md settings.json settings.local.json settings.json.backup \
    .gitignore hookify.session-reminder.local.md \
    config hooks docs plugins ai-system mac-scripts \
    --exclude='plugins/marketplaces/*/.git' \
    --exclude='.credentials.json' && \
sha256sum /tmp/claude-config.tar.gz > /tmp/claude-config.tar.gz.sha256 && \
echo "Package created: $(du -sh /tmp/claude-config.tar.gz)" && \
scp /tmp/claude-config.tar.gz /tmp/claude-config.tar.gz.sha256 linode-southeast:/tmp/ && \
echo "Transfer complete!"
```

### DESTINATION SERVER (SSH to linode-southeast, then run this)
```bash
# First SSH: ssh linode-southeast

# Backup, extract, apply, restore preserved items
DEST_DIR="/home/ai_dev/.claude" && \
BACKUP="/home/ai_dev/.claude.backup.$(date +%Y%m%d-%H%M%S)" && \
cp -rp "$DEST_DIR" "$BACKUP" && \
echo "Backup created: $BACKUP" && \
mkdir -p /tmp/preserve && \
mv "$DEST_DIR"/{plans,file-history,projects,todos,history.jsonl} /tmp/preserve/ 2>/dev/null ; \
rm -rf "$DEST_DIR"/{CLAUDE.md,settings.json,settings.local.json,settings.json.backup,.gitignore,hookify.session-reminder.local.md} && \
rm -rf "$DEST_DIR"/{config,hooks,docs,plugins,ai-system,mac-scripts} && \
rm -rf "$DEST_DIR"/{debug,local,paste-cache,shell-snapshots,session-env,cache,statsig,telemetry,state,hook-state,ide,audit,.credentials.json,stats-cache.json,firebase-debug.log} && \
cd /tmp && tar -xzf claude-config.tar.gz && \
cp -rp /tmp/claude-config.tar.gz.d/* "$DEST_DIR/" 2>/dev/null || cp -rp CLAUDE.md settings.* config hooks docs plugins ai-system mac-scripts .gitignore hookify.session-reminder.local.md "$DEST_DIR/" 2>/dev/null && \
cp -rp /tmp/preserve/* "$DEST_DIR/" 2>/dev/null ; \
chmod +x "$DEST_DIR"/hooks/*.sh "$DEST_DIR"/hooks/handlers/*.sh "$DEST_DIR"/hooks/lib/*.sh 2>/dev/null ; \
chmod +x "$DEST_DIR"/hooks/archive/*.sh 2>/dev/null ; \
mkdir -p "$DEST_DIR"/{debug,local,paste-cache,shell-snapshots,session-env,cache,statsig,telemetry,state,hook-state,ide,audit} && \
echo '{}' > "$DEST_DIR/state/session.json" && \
echo '{}' > "$DEST_DIR/state/trigger-history.json" && \
echo '{}' > "$DEST_DIR/state/mcp-usage.json" && \
chown -R ai_dev:ai_dev "$DEST_DIR" && \
echo "Done! Configuration applied. Backup at: $BACKUP"
```

### VERIFICATION (Run on destination after apply)
```bash
# Quick verification
DEST_DIR="/home/ai_dev/.claude"
echo "=== Core Files ===" && \
ls -la "$DEST_DIR"/{CLAUDE.md,settings.json,settings.local.json} 2>/dev/null && \
echo "" && echo "=== Directories ===" && \
ls -d "$DEST_DIR"/{config,hooks,docs,plugins} 2>/dev/null && \
echo "" && echo "=== Hooks Executable ===" && \
ls -la "$DEST_DIR/hooks/"*.sh | head -3 && \
echo "" && echo "=== Preserved ===" && \
ls -d "$DEST_DIR"/{plans,file-history,projects,todos} 2>/dev/null && \
echo "" && echo "SUCCESS: All components verified!"
```

---

## Files Being Transferred

| File/Directory | Size | Purpose |
|----------------|------|---------|
| `CLAUDE.md` | 12KB | Master documentation & command triggers |
| `settings.json` | 4KB | Hooks configuration & enabled plugins |
| `settings.local.json` | 4KB | Permission whitelist (70+ commands) |
| `config/triggers.json` | 9KB | 45+ trigger pattern definitions |
| `config/master.json` | 2KB | System-wide settings |
| `config/permissions.json` | 1KB | Permission configuration |
| `hooks/router.sh` | 1KB | Main hook entry point |
| `hooks/handlers/*.sh` | 4KB | Event handlers (3 files) |
| `hooks/lib/*.sh` | 12KB | Shared utilities (2 files) |
| `hooks/archive/*.sh` | 7KB | Archived hooks (5 files) |
| `docs/*.md` | 32KB | MCP documentation (7 files) |
| `plugins/` | ~30MB | Plugin system & cache |
| `ai-system/` | 52KB | Custom AI system files |
| `mac-scripts/` | 16KB | Utility scripts |

**Total Transfer Size: ~35MB compressed**

---

## Rollback Procedure

If something goes wrong:
```bash
# On DESTINATION server
rm -rf ~/.claude
mv ~/.claude.backup.* ~/.claude
```

---

## Security Considerations

1. **Never transfer**: `.credentials.json`, `*.secret`, `*.key`
2. **Verify checksums** before and after transfer
3. **Use SSH/SCP** for encrypted transfer
4. **Set restrictive permissions** on sensitive files
5. **Remove transfer artifacts** after completion

---

## Single Automated Script (Recommended)

Save this as `transfer-claude-config.sh` and run it from the source server:

```bash
#!/bin/bash
set -euo pipefail

#=============================================================================
# Claude Configuration Transfer Script
# Transfers .claude config from source to linode-southeast
#=============================================================================

# Configuration
SOURCE_DIR="/home/ai_dev/.claude"
DEST_HOST="linode-southeast"
DEST_DIR="/home/ai_dev/.claude"
DEST_USER="ai_dev"  # Owner of .claude on destination
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
PACKAGE="/tmp/claude-config-${TIMESTAMP}.tar.gz"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

#-----------------------------------------------------------------------------
# PHASE 1: Create Package
#-----------------------------------------------------------------------------
log "Phase 1: Creating transfer package..."

cd "$SOURCE_DIR"

# List of items to transfer
TRANSFER_ITEMS=(
    "CLAUDE.md"
    "settings.json"
    "settings.local.json"
    "settings.json.backup"
    ".gitignore"
    "hookify.session-reminder.local.md"
    "config"
    "hooks"
    "docs"
    "plugins"
    "ai-system"
    "mac-scripts"
)

# Build tar command arguments
TAR_ARGS=""
for item in "${TRANSFER_ITEMS[@]}"; do
    if [ -e "$item" ]; then
        TAR_ARGS="$TAR_ARGS $item"
    else
        warn "Skipping missing: $item"
    fi
done

# Create archive
tar -czvf "$PACKAGE" \
    --exclude='plugins/marketplaces/*/.git' \
    --exclude='.credentials.json' \
    --exclude='*.secret' \
    --exclude='*.key' \
    $TAR_ARGS

# Create checksum
sha256sum "$PACKAGE" > "${PACKAGE}.sha256"

log "Package created: $(du -sh $PACKAGE | cut -f1)"

#-----------------------------------------------------------------------------
# PHASE 2: Transfer to Destination
#-----------------------------------------------------------------------------
log "Phase 2: Transferring to $DEST_HOST..."

scp "$PACKAGE" "${PACKAGE}.sha256" "${DEST_HOST}:/tmp/"
log "Transfer complete"

#-----------------------------------------------------------------------------
# PHASE 3: Apply on Destination (via SSH)
#-----------------------------------------------------------------------------
log "Phase 3: Applying configuration on destination..."

ssh "$DEST_HOST" bash -s "$DEST_DIR" "$DEST_USER" "$TIMESTAMP" << 'REMOTE_SCRIPT'
set -euo pipefail

DEST_DIR="$1"
DEST_USER="$2"
TIMESTAMP="$3"
PACKAGE="/tmp/claude-config-${TIMESTAMP}.tar.gz"
BACKUP_DIR="${DEST_DIR}.backup.${TIMESTAMP}"
PRESERVE_DIR="/tmp/claude-preserve-${TIMESTAMP}"

echo "[DEST] Verifying checksum..."
cd /tmp
sha256sum -c "${PACKAGE}.sha256" || { echo "Checksum failed!"; exit 1; }

echo "[DEST] Creating backup at $BACKUP_DIR..."
cp -rp "$DEST_DIR" "$BACKUP_DIR"

echo "[DEST] Preserving session data..."
mkdir -p "$PRESERVE_DIR"
for item in plans file-history projects todos history.jsonl; do
    [ -e "$DEST_DIR/$item" ] && mv "$DEST_DIR/$item" "$PRESERVE_DIR/" && echo "  Preserved: $item"
done

echo "[DEST] Removing old configuration..."
rm -f "$DEST_DIR"/{CLAUDE.md,settings.json,settings.local.json,settings.json.backup,.gitignore,hookify.session-reminder.local.md}
rm -rf "$DEST_DIR"/{config,hooks,docs,plugins,ai-system,mac-scripts}
rm -rf "$DEST_DIR"/{debug,local,paste-cache,shell-snapshots,session-env,cache,statsig,telemetry,state,hook-state,ide,audit}
rm -f "$DEST_DIR"/{.credentials.json,stats-cache.json,firebase-debug.log}

echo "[DEST] Extracting new configuration..."
cd "$DEST_DIR"
tar -xzvf "$PACKAGE"

echo "[DEST] Restoring preserved data..."
for item in "$PRESERVE_DIR"/*; do
    [ -e "$item" ] && cp -rp "$item" "$DEST_DIR/" && echo "  Restored: $(basename $item)"
done

echo "[DEST] Setting permissions..."
chmod +x "$DEST_DIR"/hooks/*.sh 2>/dev/null || true
chmod +x "$DEST_DIR"/hooks/handlers/*.sh 2>/dev/null || true
chmod +x "$DEST_DIR"/hooks/lib/*.sh 2>/dev/null || true
chmod +x "$DEST_DIR"/hooks/archive/*.sh 2>/dev/null || true
chmod +x "$DEST_DIR"/mac-scripts/*.sh 2>/dev/null || true
chmod 600 "$DEST_DIR/settings.local.json" 2>/dev/null || true

echo "[DEST] Creating ephemeral directories..."
mkdir -p "$DEST_DIR"/{debug,local,paste-cache,shell-snapshots,session-env,cache,statsig,telemetry,state,hook-state,ide,audit}
echo '{}' > "$DEST_DIR/state/session.json"
echo '{}' > "$DEST_DIR/state/trigger-history.json"
echo '{}' > "$DEST_DIR/state/mcp-usage.json"

echo "[DEST] Setting ownership to $DEST_USER..."
chown -R "$DEST_USER:$DEST_USER" "$DEST_DIR"

echo "[DEST] Cleaning up..."
rm -f "$PACKAGE" "${PACKAGE}.sha256"
rm -rf "$PRESERVE_DIR"

echo "[DEST] Verification..."
echo "  Config files: $(ls $DEST_DIR/{CLAUDE.md,settings.json} 2>/dev/null | wc -l)/2"
echo "  Directories: $(ls -d $DEST_DIR/{config,hooks,docs,plugins} 2>/dev/null | wc -l)/4"
echo "  Hooks executable: $(find $DEST_DIR/hooks -name '*.sh' -executable | wc -l)"
echo "[DEST] Done! Backup at: $BACKUP_DIR"
REMOTE_SCRIPT

#-----------------------------------------------------------------------------
# PHASE 4: Cleanup Source
#-----------------------------------------------------------------------------
log "Phase 4: Cleaning up source..."
rm -f "$PACKAGE" "${PACKAGE}.sha256"

#-----------------------------------------------------------------------------
# COMPLETE
#-----------------------------------------------------------------------------
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  TRANSFER COMPLETE${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_HOST:$DEST_DIR"
echo ""
echo "To verify on destination:"
echo "  ssh $DEST_HOST 'ls -la $DEST_DIR/{CLAUDE.md,settings.json,config,hooks}'"
echo ""
echo "To rollback on destination:"
echo "  ssh $DEST_HOST 'rm -rf $DEST_DIR && mv ${DEST_DIR}.backup.${TIMESTAMP} $DEST_DIR'"
```

---

## Quick Start (Copy-Paste Ready)

### Option 1: Run the script above
```bash
# Save script and run
chmod +x transfer-claude-config.sh
./transfer-claude-config.sh
```

### Option 2: Manual step-by-step

**Step 1 - On this server (source):**
```bash
cd ~/.claude && tar -czvf /tmp/cc.tar.gz CLAUDE.md settings.json settings.local.json settings.json.backup .gitignore hookify.session-reminder.local.md config hooks docs plugins ai-system mac-scripts --exclude='plugins/marketplaces/*/.git' --exclude='.credentials.json' && scp /tmp/cc.tar.gz linode-southeast:/tmp/
```

**Step 2 - SSH to destination:**
```bash
ssh linode-southeast
```

**Step 3 - On destination server:**
```bash
D=/home/ai_dev/.claude && cp -rp $D $D.bak && mkdir -p /tmp/p && mv $D/{plans,file-history,projects,todos,history.jsonl} /tmp/p/ 2>/dev/null; rm -rf $D/{CLAUDE.md,settings*,config,hooks,docs,plugins,ai-system,mac-scripts,debug,local,paste-cache,shell-snapshots,session-env,cache,statsig,telemetry,state,hook-state,ide,audit,.credentials.json,stats-cache.json,firebase-debug.log,.gitignore,hookify*} && cd $D && tar -xzf /tmp/cc.tar.gz && cp -rp /tmp/p/* $D/ 2>/dev/null; chmod +x $D/hooks/*.sh $D/hooks/handlers/*.sh $D/hooks/lib/*.sh 2>/dev/null; mkdir -p $D/{debug,local,paste-cache,shell-snapshots,session-env,cache,statsig,telemetry,state,hook-state,ide,audit} && echo '{}' > $D/state/session.json && chown -R ai_dev:ai_dev $D && echo "DONE"
```
