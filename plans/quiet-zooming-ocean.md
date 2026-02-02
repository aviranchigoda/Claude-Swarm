# TMUX Desktop Application - Implementation Plan

## Overview

Build a unified Electron + React + TypeScript desktop application that consolidates functionality from the `tmux-software` (11 branches) and `tmux-unified` repositories into a single, polished desktop app for managing:
- Linux server information
- Tmux sessions
- Claude processes
- MCP servers (full management)

## Design Principles

- **Black & white minimalist color scheme** with high information density
- **Multi-page navigation** (not everything on one window)
- **Cross-platform** (macOS and Linux equally)
- **SSH connection** to 172.105.183.244 as ai_dev

---

## Technology Stack

| Category | Technology |
|----------|------------|
| Framework | Electron 28+ |
| Build Tool | electron-vite |
| Frontend | React 18 + TypeScript 5 |
| Routing | react-router-dom 6 |
| State | Zustand |
| SSH | ssh2 (Node.js) |
| Styling | Tailwind CSS (dark theme) |
| Icons | lucide-react |
| Charts | recharts |
| Storage | electron-store |
| Packaging | electron-builder |

---

## Color Palette (Monochrome)

```
Backgrounds:
  primary:   #0a0a0a  (main bg)
  secondary: #111111  (cards)
  tertiary:  #1a1a1a  (hover)
  elevated:  #1f1f1f  (modals)

Text:
  primary:   #e6e6e6  (main text)
  secondary: #a3a3a3  (muted)
  tertiary:  #6b6b6b  (disabled)

Borders:
  default:   #2a2a2a
  hover:     #3a3a3a
  focus:     #4a4a4a

Status (subtle color accents):
  success:   #4ade80  (green - running)
  warning:   #fbbf24  (yellow)
  error:     #f87171  (red - stopped)
  info:      #60a5fa  (blue)
```

---

## Application Pages (6 Total)

### Page 1: Dashboard
- Connection status indicator (SSH online/offline)
- Quick stats cards: Sessions count, Claude processes, Memory usage, Uptime
- System health mini-charts (CPU/Memory trends)
- Recent activity log

### Page 2: Sessions
- List all tmux sessions with: name, pane count, attached status, working directory
- Actions: Create, Attach (opens terminal), Kill, View details
- Session detail modal with pane grid visualization

### Page 3: Claude Processes
- List running Claude processes with PIDs
- Memory usage per process (visual bars)
- Command lines (truncated)
- Actions: Kill individual, Kill all

### Page 4: Server
- System statistics: CPU, Memory, Disk, Uptime
- Hostname and IP display
- SSH connection details
- Refresh controls

### Page 5: MCP Servers
- List all 7 configured MCP servers with status badges
- Server types: HTTP (context7, github, greptile) and Command (pinecone, serena, firebase, supabase)
- Actions: Start, Stop, Restart
- Log viewer per server (real-time streaming)
- Configuration editor (edit settings.json)
- API key management (environment variables)
- Health monitoring

### Page 6: Settings
- SSH configuration (host, username, auth method)
- Auto-refresh intervals (5s, 10s, 30s, 60s)
- Theme settings (dark only for now)
- About section

---

## Project Structure

