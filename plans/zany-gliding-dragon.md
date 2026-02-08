# Claude Configuration Migration Blueprint

## Executive Summary

Migrate the complete Claude Code configuration system from **Server A** (source: this server) to **Server B** (destination: second Linux server). The migration preserves months of engineering work while respecting session-specific data on the destination.

**Total Source Size:** ~458MB
**Migration Payload (estimated):** ~45MB (core config only) or ~230MB (with projects)

---

## Directory Classification

### CATEGORY A: MUST MIGRATE (Core Configuration)
These are the engineered components that took months to build.

| Path | Size | Description |
|------|------|-------------|
| `CLAUDE.md` | 12KB | Master documentation and trigger system |
| `settings.json` | 1.2KB | Main settings (hooks, plugins, env) |
| `settings.local.json` | 2KB | Permission whitelist |
| `config/` | 24KB | triggers.json, permissions.json, master.json |
| `hooks/` | 72KB | Custom hook system (router.sh, lib/, handlers/) |
| `docs/` | 32KB | MCP documentation (7 files) |
| `plugins/` | 30MB | Installed plugins + cache + marketplaces |
| `ai-system/` | 52KB | AI system prompts (claude1.md) |
| `mac-scripts/` | 16KB | Utility scripts |

### CATEGORY B: PRESERVE ON DESTINATION (Do Not Overwrite)
The user wants to keep these on Server B.

| Path | Description |
|------|-------------|
| `plans/` | Plan files (markdown) |
| `file-history/` | File editing history |
| Any `.md` files | Plan/session markdown |

### CATEGORY C: SESSION-SPECIFIC (Do Not Migrate)
These are transient/ephemeral data tied to server-specific sessions.

| Path | Size | Reason |
|------|------|--------|
| `debug/` | 109MB | Debug logs (session-specific) |
| `todos/` | 3.2MB | Session todos |
| `shell-snapshots/` | 3MB | Shell state |
| `session-env/` | 388KB | Session environments |
| `paste-cache/` | 19MB | Clipboard cache |
| `history.jsonl` | 768KB | Command history |
| `state/session.json` | - | Current session state |
| `.credentials.json` | - | **SECURITY: Do not copy** |

### CATEGORY D: ASK USER (Optional Migration)
Large directories that may or may not be needed.

| Path | Size | Description |
|------|------|-------------|
| `projects/` | 185MB | Per-project CLAUDE.md files and settings |
| `local/` | 91MB | Local data storage |
| `state/trigger-history.json` | - | Trigger usage analytics |
| `state/mcp-usage.json` | - | MCP call tracking |

### CATEGORY E: DO NOT MIGRATE (System/Generated)
| Path | Reason |
|------|--------|
| `.git/` | Can be re-initialized |
| `statsig/` | Telemetry |
| `telemetry/` | Telemetry |
| `cache/` | Regenerated |
| `ide/` | IDE-specific |
| `audit/` | Server-specific |
| `hook-state/` | Session-specific |
| `*.log` | Logs |
| `stats-cache.json` | Cache |

---

## Migration Script

### Pre-Migration Checklist
```bash
# On Source Server (Server A)
# 1. Verify source directory
ls -la ~/.claude/

# 2. Check disk space
du -sh ~/.claude/

# 3. Verify SSH connectivity to destination
ssh user@server-b "echo 'SSH OK'"
```

### Option 1: Minimal Migration (Core Only ~45MB)
This copies only the essential engineered configuration.

