# FileSync Deep-Level Debugging Continuation Plan

## Executive Summary

Based on analysis of claude-history1.md through claude-history3.md and the current codebase state, this plan outlines how to continue debugging at the lowest possible software engineering level.

**Current State**: Most critical compilation/linking/runtime bugs are FIXED. System can now compile and run, but has outstanding issues preventing reliable large-scale syncs.

---

## Bug Status Summary

### FIXED (7 issues)
| ID | Issue | Fix Applied |
|----|-------|-------------|
| CE-1 | off_t vs long type mismatch | Switched to opendir/readdir |
| CE-2 | Format specifier mismatch | Cast to `unsigned long long` + `%llu` |
| CE-3 | Label-declaration C11 violation | Added empty statement after label |
| CE-4 | Variable redefinition | Block scoping |
| LE-1 | getdirentries deprecated | opendir/readdir implementation |
| RT-1 | Invalid fd in FD_SET | Guard check in sender_poll |
| RT-2 | NULL pointer in block checksums | NULL check + enable checksums |

### OUTSTANDING (4 issues)
| ID | Issue | Severity | File:Line |
|----|-------|----------|-----------|
| NET-1 | CRC32 computed but never validated | MEDIUM | server/receiver.h:336 |
| NET-2 | No connection timeout mechanism | LOW | client/sender.h |
| SYNC-1 | Large sync stalls after FILE_META flood | HIGH | Protocol flow |
| PERF-1 | No packet-level hex dump logging | DEBUG | sender.h, receiver.h |

---

## Phase 1: Implement CRC32 Validation (NET-1)

**Location**: `server/receiver.h:330-340`

**Current Code**:
```c
header.checksum = 0;
uint32_t computed_crc = crc32(&header, sizeof(header));
if (payload_len > 0) {
    computed_crc ^= crc32(client->recv_payload, payload_len);
}
(void)computed_crc;  /* TODO: verify against client->recv_header.checksum */
```

**Fix**: Add validation against received checksum and handle corrupted packets.

**Files to Modify**:
- `server/receiver.h` - Add checksum verification
- `client/sender.h` - Ensure checksums are computed correctly before send

---

## Phase 2: Add Packet-Level Instrumentation (PERF-1)

**Purpose**: Enable deep protocol debugging with hex dumps of all packets.

**Implementation**:
1. Add `hex_dump()` utility function to `common/network.h`
2. Add `LOG_PACKET` macro that logs packet type, sequence, length, file_id, block_index
3. Add conditional hex dump of first 64 bytes of payload

**Files to Modify**:
- `common/network.h` - Add hex_dump utility
- `client/sender.h` - Add [SEND] logging before each packet
- `server/receiver.h` - Add [RECV] logging after each packet parsed

---

## Phase 3: Diagnose Large Sync Stall (SYNC-1)

**Symptom**: Server log shows `packets=2101` then stalls. Client sent FILE_META for all files but sync doesn't complete.

**Root Cause Investigation**:
1. Check if server sends PKT_BLOCK_REQUEST for files needing blocks
2. Verify client handles PKT_BLOCK_REQUEST correctly
3. Check if PKT_FILE_COMPLETE is sent after 0-block files
4. Verify PKT_SYNC_COMPLETE handling

**Debugging Steps**:
1. Add logging to show state machine transitions
2. Log file_id for each FILE_META sent and each FILE_COMPLETE received
3. Track which files are stuck in "pending" state

**Files to Examine**:
- `server/main.c` - handle_packet() for PKT_FILE_META
- `server/assembler.h` - assembler_begin_file() return conditions
- `client/sender.h` - handling of PKT_BLOCK_REQUEST
- `client/main.c` - main event loop state machine

---

## Phase 4: Low-Level Memory Analysis

**Tools**:
- `leaks ./build/filesync-client` (macOS)
- `valgrind --leak-check=full` (Linux server)

**Areas to Verify**:
1. BlockChecksum arrays freed on file completion
2. mmap regions unmapped correctly
3. Ring buffers don't leak on connection errors
4. PendingFile structs freed after finalization

---

## Phase 5: Protocol State Machine Verification

**Client States**:
```
DISCONNECTED → CONNECTING → HANDSHAKE → READY → SYNCING → READY (loop)
```

**Server States per File**:
```
FILE_META received → PENDING → BLOCKS_REQUESTED → RECEIVING → COMPLETE → FREED
```

**Verification Points**:
1. Add state transition logging
2. Verify no state gets stuck
3. Check timeout on stuck states

---

## Implementation Order (User Selected: Packet Instrumentation First)

### Step 1: Add hex_dump() utility to common/network.h
```c
static inline void hex_dump(const char *label, const void *data, size_t len) {
    const uint8_t *p = (const uint8_t *)data;
    fprintf(stderr, "[HEX] %s (%zu bytes): ", label, len);
    for (size_t i = 0; i < len && i < 64; i++) {
        fprintf(stderr, "%02x", p[i]);
    }
    if (len > 64) fprintf(stderr, "...");
    fprintf(stderr, "\n");
}
```

### Step 2: Add [SEND] logging to client/sender.h
In `sender_send_packet()`:
```c
fprintf(stderr, "[SEND] type=%02x seq=%u len=%zu\n",
        type, s->next_seq, payload_len);
hex_dump("PAYLOAD", payload, payload_len);
```

### Step 3: Add [RECV] logging to server/receiver.h
In packet parsing after header validation:
```c
fprintf(stderr, "[RECV] type=%02x seq=%u len=%u from=%s\n",
        header->type, ntohl(header->sequence),
        ntohl(header->payload_len), client->addr_str);
hex_dump("PAYLOAD", payload, payload_len);
```

### Step 4: Add state machine logging
Track file_id transitions:
- `[FILE_META] file_id=%llu path=%s blocks=%u`
- `[BLOCK_REQ] file_id=%llu blocks_requested=%u`
- `[BLOCK_DATA] file_id=%llu block=%u`
- `[FILE_COMPLETE] file_id=%llu`

### Step 5: Test and analyze logs
Run sync with instrumentation, then:
```bash
grep -E "SEND|RECV|FILE_META|BLOCK|COMPLETE" /tmp/*.log
```

### Step 6: Fix discovered bugs based on trace

### Step 7: Implement CRC32 validation

---

## Critical Files to Modify

| File | Changes Required |
|------|-----------------|
| `server/receiver.h:336` | Add CRC32 validation |
| `common/network.h` | Add hex_dump() function |
| `client/sender.h` | Add [SEND] packet logging |
| `server/receiver.h` | Add [RECV] packet logging |
| `server/main.c` | Add state machine logging |
| `client/main.c` | Add state machine logging |

---

## Verification Commands

After fixes, run:

```bash
# Server (Linux via SSH to get logs on Mac)
ssh root@172.105.183.244 'cd ~/filesync && make clean && make CC=gcc server && ./build/filesync-server -d ~/sync-dest -p 9999 -v' 2>&1 | tee /tmp/server.log

# Client (Mac)
cd ~/Desktop/software/filesync && make clean && make client && ./build/filesync-client -w ~/Desktop/software -s 172.105.183.244 -p 9999 -v 2>&1 | tee /tmp/client.log

# Analysis
grep -E "SEND|RECV|FILE_META|FILE_COMPLETE|BLOCK" /tmp/server.log /tmp/client.log | head -200
```

---

## Success Criteria

1. All files in ~/Desktop/software appear in ~/sync-dest on server
2. No `.filesync.tmp` files remain after sync
3. No segmentation faults
4. No memory leaks
5. Full protocol trace available for analysis
