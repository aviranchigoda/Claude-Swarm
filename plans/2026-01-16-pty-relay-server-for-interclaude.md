# PTY Relay Server for Inter-Claude Communication

## Goal
Enable the Claude instance on macOS (filesync folder) to execute commands on the Linux server (aidev) via a **persistent PTY relay connection** with SSH tunnel security.

## Architecture

```
┌─────────────────────────────────────┐         ┌─────────────────────────────────────┐
│  macOS Desktop (filesync)           │         │  Linux Server (aidev)               │
│                                     │         │                                     │
│  Claude Code ──► Bash tool          │         │  pty_relay_server (localhost:9998)  │
│       │                             │         │       │                             │
│       └──► nc localhost:9998        │         │       ├── PTY master ◄──► bash      │
│              │                      │   SSH   │       │   (persistent session)      │
│              └──────────────────────│◄═══════►│       └── Ring buffer + rate limit  │
│                   (port forward)    │ tunnel  │                                     │
│                                     │         │                                     │
│  ~/Desktop/software/filesync/       │         │  ~/connection-monitoring/           │
└─────────────────────────────────────┘         └─────────────────────────────────────┘

SSH tunnel: ssh -L 9998:localhost:9998 aidev -N (runs in background)
```

## Key Design Decisions
- **Persistent shell**: Environment variables, working directory, and shell state persist between commands
- **SSH tunnel only**: Server binds to localhost (127.0.0.1) - no direct network exposure
- **Server hostname**: `aidev` (from SSH config)

## Implementation Plan

### Phase 1: Linux Server - PTY Relay Server

Create `~/connection-monitoring/pty_relay_server.c` on the Linux server:

**Key Components:**
1. **TCP Listener** - Accept incoming connections on configurable port (default: 9998)
2. **PTY Spawner** - Create PTY pair and fork shell for each connection
3. **I/O Forwarder** - Bidirectional forwarding between socket and PTY master
4. **Rate Limiter** - Reuse token bucket from existing pty_relay.c
5. **Ring Buffer** - Capture all output (never lose data)

**Files to create on Linux server:**
```
~/connection-monitoring/
├── pty_relay_server.c    # Main server (epoll-based, multi-client)
├── Makefile              # Build instructions
└── README.md             # Usage documentation
```

**Server Features:**
- Single-threaded epoll event loop (handles multiple clients)
- Per-client: PTY master fd, shell PID, ring buffer, rate limiter
- Graceful shutdown on SIGINT/SIGTERM
- Client authentication (optional, simple shared secret)
- Logging with configurable verbosity

### Phase 2: macOS Client - Connection Helper

Two options for the macOS side:

**Option A: Use existing tools (Simplest)**
```bash
# From macOS, Claude can run:
nc SERVER_IP 9998
# or
socat - TCP:SERVER_IP:9998
```

**Option B: Custom client (Better UX)**
Create `~/Desktop/software/filesync/pty_client.c`:
- Connects to PTY relay server
- Handles terminal raw mode locally
- Provides reconnection logic
- Shows connection status

### Phase 3: Integration with Claude Code

The desktop Claude can execute commands on Linux via:
```bash
# One-shot command execution
echo "ls -la ~/workspace" | nc SERVER_IP 9998

# Interactive session (for debugging)
./pty_client -s SERVER_IP -p 9998
```

## Critical Files to Modify/Create

### On Linux Server (aidev):
| File | Action | Purpose |
|------|--------|---------|
| `~/connection-monitoring/pty_relay_server.c` | Create | Main server implementation |
| `~/connection-monitoring/Makefile` | Create | Build system |

### On macOS (optional):
| File | Action | Purpose |
|------|--------|---------|
| `~/Desktop/software/filesync/pty_client.c` | Create | Custom client (optional) |

## Server Implementation Details

### Data Structures
```c
typedef struct {
    int socket_fd;              // Network connection
    int pty_master;             // PTY master fd
    pid_t child_pid;            // Shell process
    RingBuffer output_buf;      // Captured output
    RateLimiter limiter;        // Flow control
    bool active;
} ClientSession;

typedef struct {
    int listen_fd;
    int epoll_fd;
    ClientSession clients[MAX_CLIENTS];
    int client_count;
    volatile sig_atomic_t running;
} PTYRelayServer;
```

### Event Loop
```c
while (server->running) {
    n = epoll_wait(epoll_fd, events, MAX_EVENTS, 100);
    for (i = 0; i < n; i++) {
        if (is_listen_socket(events[i]))
            accept_client();
        else if (is_client_socket(events[i]))
            forward_socket_to_pty();
        else if (is_pty_master(events[i]))
            forward_pty_to_socket();
    }
}
```

## Verification Steps

1. **Build server on Linux:**
   ```bash
   ssh aidev 'cd ~/connection-monitoring && make'
   ```

2. **Start SSH tunnel (macOS):**
   ```bash
   ssh -L 9998:localhost:9998 aidev -N -f
   ```

3. **Start server (Linux, in separate terminal or tmux):**
   ```bash
   ssh aidev '~/connection-monitoring/pty_relay_server -p 9998 -v'
   ```

4. **Test from macOS:**
   ```bash
   echo "whoami && pwd" | nc localhost 9998
   ```

5. **Verify persistent state:**
   ```bash
   # First command sets directory
   echo "cd /tmp" | nc localhost 9998
   # Second command should show /tmp
   echo "pwd" | nc localhost 9998
   ```

## Security Model

- **Server binds to 127.0.0.1 only** - No network exposure
- **Access via SSH tunnel** - Leverages existing SSH authentication
- **No additional auth needed** - If you can SSH, you can connect

## Usage Workflow

### Step 1: Start SSH Tunnel (one-time, in background)
```bash
# On macOS - establish persistent tunnel
ssh -L 9998:localhost:9998 aidev -N -f
```

### Step 2: Start PTY Relay Server (on Linux)
```bash
# On aidev
cd ~/connection-monitoring
./pty_relay_server -p 9998 -v
```

### Step 3: Connect from macOS Claude
```bash
# Send commands through the tunnel
echo "cd ~/workspace && ls -la" | nc localhost 9998

# Or interactive session
nc localhost 9998
```

## Persistent Session Benefits

Since the shell session persists:
- `cd /some/dir` in one command affects subsequent commands
- Environment variables set with `export` remain available
- Shell aliases and functions work normally
- Background processes continue running