```bash
#!/bin/bash
# migrate-claude-minimal.sh
# Run this on SOURCE server (Server A)

set -euo pipefail

# Configuration
DEST_USER="ai_dev"          # Change to destination username
DEST_HOST="server-b"         # Change to destination hostname/IP
DEST_PATH="/home/${DEST_USER}/.claude"
SRC_PATH="${HOME}/.claude"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="claude-config-minimal-${TIMESTAMP}.tar.gz"

echo "=== Claude Configuration Migration (Minimal) ==="
echo "Source: ${SRC_PATH}"
echo "Destination: ${DEST_USER}@${DEST_HOST}:${DEST_PATH}"
echo ""

# Step 1: Create archive of core configuration
echo "[1/5] Creating archive of core configuration..."
cd "${SRC_PATH}"

tar -czvf "/tmp/${ARCHIVE_NAME}" \
    --exclude='*.log' \
    --exclude='._*' \
    CLAUDE.md \
    settings.json \
    settings.local.json \
    settings.json.backup \
    config/ \
    hooks/ \
    docs/ \
    plugins/ \
    ai-system/ \
    mac-scripts/ \
    2>/dev/null || true

echo "Archive created: /tmp/${ARCHIVE_NAME}"
echo "Archive size: $(du -h /tmp/${ARCHIVE_NAME} | cut -f1)"

# Step 2: Backup destination's preserved directories
echo ""
echo "[2/5] Backing up destination's preserved directories..."
ssh "${DEST_USER}@${DEST_HOST}" "
    mkdir -p ~/.claude-backup-${TIMESTAMP}
    if [ -d ~/.claude/plans ]; then
        cp -r ~/.claude/plans ~/.claude-backup-${TIMESTAMP}/
    fi
    if [ -d ~/.claude/file-history ]; then
        cp -r ~/.claude/file-history ~/.claude-backup-${TIMESTAMP}/
    fi
    echo 'Backup created at ~/.claude-backup-${TIMESTAMP}'
"

# Step 3: Transfer archive
echo ""
echo "[3/5] Transferring archive to destination..."
scp "/tmp/${ARCHIVE_NAME}" "${DEST_USER}@${DEST_HOST}:/tmp/"

# Step 4: Extract on destination (preserving existing plans/file-history)
echo ""
echo "[4/5] Extracting configuration on destination..."
ssh "${DEST_USER}@${DEST_HOST}" "
    cd ~/.claude

    # Extract archive (will overwrite config files)
    tar -xzvf /tmp/${ARCHIVE_NAME}

    # Restore preserved directories if they were backed up
    if [ -d ~/.claude-backup-${TIMESTAMP}/plans ]; then
        rm -rf ~/.claude/plans
        mv ~/.claude-backup-${TIMESTAMP}/plans ~/.claude/
    fi
    if [ -d ~/.claude-backup-${TIMESTAMP}/file-history ]; then
        rm -rf ~/.claude/file-history
        mv ~/.claude-backup-${TIMESTAMP}/file-history ~/.claude/
    fi

    # Set correct permissions
    chmod +x ~/.claude/hooks/*.sh 2>/dev/null || true
    chmod +x ~/.claude/hooks/**/*.sh 2>/dev/null || true

    # Cleanup
    rm /tmp/${ARCHIVE_NAME}

    echo 'Extraction complete'
"

# Step 5: Verify
echo ""
echo "[5/5] Verifying migration..."
ssh "${DEST_USER}@${DEST_HOST}" "
    echo 'Checking critical files...'
    [ -f ~/.claude/CLAUDE.md ] && echo '  CLAUDE.md: OK' || echo '  CLAUDE.md: MISSING!'
    [ -f ~/.claude/settings.json ] && echo '  settings.json: OK' || echo '  settings.json: MISSING!'
    [ -d ~/.claude/config ] && echo '  config/: OK' || echo '  config/: MISSING!'
    [ -d ~/.claude/hooks ] && echo '  hooks/: OK' || echo '  hooks/: MISSING!'
    [ -d ~/.claude/plugins ] && echo '  plugins/: OK' || echo '  plugins/: MISSING!'
    [ -d ~/.claude/docs ] && echo '  docs/: OK' || echo '  docs/: MISSING!'

    echo ''
    echo 'Directory sizes:'
    du -sh ~/.claude/*/ 2>/dev/null | head -10
"

# Cleanup local
rm "/tmp/${ARCHIVE_NAME}"

echo ""
echo "=== Migration Complete ==="
echo "Next steps:"
echo "1. SSH to destination and run 'claude' to verify"
echo "2. Check hooks are working with 'ls -la ~/.claude/hooks/'"
echo "3. Verify plugins with 'cat ~/.claude/plugins/installed_plugins.json'"
```

### Option 2: Full Migration (With Projects ~230MB)
Includes per-project workspaces but excludes session data.