```
tmux-desktop/
├── electron.vite.config.ts
├── package.json
├── tsconfig.json
├── resources/
│   └── icon.png
├── src/
│   ├── main/                     # Electron Main Process
│   │   ├── index.ts
│   │   ├── ipc/
│   │   │   ├── sessions.ipc.ts
│   │   │   ├── processes.ipc.ts
│   │   │   ├── server.ipc.ts
│   │   │   ├── mcp.ipc.ts
│   │   │   └── settings.ipc.ts
│   │   ├── services/
│   │   │   ├── ssh.service.ts
│   │   │   ├── tmux.service.ts
│   │   │   ├── process.service.ts
│   │   │   ├── server.service.ts
│   │   │   ├── mcp.service.ts
│   │   │   └── terminal.service.ts
│   │   └── store/
│   │       └── config.store.ts
│   ├── preload/
│   │   └── index.ts
│   └── renderer/
│       ├── index.html
│       └── src/
│           ├── main.tsx
│           ├── App.tsx
│           ├── components/
│           │   ├── layout/
│           │   │   ├── Sidebar.tsx
│           │   │   ├── Header.tsx
│           │   │   └── MainLayout.tsx
│           │   ├── common/
│           │   │   ├── Button.tsx
│           │   │   ├── Card.tsx
│           │   │   ├── Badge.tsx
│           │   │   ├── Table.tsx
│           │   │   ├── Modal.tsx
│           │   │   └── StatusIndicator.tsx
│           │   ├── dashboard/
│           │   ├── sessions/
│           │   ├── processes/
│           │   ├── server/
│           │   ├── mcp/
│           │   └── settings/
│           ├── pages/
│           │   ├── DashboardPage.tsx
│           │   ├── SessionsPage.tsx
│           │   ├── ProcessesPage.tsx
│           │   ├── ServerPage.tsx
│           │   ├── MCPPage.tsx
│           │   └── SettingsPage.tsx
│           ├── hooks/
│           ├── store/
│           ├── types/
│           └── styles/
└── electron-builder.yml
```

---

## Key Services (Main Process)

### SSHService
- Connect/disconnect with auto-reconnect
- Execute commands with timeout
- Stream output for real-time logs
- Secure credential storage

### TmuxService
```typescript
// Commands via SSH:
tmux list-sessions -F "#{session_name}|#{session_windows}|#{session_attached}"
tmux list-panes -t <session> -F "#{pane_index}|#{pane_current_path}"
tmux new-session -d -s <name>
tmux kill-session -t <name>
```

### ProcessService
```typescript
// Commands via SSH:
ps aux | grep -E "[c]laude"
kill -9 <pid>
pkill -9 claude
```

### ServerService
```typescript
// Commands via SSH:
hostname
uptime -p
cat /proc/loadavg
free -b | grep Mem
df -B1 /
```

### MCPService
```typescript
// Config: cat ~/.claude.json
// Detect running: ps aux | grep -E "(mcp|@pinecone|firebase|supabase|serena)"
// Start: nohup npx -y @pinecone-database/mcp > /tmp/mcp-pinecone.log 2>&1 &
// Stop: pkill -f "@pinecone-database/mcp"
// Logs: tail -f /tmp/mcp-<name>.log
```

### TerminalService
- macOS: Open Terminal.app or iTerm via AppleScript
- Linux: Try gnome-terminal, konsole, xfce4-terminal, xterm

---

## Implementation Phases

### Phase 1: Project Setup (Day 1-2)
- [ ] Initialize electron-vite project
- [ ] Configure TypeScript, ESLint, Prettier
- [ ] Set up Tailwind CSS with dark theme
- [ ] Create folder structure
- [ ] Configure electron-builder for Mac/Linux

### Phase 2: SSH Infrastructure (Day 3-4)
- [ ] Implement SSHService with ssh2
- [ ] Add connection persistence and auto-reconnect
- [ ] Create secure credential storage
- [ ] Set up IPC handlers for SSH
- [ ] Test connection to 172.105.183.244

### Phase 3: Core UI Framework (Day 5-6)
- [ ] Build MainLayout with Sidebar navigation
- [ ] Implement React Router with 6 routes
- [ ] Create common UI components (Button, Card, Table, Badge, Modal)
- [ ] Set up Zustand stores
- [ ] Apply monochrome theme

### Phase 4: Dashboard Page (Day 7)
- [ ] Build QuickStats cards
- [ ] Create ConnectionStatus indicator
- [ ] Implement SystemHealth mini charts
- [ ] Add RecentActivity log

