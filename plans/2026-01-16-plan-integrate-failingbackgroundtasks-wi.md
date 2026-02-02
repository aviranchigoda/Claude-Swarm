# Plan: Integrate failing-background-tasks with Filesync Monitoring

## Summary
Create a Node.js wrapper that monitors the filesync-client process and uses the failing-background-tasks orchestrator to automatically detect failures and propose recovery solutions using Claude Opus 4.5 agents.

## Current Status
- **Filesync sync completed**: 264 files successfully synced to server
- **failing-background-tasks library**: TypeScript library for multi-agent failure recovery already exists

## Integration Approach

### Option A: Node.js Process Monitor (Recommended)
Create a wrapper that:
1. Spawns filesync-client as a child process
2. Monitors stdout/stderr for errors and progress
3. Uses the Orchestrator to track sync as a "task"
4. Triggers agent recovery when sync fails/stalls

### Critical Files to Modify/Create

1. **New file**: `filesync/monitor/filesync-monitor.ts`
   - Spawns filesync-client process
   - Parses output for progress and errors
   - Registers with Orchestrator

2. **New file**: `filesync/monitor/filesync-failure-patterns.ts`
   - Define failure patterns specific to filesync (connection refused, FD exhaustion, APFS errors, etc.)

3. **Existing**: `failing-background-tasks/src/failure-detector.ts`
   - Add filesync-specific patterns

## Implementation Steps

### Step 1: Create Filesync Monitor Module
```
filesync/monitor/
  ├── filesync-monitor.ts      # Process wrapper
  ├── failure-patterns.ts      # Filesync failure patterns
  ├── recovery-strategies.ts   # Recovery actions (restart, increase FD limit, etc.)
  └── index.ts                 # Export all
```

### Step 2: Define Filesync Failure Patterns
- `APFS_COMPRESSION_ERROR`: mmap failure on compressed files
- `FD_EXHAUSTION`: "Failed to begin file assembly" messages
- `CONNECTION_REFUSED`: Server unreachable
- `TIMEOUT`: Sync stalled (no progress for X seconds)
- `PARTIAL_SYNC`: Files completed < files expected

### Step 3: Implement Recovery Strategies
- **APFS Error**: Switch to read() based scanning (already done)
- **FD Exhaustion**: Restart server with higher ulimit
- **Connection Refused**: Wait and retry, check server status
- **Timeout/Stall**: Kill and restart client with fresh scan

### Step 4: Create CLI Interface
```bash
# Instead of running filesync-client directly
node filesync/monitor/index.js \
  --watch ~/Desktop/software \
  --server 172.105.183.244 \
  --port 9999 \
  --auto-recover
```

## Verification Plan
1. Run monitor with intentional failure (e.g., wrong port)
2. Verify failure detection triggers
3. Verify agent spawns and proposes solution
4. Verify recovery strategy executes
5. Confirm sync completes after recovery

## Questions for User
1. Should the monitor automatically execute recovery strategies, or just propose them?
2. Should recovery agents have access to modify server configuration (SSH)?
3. Priority: Is this for production use or development/testing?
