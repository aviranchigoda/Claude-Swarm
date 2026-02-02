# Plan: Fix Software Folder Sync to Linux Workspace

## Problem Summary
The `filesync-client` application crashes with a stack overflow when scanning the `/Users/aviranchigoda/Desktop/software` directory. The directory contains deep nested structures (node_modules, .venv, etc.) that cause the recursive scanner to exhaust the 8MB stack.

## Current State
- **Client binary exists**: `/Users/aviranchigoda/Desktop/software/filesync/build/filesync-client` (built Jan 15)
- **Deep scanner is enabled**: `USE_DEEP_SCANNER 1` in `scanner.h:344`
- **Server IP reachable**: `172.105.183.244` responds to ping

## Root Cause Analysis
1. **Deep scanner IS enabled** (`USE_DEEP_SCANNER 1`) but the binary may predate this change
2. The recursive `scan_directory()` uses ~4.4KB per stack frame
3. Deep directory trees (potentially 1500+ levels) exhaust the 8MB stack
4. If deep scanner init fails, code falls back to recursive (buggy path)

## Implementation Steps

### Step 1: Rebuild Client with Deep Scanner
```bash
cd /Users/aviranchigoda/Desktop/software/filesync
make clean
make client
```
This ensures the deep scanner code is compiled into the binary.

### Step 2: Verify Server is Running
SSH to aidev and check/start the server:
```bash
ssh aidev
cd ~/filesync  # or wherever server is
./build/filesync-server -d ~/workspace -p 9999 -v
```

### Step 3: Start Client and Test
```bash
cd /Users/aviranchigoda/Desktop/software/filesync
./build/filesync-client -w ~/Desktop/software -s 172.105.183.244 -p 9999 -v
```

Expected output:
- "Starting deep scan of: /Users/aviranchigoda/Desktop/software"
- Deep Scan Statistics printout (no segfault)
- Connection to server and file sync

## Files to Modify
None needed if rebuild works. If issues persist:
- `/Users/aviranchigoda/Desktop/software/filesync/client/scanner.h`
- `/Users/aviranchigoda/Desktop/software/filesync/client/scanner_deep.h`

## Verification
1. Client starts without segfault
2. Deep scanner statistics are printed (dirs_scanned, files_scanned, etc.)
3. Files appear in `~/workspace` on the Linux server