### Phase 5: Sessions Page (Day 8-9)
- [ ] Implement TmuxService
- [ ] Build SessionList with SessionCards
- [ ] Add CreateSession modal
- [ ] Implement terminal attach (cross-platform)
- [ ] Build PaneGrid visualizer

### Phase 6: Processes Page (Day 10)
- [ ] Implement ProcessService
- [ ] Build ProcessList with memory bars
- [ ] Add kill functionality

### Phase 7: Server Page (Day 11)
- [ ] Implement ServerService
- [ ] Build ServerStats cards with charts
- [ ] Add UptimeCard

### Phase 8: MCP Servers Page (Day 12-14)
- [ ] Implement MCPService (config parsing, process detection, lifecycle)
- [ ] Build MCPServerList with status badges
- [ ] Create start/stop/restart actions
- [ ] Build MCPLogs viewer with real-time streaming
- [ ] Create MCPConfig editor
- [ ] Add APIKeyManager

### Phase 9: Settings Page (Day 15)
- [ ] Build SSHSettings form
- [ ] Implement RefreshSettings
- [ ] Add AboutSection

### Phase 10: Polish & Packaging (Day 16-17)
- [ ] Add loading states and error handling
- [ ] Implement toast notifications
- [ ] Test on macOS and Linux
- [ ] Build DMG (Mac) and AppImage/DEB (Linux)

---

## Source Code Integration

### From tmux-software repository:
| Branch | Use For |
|--------|---------|
| files-4 | Session management logic, SSH commands, page structure |
| files-5/6 | Agent/Mission Control UI patterns, status badges |
| file-1/2 | MCP server configurations, hooks system reference |
| files-7 | MCP diagnostics scripts, environment setup |

### From tmux-unified repository:
| File | Use For |
|------|---------|
| claude-session.sh | Tmux session creation logic |
| install-server.sh | Tmux configuration, keybindings |
| COMMANDS.md | Command reference for features |

---

## Critical Files to Create

1. **src/main/services/ssh.service.ts** - Core SSH connection handling
2. **src/main/services/mcp.service.ts** - MCP server management
3. **src/renderer/src/store/appStore.ts** - Global state management
4. **src/renderer/src/pages/MCPPage.tsx** - MCP management interface
5. **src/renderer/src/components/layout/MainLayout.tsx** - App shell with navigation

---

## Verification Plan

### Testing Checklist:
1. [ ] SSH connects successfully to 172.105.183.244
2. [ ] Can list all tmux sessions
3. [ ] Can create/kill tmux sessions
4. [ ] Can attach to session (opens terminal)
5. [ ] Can list Claude processes with memory info
6. [ ] Can kill Claude processes
7. [ ] Server stats display correctly (CPU, Memory, Disk)
8. [ ] Can read ~/.claude.json MCP configuration
9. [ ] Can detect running MCP servers
10. [ ] Can start/stop/restart MCP servers
11. [ ] MCP logs stream in real-time
12. [ ] Can edit MCP configuration
13. [ ] Auto-refresh works at configured intervals
14. [ ] App builds for macOS (DMG)
15. [ ] App builds for Linux (AppImage)

### Manual Testing:
```bash
# Build and run
npm run dev

# Package for distribution
npm run package:mac
npm run package:linux
```

---

## Repository Setup

Create new repository: `tmux-desktop` (or use existing tmux-unified)

```bash
# Initialize with electron-vite
npm create electron-vite@latest tmux-desktop -- --template react-ts

# Install dependencies
cd tmux-desktop
npm install ssh2 zustand immer electron-store
npm install tailwindcss @headlessui/react lucide-react recharts
npm install -D @types/ssh2
```

---

## Notes

- All SSH operations run in main process (security)
- Renderer uses IPC to communicate with main process
- Credentials stored securely with electron-store encryption
- Real-time log streaming via SSH exec with callbacks
- Cross-platform terminal launching requires platform detection
