# Unified Claude Autonomous Launcher - Engineering Plan

## Executive Summary

Merge three systems into one unified, interactive launcher:
1. **claude.sh** - Simple iTerm2 grid spawner for Linode Claude instances
2. **claude-autonomous** - Autonomous execution with safety controls
3. **claude-bootup** - Session initialization and persistence

**Core Requirements:**
- Real-time customizability with minimal keypresses
- Simple quick-launch mode AND advanced configuration mode
- Safe autonomous operation (sandboxed, no destructive commands)
- Cursor IDE integration for remote file editing

---

## Current System Analysis

### 1. claude.sh (Local: `/Users/aviranchigoda/claude.sh`)
**Purpose:** Launch multiple Claude Code instances on Linode via iTerm2 grids

**Key Features:**
- SSH to `linode` host (172.105.183.244)
- YOLO mode permissions (allow all except rm/rmdir/shred)
- iTerm2 AppleScript automation (5x2, 2x2 grids)
- Project selection from `/root/*` directories
- Folder upload via rsync

**Strengths:** Simple, visual, immediate
**Weaknesses:** No autonomy, fixed grid sizes, no persistence

### 2. Droid System (Binary: `/Users/aviranchigoda/.local/bin/droid`)
**Purpose:** Autonomous agent execution

**Key Features:**
- 83MB compiled binary (ARM64 Mach-O)
- Factory AI integration
- Autonomy levels: `auto-medium`, `auto-high`
- Custom droids, droid shields enabled

**Strengths:** True autonomous operation
**Weaknesses:** Binary (not customizable), separate from claude.sh

### 3. Cursor Remote Integration
**Command:** `cursor --folder-uri vscode-remote://ssh-remote+linode/<path>`

**Key Features:**
- Opens any Linode file/folder directly in Cursor IDE
- Uses SSH config for authentication
- Seamless remote editing

### 4. Factory Hooks System (`.factory/settings.json`)
**Key Features:**
- SessionStart hooks (omnibrain.py)
- PreToolUse hooks (check-ownership.sh)
- PostToolUse hooks (repomix refresh)
- Command allowlist/denylist

---

## Unified Architecture Design

### Core Concept: "claude-unified.sh"