```bash
#!/bin/bash
# migrate-claude-full.sh
# Run this on SOURCE server (Server A)

set -euo pipefail

# Configuration
DEST_USER="ai_dev"          # Change to destination username
DEST_HOST="server-b"         # Change to destination hostname/IP
DEST_PATH="/home/${DEST_USER}/.claude"
SRC_PATH="${HOME}/.claude"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_NAME="claude-config-full-${TIMESTAMP}.tar.gz"

echo "=== Claude Configuration Migration (Full) ==="
echo "Source: ${SRC_PATH}"
echo "Destination: ${DEST_USER}@${DEST_HOST}:${DEST_PATH}"
echo ""

# Step 1: Create archive
echo "[1/5] Creating full archive (excluding session data)..."
cd "${SRC_PATH}"

tar -czvf "/tmp/${ARCHIVE_NAME}" \
    --exclude='debug' \
    --exclude='todos' \
    --exclude='shell-snapshots' \
    --exclude='session-env' \
    --exclude='paste-cache' \
    --exclude='history.jsonl' \
    --exclude='state/session.json' \
    --exclude='.credentials.json' \
    --exclude='statsig' \
    --exclude='telemetry' \
    --exclude='cache' \
    --exclude='ide' \
    --exclude='audit' \
    --exclude='hook-state' \
    --exclude='*.log' \
    --exclude='stats-cache.json' \
    --exclude='.git' \
    --exclude='._*' \
    --exclude='plans' \
    --exclude='file-history' \
    . 2>/dev/null || true

echo "Archive created: /tmp/${ARCHIVE_NAME}"
echo "Archive size: $(du -h /tmp/${ARCHIVE_NAME} | cut -f1)"

# Step 2: Backup destination
echo ""
echo "[2/5] Backing up destination..."
ssh "${DEST_USER}@${DEST_HOST}" "
    mkdir -p ~/.claude-backup-${TIMESTAMP}
    if [ -d ~/.claude/plans ]; then
        cp -r ~/.claude/plans ~/.claude-backup-${TIMESTAMP}/
    fi
    if [ -d ~/.claude/file-history ]; then
        cp -r ~/.claude/file-history ~/.claude-backup-${TIMESTAMP}/
    fi
    # Backup any existing markdown files in root
    find ~/.claude -maxdepth 1 -name '*.md' -exec cp {} ~/.claude-backup-${TIMESTAMP}/ \; 2>/dev/null || true
    echo 'Backup created'
"

# Step 3: Transfer
echo ""
echo "[3/5] Transferring archive..."
scp "/tmp/${ARCHIVE_NAME}" "${DEST_USER}@${DEST_HOST}:/tmp/"

# Step 4: Extract
echo ""
echo "[4/5] Extracting on destination..."
ssh "${DEST_USER}@${DEST_HOST}" "
    cd ~/.claude

    # Extract (preserves existing session data)
    tar -xzvf /tmp/${ARCHIVE_NAME}

    # Restore preserved directories
    if [ -d ~/.claude-backup-${TIMESTAMP}/plans ]; then
        rm -rf ~/.claude/plans 2>/dev/null || true
        mv ~/.claude-backup-${TIMESTAMP}/plans ~/.claude/
    fi
    if [ -d ~/.claude-backup-${TIMESTAMP}/file-history ]; then
        rm -rf ~/.claude/file-history 2>/dev/null || true
        mv ~/.claude-backup-${TIMESTAMP}/file-history ~/.claude/
    fi

    # Restore markdown files
    find ~/.claude-backup-${TIMESTAMP} -maxdepth 1 -name '*.md' -exec cp {} ~/.claude/ \; 2>/dev/null || true

    # Fix permissions
    chmod +x ~/.claude/hooks/*.sh 2>/dev/null || true
    chmod +x ~/.claude/hooks/**/*.sh 2>/dev/null || true
    find ~/.claude/plugins -name '*.sh' -exec chmod +x {} \; 2>/dev/null || true

    rm /tmp/${ARCHIVE_NAME}
"

# Step 5: Verify
echo ""
echo "[5/5] Verification..."
ssh "${DEST_USER}@${DEST_HOST}" "
    echo 'Critical files check:'
    [ -f ~/.claude/CLAUDE.md ] && echo '  CLAUDE.md: OK'
    [ -f ~/.claude/settings.json ] && echo '  settings.json: OK'
    [ -d ~/.claude/config ] && echo '  config/: OK'
    [ -d ~/.claude/hooks ] && echo '  hooks/: OK'
    [ -d ~/.claude/plugins ] && echo '  plugins/: OK'
    [ -d ~/.claude/projects ] && echo '  projects/: OK'

    echo ''
    echo 'Preserved directories:'
    [ -d ~/.claude/plans ] && echo '  plans/: PRESERVED' || echo '  plans/: (none)'
    [ -d ~/.claude/file-history ] && echo '  file-history/: PRESERVED' || echo '  file-history/: (none)'
"

rm "/tmp/${ARCHIVE_NAME}"
echo ""
echo "=== Full Migration Complete ==="
```

