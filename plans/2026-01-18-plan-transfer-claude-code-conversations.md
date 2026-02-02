# Plan: Transfer Claude Code Conversations from Backup Server to MacBook

## Context

- **Problem:** MacBook crashed due to Shadowsocks issues
- **Recovery:** Used Claude Code on backup server (194.195.123.136) via Termius on iPad
- **Goal:** Retrieve those conversation logs to understand networking fix
- **Destination:** Keep as separate backup (not merge into MacBook Claude Code)

## Key Finding: No Automatic Sync

**Claude Code stores all data locally on each machine. There is no cloud sync.**

| Location | Path | Status |
|----------|------|--------|
| MacBook | `~/.claude/` | Local only |
| Backup server | `/root/.claude/` | Separate, isolated |

## Your SSH Configuration

```
Host backup
    HostName 194.195.123.136
    User root
    IdentityFile ~/.ssh/id_ed25519
```

**Auth:** SSH key (passwordless) - ready to use.

## Data Storage Structure

```
~/.claude/
├── history.jsonl              # Global conversation index
├── projects/                  # All conversation data
│   └── {encoded-path}/
│       └── {session-uuid}.jsonl   # Individual conversations
├── plans/                     # Markdown plan files
└── todos/                     # Session todo states
```

**Format:** JSONL (JSON Lines) - one JSON object per line with message content, timestamps, tool calls, etc.

---

## Transfer Plan

### Step 1: Check Claude Code Data Exists on Backup Server

```bash
ssh backup "ls -la ~/.claude/ && du -sh ~/.claude/projects/"
```

### Step 2: Create Compressed Archive on Backup Server

```bash
ssh backup "tar -czvf /tmp/claude-conversations.tar.gz \
  ~/.claude/history.jsonl \
  ~/.claude/projects/ \
  ~/.claude/plans/ \
  ~/.claude/todos/ 2>/dev/null"
```

### Step 3: Transfer to MacBook (Separate Backup Location)

```bash
# Create backup directory
mkdir -p ~/ubuntu-claude-backup

# Download the archive
scp backup:/tmp/claude-conversations.tar.gz ~/ubuntu-claude-backup/

# Extract
cd ~/ubuntu-claude-backup
tar -xzvf claude-conversations.tar.gz --strip-components=2
```

This creates:
```
~/ubuntu-claude-backup/
├── history.jsonl
├── projects/
├── plans/
└── todos/
```

### Step 4: View Conversations

**List all conversations:**
```bash
find ~/ubuntu-claude-backup/projects -name "*.jsonl" -type f
```

**Pretty-print a specific conversation:**
```bash
cat ~/ubuntu-claude-backup/projects/{path}/{session}.jsonl | jq -s .
```

**Extract just the human-readable messages:**
```bash
cat {file}.jsonl | jq -r 'select(.type == "user" or .type == "assistant") |
  if .type == "user" then "USER: " + (.message.content | tostring)
  else "CLAUDE: " + (.message.content[0].text // .message.content | tostring) end'
```

**Search for Shadowsocks/networking conversations:**
```bash
grep -l -r "shadowsocks\|tunnelblick\|vpn\|network" ~/ubuntu-claude-backup/projects/
```

### Step 5: Cleanup (Optional)

```bash
# Remove archive from backup server
ssh backup "rm /tmp/claude-conversations.tar.gz"
```

---

## Verification

1. **Check transfer integrity:**
   ```bash
   tar -tvf ~/ubuntu-claude-backup/claude-conversations.tar.gz | head -20
   ```

2. **Validate JSONL format:**
   ```bash
   head -1 ~/ubuntu-claude-backup/projects/*/*.jsonl | jq .
   ```

3. **Count conversations retrieved:**
   ```bash
   find ~/ubuntu-claude-backup/projects -name "*.jsonl" | wc -l
   ```

---

## Files Transferred

| Priority | Path | Purpose |
|----------|------|---------|
| High | `projects/**/*.jsonl` | All conversation content |
| High | `history.jsonl` | Conversation index |
| Medium | `plans/` | Markdown plans created |
| Low | `todos/` | Session todo states |

---

## Notes

- The `aidev` host in your SSH config has a LocalCommand that syncs ~/.claude/ TO that server, but not back. This is a one-way sync.
- If you want bi-directional sync in the future, consider adding a similar rsync command for the reverse direction.