```
┌─────────────────────────────────────────────────────────────────┐
│                    CLAUDE UNIFIED LAUNCHER                       │
├─────────────────────────────────────────────────────────────────┤
│  [Q]uick Launch (1 key)  │  [A]dvanced Mode  │  [C]ursor Open   │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Quick Launch: ./claude.sh → Enter → Running in 3 seconds       │
│                                                                  │
│  Advanced Mode:                                                  │
│    ├── Instance Count: [1-100] (type number, auto-grid)         │
│    ├── Autonomy Level: [0-4] (0=manual, 4=full auto)           │
│    ├── Project: [arrow keys to select]                          │
│    ├── Safety: [sandbox|docker|bare] (default: sandbox)        │
│    └── Persistence: [tmux|screen|none]                          │
│                                                                  │
│  Cursor: Open any remote file in Cursor with 2 keys             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Detailed Engineering Specification

### Module 1: Quick Launch (1-Key Operation)

**Trigger:** Just press Enter on script launch (or `./claude.sh q`)

**Behavior:**
1. Uses last-used settings (stored in `~/.claude-unified-state.json`)
2. Default: 4 instances, /root, autonomy level 2 (supervised), sandbox mode
3. Launches immediately with no prompts

**Implementation:**
```bash
quick_launch() {
    load_state
    [ -z "$LAST_PROJECT" ] && LAST_PROJECT="/root"
    [ -z "$LAST_COUNT" ] && LAST_COUNT=4
    [ -z "$LAST_AUTONOMY" ] && LAST_AUTONOMY=2
    spawn_instances "$LAST_COUNT" "$LAST_PROJECT" "$LAST_AUTONOMY"
}
```

### Module 2: Dynamic Grid Calculator

**Input:** Any number 1-100
**Output:** Optimal grid layout (rows × cols)

**Algorithm:**
```bash
calculate_grid() {
    local n=$1
    local cols=$(echo "sqrt($n)" | bc)
    [ $((cols * cols)) -lt $n ] && cols=$((cols + 1))
    local rows=$(( (n + cols - 1) / cols ))
    echo "$rows $cols"
}
```

**Examples:**
- 1 → 1×1
- 4 → 2×2
- 10 → 3×4 (or 2×5)
- 20 → 4×5
- 50 → 7×8

### Module 3: Autonomy Levels

| Level | Name | Behavior | Safety |
|-------|------|----------|--------|
| 0 | Manual | Every action requires approval | Maximum |
| 1 | Supervised | Read ops auto-approved, writes need approval | High |
| 2 | Guarded | All ops auto-approved except system commands | Medium |
| 3 | Autonomous | Full auto, safety sandbox active | Low |
| 4 | Unrestricted | Full auto, no sandbox (dangerous) | None |

**Implementation via settings.json generation:**
```bash
generate_autonomy_settings() {
    local level=$1
    case $level in
        0) echo '{"defaultMode":"askPermission"}' ;;
        1) echo '{"defaultMode":"askPermission","permissions":{"allow":["Read","Glob","Grep"]}}' ;;
        2) echo '{"defaultMode":"acceptEdits","permissions":{"deny":["Bash(rm *)","Bash(shutdown *)"]}}' ;;
        3) echo '{"defaultMode":"acceptEdits","permissions":{"allow":["*"],"deny":["Bash(rm -rf /)"]}}' ;;
        4) echo '{"defaultMode":"acceptEdits","permissions":{"allow":["*"]}}' ;;
    esac
}
```

### Module 4: Safety Sandbox System

**Docker Isolation (Recommended for Level 3+):**
```bash
setup_sandbox() {
    ssh $SSH_HOST "docker run -d --name claude-sandbox-\$\$ \
        -v /root/$PROJECT:/workspace:rw \
        -v /root/.claude:/root/.claude:rw \
        --network host \
        --memory 4g \
        --cpus 2 \
        ubuntu:22.04 sleep infinity"
}
```

**Filesystem Snapshot (Backup before autonomous runs):**
```bash
create_snapshot() {
    ssh $SSH_HOST "tar -czf /root/backups/snapshot-\$(date +%s).tar.gz /root/$PROJECT"
}
```

### Module 5: Cursor Integration

**Single-key open remote file:**
```bash
cursor_open() {
    echo "Enter path on Linode (relative to /root):"
    read -p "> " remote_path
    cursor --folder-uri "vscode-remote://ssh-remote+linode/root/$remote_path"
}
```

**Hotkey Integration (via Hammerspoon/Karabiner):**
- `Cmd+Shift+L` → Opens Cursor with last-used Linode path
- `Cmd+Shift+O` → Opens picker for Linode directories

### Module 6: Session Persistence (tmux)

**Auto-attach to existing or create new:**
```bash
launch_persistent() {
    local session_name="claude-$PROJECT_NAME"
    ssh -t $SSH_HOST "tmux has-session -t $session_name 2>/dev/null && \
        tmux attach -t $session_name || \
        tmux new-session -d -s $session_name 'cd $PROJECT && claude' && \
        tmux attach -t $session_name"
}
```

**Recovery after crash:**
```bash
recover_sessions() {
    echo "Active tmux sessions on Linode:"
    ssh $SSH_HOST "tmux list-sessions 2>/dev/null || echo 'No sessions'"
    read -p "Attach to session: " session
    ssh -t $SSH_HOST "tmux attach -t $session"
}
```

### Module 7: Real-Time Control Panel

**Live Dashboard (runs in separate iTerm tab):**
```bash
control_panel() {
    while true; do
        clear
        echo "╔════════════════════════════════════════╗"
        echo "║      CLAUDE CONTROL PANEL              ║"
        echo "╠════════════════════════════════════════╣"
        ssh $SSH_HOST "ps aux | grep -c '[c]laude'" | xargs echo "║ Active Instances:"
        ssh $SSH_HOST "df -h /root | tail -1 | awk '{print \$4}'" | xargs echo "║ Disk Free:"
        ssh $SSH_HOST "uptime | awk -F'load average:' '{print \$2}'" | xargs echo "║ Load:"
        echo "╠════════════════════════════════════════╣"
        echo "║ [+] Add Instance  [-] Remove Instance  ║"
        echo "║ [s] Stop All      [r] Restart All      ║"
        echo "║ [c] Open Cursor   [t] tmux Sessions    ║"
        echo "║ [q] Quit Panel                         ║"
        echo "╚════════════════════════════════════════╝"
        read -t 2 -n 1 cmd
        case $cmd in
            +) spawn_single_instance ;;
            -) kill_oldest_instance ;;
            s) stop_all_instances ;;
            r) restart_all_instances ;;
            c) cursor_open ;;
            t) show_tmux_sessions ;;
            q) break ;;
        esac
    done
}
```

---

## User Interface Design

### Main Menu (Minimal Keystrokes)

```
╔══════════════════════════════════════════════════════════════════╗
║                    CLAUDE UNIFIED LAUNCHER v2.0                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  Press a key:                                                     ║
║                                                                   ║
║    [ENTER] Quick Launch (4 instances, last project, guarded)     ║
║    [1-9]   Launch N instances (press number directly)            ║
║    [a]     Advanced configuration                                 ║
║    [c]     Open in Cursor IDE                                     ║
║    [p]     Control Panel (live dashboard)                         ║
║    [r]     Recover/attach tmux sessions                           ║
║    [u]     Upload folder to Linode                                ║
║    [q]     Quit                                                   ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