---

## Alternative: rsync Method (Incremental/Resumable)

For unreliable connections or repeated syncs:

```bash
#!/bin/bash
# migrate-claude-rsync.sh

DEST_USER="ai_dev"
DEST_HOST="server-b"

rsync -avz --progress \
    --exclude='debug/' \
    --exclude='todos/' \
    --exclude='shell-snapshots/' \
    --exclude='session-env/' \
    --exclude='paste-cache/' \
    --exclude='history.jsonl' \
    --exclude='state/session.json' \
    --exclude='.credentials.json' \
    --exclude='statsig/' \
    --exclude='telemetry/' \
    --exclude='cache/' \
    --exclude='ide/' \
    --exclude='audit/' \
    --exclude='hook-state/' \
    --exclude='*.log' \
    --exclude='stats-cache.json' \
    --exclude='.git/' \
    --exclude='._*' \
    --exclude='plans/' \
    --exclude='file-history/' \
    ~/.claude/ \
    "${DEST_USER}@${DEST_HOST}:~/.claude/"

echo "rsync complete"
```

---

## Post-Migration Steps

### On Destination Server (Server B)

```bash
# 1. Verify hooks are executable
chmod +x ~/.claude/hooks/router.sh
chmod +x ~/.claude/hooks/handlers/*.sh
chmod +x ~/.claude/hooks/lib/*.sh

# 2. Initialize empty state files if missing
mkdir -p ~/.claude/state
touch ~/.claude/state/session.json
touch ~/.claude/state/trigger-history.json
touch ~/.claude/state/mcp-usage.json

# 3. Initialize empty directories if missing
mkdir -p ~/.claude/plans
mkdir -p ~/.claude/file-history
mkdir -p ~/.claude/debug
mkdir -p ~/.claude/todos

# 4. Set up credentials (DO NOT COPY - regenerate)
# Run 'claude' and re-authenticate

# 5. Test the installation
claude --version
claude  # Start a session to test hooks

# 6. Verify hooks work
echo "Testing hooks..."
ls ~/.claude/hooks/
cat ~/.claude/settings.json | grep -A 20 '"hooks"'
```

### Verification Checklist

