# FileSync Debugging Continuation Plan

## Executive Summary

Based on comprehensive analysis of `claude-history3.md`, the engineering reports, and all source files, I've identified the current state and remaining work for the FileSync debugging effort.

**Current State**: Multiple critical bugs have been identified and partially fixed. The deep scanner implementation exists but needs verification and potentially further fixes.

---

## Analysis of Current State

### Issues Identified (from ENGINEERING-REPORT-Deep-Scanner-Issues.md)

| Issue | Type | Status | Fix Location |
|-------|------|--------|--------------|
| CE-1: off_t* vs long* | Compile | FIXED | scanner_deep.h - switched to opendir/readdir |
| CE-2: Format specifier | Compile | NEEDS VERIFICATION | scanner_deep.h:740 |
| CE-3: Label-declaration | Compile | FIXED | scanner.h - added empty statement |
| CE-4: Variable redefinition | Compile | FIXED | scanner.h - block scoping |
| LE-1: getdirentries deprecated | Linker | FIXED | scanner_deep.h - uses opendir/readdir |
| RT-1: Invalid fd in FD_SET | Runtime | FIXED | sender.h:348-352 |
| RT-2: NULL block_checksums | Runtime | FIXED | sender.h:148 |

### Current Code Analysis

**scanner_deep.h** (lines 306-345):
- Uses `opendir()`/`readdir()` instead of deprecated `getdirentries()` ✓
- Iterative design with explicit heap stack ✓
- mmap-based memory pools ✓
- Comprehensive exclusion patterns ✓

**scanner.h** (lines 344-416):
- `USE_DEEP_SCANNER=1` enabled ✓
- `compute_checksums = true` (changed from false) ✓
- Block scoping for variable redefinition fix ✓
- Empty statement after label ✓

**sender.h**:
- fd guard in `sender_poll()` at line 348-352 ✓
- NULL check for `block_checksums` at line 148 ✓

---

## Debugging Continuation Strategy

### Phase 1: Verification Build (Immediate)

**Objective**: Confirm the code compiles without errors

```bash
cd ~/Desktop/software/filesync
make clean && make client
```

**Expected Issues to Watch For**:
1. Any remaining `-Werror` failures
2. Format specifier warnings (`%llu` vs `%zu`)
3. Type mismatch warnings

**Files to Check if Compilation Fails**:
- `client/scanner_deep.h` - lines 739-740 (format specifiers)
- `client/scanner.h` - lines 414-416 (block scoping)

### Phase 2: Runtime Verification

**Objective**: Test the client on a small directory first

```bash
# Create test directory
mkdir -p ~/Desktop/filesync-test-small
echo "test" > ~/Desktop/filesync-test-small/file1.txt

# Run client on small directory (foreground, verbose)
./build/filesync-client -w ~/Desktop/filesync-test-small -s 172.105.183.244 -p 9999 -v
```

**What to Monitor**:
1. "Starting deep scan" message appears
2. Scan statistics printed
3. No segfaults during initial scan
4. Connection established successfully
5. Files synced to server

### Phase 3: Large Directory Test

**Objective**: Test on the actual ~/Desktop/software folder

```bash
./build/filesync-client -w ~/Desktop/software -s 172.105.183.244 -p 9999 -v 2>&1 | tee /tmp/filesync-full.log
```

**Expected Behavior**:
- Deep scanner statistics showing files scanned, dirs skipped
- No stack overflow (iterative design)
- Connection to server
- Initial sync completion

### Phase 4: Server-Side Verification

```bash
ssh ai_dev@172.105.183.244 "ls -la ~/sync-dest/ && cat /tmp/filesync.log | tail -50"
```

---

## Specific Bugs to Fix (if compilation fails)

### Bug Fix 1: Format Specifier Mismatch

**Location**: `client/scanner_deep.h` lines ~739-740, ~806-834

**Current Code** (potentially buggy):
```c
fprintf(stderr, "Stack overflow at depth %zu\n",
        scanner->stats.peak_stack_depth);  // peak_stack_depth is uint64_t
```

**Fix**:
```c
fprintf(stderr, "Stack overflow at depth %llu\n",
        (unsigned long long)scanner->stats.peak_stack_depth);
```

**All format specifier fixes needed in deep_scanner_print_stats()**:
- All `%llu` casts for `uint64_t` fields
- All `%.2f` for calculated floats

### Bug Fix 2: Potential Memory Leak

**Location**: `client/scanner.h` lines 391-402

**Issue**: Block checksums are allocated with `realloc()` but if deep scanner fails, old checksums may leak.

**Verification**: Check that `deep_scanner_free()` properly frees all allocated memory.

### Bug Fix 3: Thread Safety in FSWatcher

**Location**: `client/watcher.h`

**Issue**: The FSEvents callback runs on a dispatch queue (different thread), writing to the event queue. Verify mutex protection is correct.

---

## Low-Level Engineering Analysis

### Memory Architecture

```
Deep Scanner Memory Layout:
┌─────────────────────────────────────────────────────────────────────┐
│ DeepScanner Structure                                                │
├─────────────────────────────────────────────────────────────────────┤
│ DeepMemPool pool (128MB mmap'd)                                      │
│   └── Base address, used/high_water tracking                        │
├─────────────────────────────────────────────────────────────────────┤
│ DeepDirStack stack (mmap'd, starts 4096 entries)                    │
│   └── Grows dynamically up to 1M entries                            │
├─────────────────────────────────────────────────────────────────────┤
│ DeepFileIndex index (65536 × DeepFileEntry mmap'd)                  │
│   └── Each entry: 64 bytes hot + 4KB path + checksums               │
└─────────────────────────────────────────────────────────────────────┘
```

### Syscall Flow

```
Iterative Scan:
1. deep_stack_push(root_path)
2. while (deep_stack_pop(current_path)):
   a. opendir(current_path)        → 1 syscall
   b. while (readdir(dir)):        → ~1 syscall per entry
      - if DIR: deep_stack_push()
      - if FILE: stat() + add to index  → 1 syscall per file
   c. closedir(dir)
```

### Critical Path Analysis

The most likely crash points are:

1. **scanner_full_scan()** at `deep_scanner_init()` - memory allocation failure
2. **deep_scanner_scan()** at `deep_stack_push()` - stack growth failure
3. **sender_send_file_meta()** - NULL pointer on block_checksums
4. **sender_poll()** - invalid fd in FD_SET

---

## Files to Modify (if fixes needed)

| File | Lines | Change |
|------|-------|--------|
| `client/scanner_deep.h` | 739-740, 806-834 | Format specifier casts |
| `client/scanner.h` | 414-416 | Verify block scoping |
| `client/sender.h` | 146-183 | Verify NULL checks |

---

## Verification Checklist

After fixes, verify:

- [ ] `make clean && make client` succeeds with zero warnings
- [ ] Client runs on small test directory without crash
- [ ] Deep scanner statistics printed correctly
- [ ] Client connects to server successfully
- [ ] Files appear in server's sync-dest directory
- [ ] Client runs on ~/Desktop/software without stack overflow
- [ ] ~1000+ files scanned in software folder
- [ ] Reconnection works after network interruption

---

## Implementation Order

1. Attempt compilation - identify any remaining errors
2. Fix format specifier issues if present
3. Test on small directory
4. Test on large directory
5. Verify server receives files
6. Test edge cases (deleted files, modified files)