### Advanced Configuration (Arrow Key Navigation)

```
╔══════════════════════════════════════════════════════════════════╗
║                    ADVANCED CONFIGURATION                         ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  Instances:    [▸ 10 ◂]     (←/→ to adjust, type number)         ║
║  Project:      [▸ vertex-exchange ◂]  (↑/↓ to select)            ║
║  Autonomy:     [▸ Level 2: Guarded ◂]                            ║
║  Safety:       [▸ Sandbox (Docker) ◂]                            ║
║  Persistence:  [▸ tmux ◂]                                        ║
║                                                                   ║
║  [ENTER] Launch with these settings                               ║
║  [s] Save as default                                              ║
║  [ESC] Back to main menu                                          ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## File Structure

```
/Users/aviranchigoda/
├── claude-unified.sh              # Main unified launcher
├── .claude-unified/
│   ├── state.json                 # Last-used settings
│   ├── presets/                   # Saved configurations
│   │   ├── quick.json
│   │   ├── full-auto.json
│   │   └── development.json
│   ├── hooks/
│   │   ├── pre-launch.sh          # Runs before spawning
│   │   ├── post-launch.sh         # Runs after spawning
│   │   └── on-crash.sh            # Recovery script
│   └── logs/
│       └── sessions/              # Session logs
│
└── .ssh/config                    # SSH configuration (existing)
    Host linode
        HostName 172.105.183.244
        User root
        ControlMaster auto
        ControlPath ~/.ssh/sockets/%r@%h-%p
        ControlPersist 600
```

**On Linode Server (/root/):**
```
/root/
├── claude-bootup/
│   ├── init.sh                    # Bootup sequence
│   ├── settings.json              # Autonomy settings
│   └── hooks/
│       ├── session-start.sh
│       └── check-ownership.sh
├── claude-autonomous/
│   ├── sandbox/                   # Docker sandbox configs
│   ├── snapshots/                 # Pre-run backups
│   └── watchdog.sh                # Safety monitor
└── [your projects...]
```

---

## Implementation Steps

### Phase 1: Core Script Refactor
1. Create `claude-unified.sh` with modular functions
2. Implement quick-launch with state persistence
3. Add dynamic grid calculator
4. Migrate existing `claude.sh` functionality

### Phase 2: Autonomy Integration
5. Implement autonomy level settings generator
6. Add safety sandbox (Docker) option
7. Create filesystem snapshot system
8. Integrate with Factory hooks if available

### Phase 3: Persistence & Recovery
9. Add tmux session management
10. Implement crash recovery
11. Create session logging

### Phase 4: Real-Time Control
12. Build control panel dashboard
13. Add hotkey integration for Cursor
14. Implement live instance management

### Phase 5: Polish
15. Add preset configurations
16. Create install script
17. Write usage documentation

---

## Safety Guarantees

1. **Default Safe:** Level 2 (Guarded) is default - no destructive commands
2. **Explicit Danger:** Level 4 requires typing "I UNDERSTAND" to enable
3. **Snapshots:** Auto-snapshot before Level 3+ runs
4. **Watchdog:** Background process monitors for runaway operations
5. **Kill Switch:** `Cmd+Shift+K` emergency stop all instances

---

## Verification Steps

1. **Quick Launch Test:**
   ```bash
   ./claude-unified.sh
   # Press Enter - should launch 4 instances immediately
   ```

2. **Grid Test:**
   ```bash
   ./claude-unified.sh
   # Press 7 - should create 3×3 grid (9 panes, 7 with Claude)
   ```

3. **Cursor Integration Test:**
   ```bash
   ./claude-unified.sh
   # Press c, type "vertex-exchange"
   # Should open Cursor with /root/vertex-exchange
   ```

4. **Autonomy Test:**
   ```bash
   # Launch with Level 3
   # Verify Claude auto-approves safe commands
   # Verify Claude blocks rm -rf
   ```

5. **Recovery Test:**
   ```bash
   # Kill terminal mid-session
   ./claude-unified.sh
   # Press r - should show active tmux sessions
   # Attach and verify work preserved
   ```

---

## User Decisions (Confirmed)

1. **Droid Binary:** Both as options - menu to choose between droid or native Claude autonomy per session
2. **Cursor Hotkeys:** Both - system-wide hotkey (Hammerspoon) plus in-script option
3. **Docker on Linode:** Install Docker - include Docker installation in implementation
4. **Factory AI Integration:** Optional toggle - detect if Factory is available and use it, otherwise fall back to standalone

---

## Additional Implementation Details

### Docker Installation on Linode
```bash
setup_docker_linode() {
    ssh $SSH_HOST "apt-get update && apt-get install -y docker.io docker-compose"
    ssh $SSH_HOST "systemctl enable docker && systemctl start docker"
    ssh $SSH_HOST "docker pull ubuntu:22.04"  # Pre-pull sandbox image
}
```

### Hammerspoon System-Wide Hotkey
**File:** `~/.hammerspoon/init.lua`
```lua
-- Cmd+Shift+L: Open last Linode project in Cursor
hs.hotkey.bind({"cmd", "shift"}, "L", function()
    local state = hs.json.read("~/.claude-unified/state.json")
    local project = state and state.last_project or "/root"
    hs.execute("cursor --folder-uri 'vscode-remote://ssh-remote+linode" .. project .. "'")
end)