```bash
# Run this verification script on destination
#!/bin/bash
echo "=== Claude Migration Verification ==="

CHECKS_PASSED=0
CHECKS_FAILED=0

check() {
    if [ "$1" = "OK" ]; then
        echo "  [OK] $2"
        ((CHECKS_PASSED++))
    else
        echo "  [FAIL] $2"
        ((CHECKS_FAILED++))
    fi
}

# Core files
[ -f ~/.claude/CLAUDE.md ] && check OK "CLAUDE.md exists" || check FAIL "CLAUDE.md missing"
[ -f ~/.claude/settings.json ] && check OK "settings.json exists" || check FAIL "settings.json missing"
[ -f ~/.claude/settings.local.json ] && check OK "settings.local.json exists" || check FAIL "settings.local.json missing"

# Config
[ -f ~/.claude/config/triggers.json ] && check OK "triggers.json exists" || check FAIL "triggers.json missing"
[ -f ~/.claude/config/permissions.json ] && check OK "permissions.json exists" || check FAIL "permissions.json missing"
[ -f ~/.claude/config/master.json ] && check OK "master.json exists" || check FAIL "master.json missing"

# Hooks
[ -x ~/.claude/hooks/router.sh ] && check OK "router.sh executable" || check FAIL "router.sh not executable"
[ -f ~/.claude/hooks/lib/common.sh ] && check OK "lib/common.sh exists" || check FAIL "lib/common.sh missing"
[ -f ~/.claude/hooks/handlers/prompt-submit.sh ] && check OK "prompt-submit.sh exists" || check FAIL "prompt-submit.sh missing"

# Plugins
[ -f ~/.claude/plugins/installed_plugins.json ] && check OK "plugins registry exists" || check FAIL "plugins registry missing"
PLUGIN_COUNT=$(cat ~/.claude/plugins/installed_plugins.json | grep -c '"scope"' 2>/dev/null || echo 0)
[ "$PLUGIN_COUNT" -gt 0 ] && check OK "$PLUGIN_COUNT plugins installed" || check FAIL "No plugins found"

# Docs
DOC_COUNT=$(ls ~/.claude/docs/*.md 2>/dev/null | wc -l)
[ "$DOC_COUNT" -gt 0 ] && check OK "$DOC_COUNT MCP docs found" || check FAIL "No MCP docs"

# Preserved directories
[ -d ~/.claude/plans ] && check OK "plans/ preserved" || echo "  [INFO] plans/ not present"
[ -d ~/.claude/file-history ] && check OK "file-history/ preserved" || echo "  [INFO] file-history/ not present"

echo ""
echo "=== Results: $CHECKS_PASSED passed, $CHECKS_FAILED failed ==="
```

---

## Critical Files Inventory

### Files That MUST Exist After Migration

| File | Purpose |
|------|---------|
| `~/.claude/CLAUDE.md` | Master trigger system and documentation |
| `~/.claude/settings.json` | Hook configuration, enabled plugins |
| `~/.claude/settings.local.json` | Permission whitelist |
| `~/.claude/config/triggers.json` | 45+ trigger patterns |
| `~/.claude/config/permissions.json` | Auto-approved operations |
| `~/.claude/config/master.json` | System settings |
| `~/.claude/hooks/router.sh` | Main hook entry point |
| `~/.claude/hooks/lib/common.sh` | Shared utilities |
| `~/.claude/hooks/lib/state.sh` | State management |
| `~/.claude/hooks/handlers/prompt-submit.sh` | UserPromptSubmit handler |
| `~/.claude/hooks/handlers/post-tool.sh` | PostToolUse handler |
| `~/.claude/hooks/handlers/session.sh` | Stop handler |
| `~/.claude/plugins/installed_plugins.json` | Plugin registry |
| `~/.claude/docs/*.md` | MCP documentation (7 files) |

### Enabled Plugins (from settings.json)

| Plugin | Source |
|--------|--------|
| `clangd-lsp` | claude-plugins-official |
| `rust-analyzer-lsp` | claude-plugins-official |
| `code-review` | claude-code-plugins |
| `feature-dev` | claude-code-plugins |
| `pr-review-toolkit` | claude-code-plugins |
| `ralph-loop` | claude-plugins-official |
| `code-simplifier` | claude-plugins-official |
| `hookify` | claude-plugins-official |

---

## Rollback Plan

If migration fails or causes issues:

```bash
# On destination server
# Restore from backup
cp -r ~/.claude-backup-TIMESTAMP/* ~/.claude/

# Or completely reset
rm -rf ~/.claude
mkdir ~/.claude
# Re-run migration
```

---

## Questions for User

Before executing, please clarify:

1. **Server B connection details:**
   - Hostname/IP address?
   - Username?
   - SSH key or password auth?

2. **Include projects directory?** (185MB of per-project workspaces)
   - Yes = Full migration
   - No = Minimal migration

3. **Include local/ directory?** (91MB)
   - Contains local data storage

4. **Any additional files to preserve on Server B?**
   - Currently preserving: plans/, file-history/

5. **Preferred method:**
   - Option 1: tar + scp (one-shot, faster)
   - Option 2: rsync (incremental, resumable)