-- Cmd+Shift+O: Open Linode project picker
hs.hotkey.bind({"cmd", "shift"}, "O", function()
    hs.execute("osascript -e 'tell app \"iTerm2\" to activate' && ~/.claude-unified/picker.sh")
end)

-- Cmd+Shift+K: Emergency kill all Claude instances
hs.hotkey.bind({"cmd", "shift"}, "K", function()
    hs.execute("ssh linode 'pkill -f claude; tmux kill-server 2>/dev/null'")
    hs.alert.show("All Claude instances killed")
end)
```

### Factory AI Detection & Toggle
```bash
detect_factory() {
    if [ -f "$HOME/.factory/settings.json" ] && command -v droid &>/dev/null; then
        FACTORY_AVAILABLE=true
        echo -e "${GREEN}Factory AI detected${NC}"
    else
        FACTORY_AVAILABLE=false
        echo -e "${YELLOW}Factory AI not detected - using standalone mode${NC}"
    fi
}

# In menu, show Factory option only if available
show_autonomy_options() {
    echo "  [1] Claude Native Autonomy (permissions-based)"
    if [ "$FACTORY_AVAILABLE" = true ]; then
        echo "  [2] Factory Droid (full autonomous agent)"
    fi
}
```

### Updated Main Menu
```
╔══════════════════════════════════════════════════════════════════╗
║                    CLAUDE UNIFIED LAUNCHER v2.0                   ║
╠══════════════════════════════════════════════════════════════════╣
║  [Factory AI: Detected] [Docker: Ready] [tmux: 3 sessions]       ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║    [ENTER] Quick Launch (4 instances, guarded mode)              ║
║    [1-9]   Launch N instances directly                           ║
║    [a]     Advanced configuration                                 ║
║    [d]     Launch with Droid (Factory AI autonomous)             ║
║    [c]     Open in Cursor IDE (also: Cmd+Shift+L globally)       ║
║    [p]     Control Panel (live dashboard)                         ║
║    [r]     Recover/attach tmux sessions                           ║
║    [u]     Upload folder to Linode                                ║
║    [i]     Install/setup Docker on Linode                         ║
║    [q]     Quit                                                   ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Final Implementation Checklist

### Phase 1: Core Script (Local)
- [ ] Create `claude-unified.sh` with modular architecture
- [ ] Implement quick-launch with state persistence (`~/.claude-unified/state.json`)
- [ ] Add dynamic grid calculator (any number 1-100)
- [ ] Migrate existing `claude.sh` functions
- [ ] Add Cursor integration (`c` key + `cursor --folder-uri`)

### Phase 2: System-Wide Integration
- [ ] Create Hammerspoon config for global hotkeys
- [ ] `Cmd+Shift+L` - Open last project in Cursor
- [ ] `Cmd+Shift+O` - Project picker
- [ ] `Cmd+Shift+K` - Emergency kill switch

### Phase 3: Linode Server Setup
- [ ] Install Docker on Linode
- [ ] Create `/root/claude-bootup/` directory structure
- [ ] Create `/root/claude-autonomous/` with safety configs
- [ ] Set up sandbox Docker container template
- [ ] Configure tmux for session persistence

### Phase 4: Autonomy System
- [ ] Implement 5 autonomy levels (0-4) via settings.json generation
- [ ] Add Factory AI detection and droid integration
- [ ] Create watchdog process for runaway detection
- [ ] Implement pre-run snapshots for Level 3+

### Phase 5: Control & Recovery
- [ ] Build real-time control panel dashboard
- [ ] Add instance add/remove/restart controls
- [ ] Implement tmux session recovery
- [ ] Create crash recovery hooks

### Phase 6: Polish
- [ ] Add preset configurations (quick, dev, full-auto)
- [ ] Create one-line installer script
- [ ] Test all pathways end-to-end
