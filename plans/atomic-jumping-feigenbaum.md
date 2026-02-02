# SSH Image Paste Solution for Claude Code

## Problem Statement
When SSH'd from MacBook Pro to Linux server running Claude Code, clipboard paste (Ctrl+V) doesn't work for images because SSH doesn't share clipboard. Need a seamless way to send screenshots/images to the server for Claude to analyze.

## Solution Overview

Build a **two-component system**:
1. **Mac-side**: Hammerspoon hotkey that captures clipboard image and SCPs to server
2. **Server-side**: Hook integration + image cache infrastructure for Claude to access images

### User Configuration
- **Keyboard shortcut method**: Hammerspoon
- **SSH alias**: `linode-sydney` (from ~/.ssh/config)
- **Auto-copy path**: Yes (path copied to clipboard after upload)

### Design Goals
- One keyboard shortcut to paste image (Cmd+Shift+V)
- No manual scp commands
- Auto-generated file paths with timestamps
- Full integration with existing `.claude` hooks architecture
- Path auto-copied to clipboard for easy paste into Claude prompt

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MacBook Pro                               │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Hammerspoon Hotkey (Cmd+Shift+V)                       │    │
│  │        ↓                                                │    │
│  │  ~/bin/claude-paste.sh                                  │    │
│  │    1. pngpaste → temp file                              │    │
│  │    2. scp linode-sydney:~/.claude/paste-cache/images/   │    │
│  │    3. Copy full remote path to clipboard                │    │
│  │    4. Show macOS notification                           │    │
│  └─────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ SCP via linode-sydney alias
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│                    Linux Server (linode-sydney)                  │
│                                                                  │
│  ~/.claude/paste-cache/images/                                  │
│    ├── 2026-02-02_143022_a7f3b2.png                             │
│    ├── 2026-02-02_143156_c9d4e1.png                             │
│    └── .index.json  (metadata tracking)                         │
│                                                                  │
│  ~/.claude/hooks/handlers/image-paste.sh                        │
│    - Triggered by "show images" / "recent screenshots"          │
│    - Lists available images for Claude                          │
│                                                                  │
│  ~/.claude/config/triggers.json                                 │
│    - New "image" service patterns                               │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Server-Side Infrastructure

#### 1.1 Create Image Cache Directory
```bash
mkdir -p ~/.claude/paste-cache/images
```

#### 1.2 Add Image Triggers to `~/.claude/config/triggers.json`
Add new `"image"` service section:
```json
"image": [
  {
    "pattern": "^(show images|list images|recent images|recent screenshots)",
    "action": "LIST_IMAGES",
    "message": "📷 IMAGE: List recent images from ~/.claude/paste-cache/images/ using: ls -lt ~/.claude/paste-cache/images/ | head -10"
  },
  {
    "pattern": "^(latest image|last screenshot|show screenshot)",
    "action": "SHOW_LATEST",
    "message": "📷 IMAGE: Show the most recent image. Find it with: ls -t ~/.claude/paste-cache/images/ | head -1"
  }
]
```

#### 1.3 Create Image Handler `~/.claude/hooks/handlers/image-paste.sh`
Simple handler that responds to image-related triggers:
- Lists recent images with timestamps
- Provides full paths for Claude's Read tool
- Tracks image usage in state

#### 1.4 Update Router
Add image handler routing to `router.sh` (if needed for PreToolUse events).

---

### Phase 2: Mac-Side Script

#### 2.1 Install Prerequisites on Mac
```bash
brew install pngpaste  # Clipboard to PNG (required)
```

#### 2.2 Create `~/bin/claude-paste.sh` on Mac
```bash
#!/bin/bash
# claude-paste.sh - Paste clipboard image to remote Claude Code server
# Uses SSH config alias: linode-sydney

# Configuration
SSH_ALIAS="linode-sydney"
REMOTE_PATH=".claude/paste-cache/images"

# Generate unique filename
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
HASH=$(openssl rand -hex 3)
FILENAME="${TIMESTAMP}_${HASH}.png"
TEMP_FILE="/tmp/claude-paste-${FILENAME}"

# 1. Save clipboard to temp file
if ! pngpaste "$TEMP_FILE" 2>/dev/null; then
    osascript -e 'display notification "No image in clipboard" with title "Claude Paste" sound name "Basso"'
    exit 1
fi

# 2. Get remote home directory (cache this for performance)
REMOTE_HOME=$(ssh "$SSH_ALIAS" 'echo $HOME' 2>/dev/null)
if [ -z "$REMOTE_HOME" ]; then
    REMOTE_HOME="/home/ai_dev"  # Fallback
fi

# 3. SCP to server using SSH alias
if scp "$TEMP_FILE" "${SSH_ALIAS}:${REMOTE_PATH}/${FILENAME}" 2>/dev/null; then
    # 4. Copy full remote path to clipboard
    FULL_PATH="${REMOTE_HOME}/${REMOTE_PATH}/${FILENAME}"
    echo -n "$FULL_PATH" | pbcopy

    # 5. Notify success
    osascript -e "display notification \"Copied: ${FILENAME}\" with title \"Claude Paste ✓\" sound name \"Glass\""

    # 6. Cleanup
    rm -f "$TEMP_FILE"

    exit 0
else
    osascript -e 'display notification "Upload failed - check SSH connection" with title "Claude Paste" sound name "Basso"'
    rm -f "$TEMP_FILE"
    exit 1
fi
```

#### 2.3 Make Executable & Create Directory
```bash
mkdir -p ~/bin
chmod +x ~/bin/claude-paste.sh
```

#### 2.4 Add Hammerspoon Hotkey

Add to `~/.hammerspoon/init.lua`:
```lua
-- Claude Code Image Paste (Cmd+Shift+V)
hs.hotkey.bind({"cmd", "shift"}, "V", function()
    local task = hs.task.new(os.getenv("HOME") .. "/bin/claude-paste.sh", function(exitCode, stdOut, stdErr)
        if exitCode ~= 0 then
            hs.alert.show("Claude Paste failed")
        end
    end)
    task:start()
end)
```

Then reload Hammerspoon config (Cmd+Shift+R or click menu bar → Reload Config).

---

### Phase 3: Integration & Workflow

#### Workflow After Setup
1. **Take screenshot** on Mac (Cmd+Shift+4 or similar)
2. **Press Cmd+Shift+V** to upload
3. **Paste the path** (already in clipboard) into Claude Code prompt
4. **Claude reads** the image using its Read tool

#### Example Usage
```
You: [Cmd+Shift+V uploads image, Ctrl+V pastes path]
/home/ai_dev/.claude/paste-cache/images/2026-02-02_143022_a7f3b2.png

please analyze this screenshot
```

Claude will use the Read tool to view the image at that path.

---

## Files to Create/Modify

### Server Side (Linux - linode-sydney)
| File | Action | Purpose |
|------|--------|---------|
| `~/.claude/paste-cache/images/` | Create dir | Image storage |
| `~/.claude/config/triggers.json` | Modify | Add image service patterns |
| `~/.claude/hooks/handlers/image-paste.sh` | Create | Image listing handler (55 lines) |
| `~/.claude/hooks/router.sh` | Modify | Add image handler routing |

### Mac Side (Your MacBook Pro)
| File | Action | Purpose |
|------|--------|---------|
| `~/bin/claude-paste.sh` | Create | Main paste script (45 lines) |
| `~/.hammerspoon/init.lua` | Modify | Add Cmd+Shift+V hotkey |

---

## Configuration Requirements

### SSH Config (already configured)
Your `~/.ssh/config` already has the `linode-sydney` alias configured. The script will use this directly.

---

## Verification Plan

### Step 1: Test pngpaste installation (Mac)
```bash
# Copy an image to clipboard first (Cmd+Shift+4 for screenshot)
pngpaste /tmp/test.png && ls -la /tmp/test.png
```

### Step 2: Test SSH connection (Mac)
```bash
ssh linode-sydney 'echo "Connection OK"'
```

### Step 3: Test the script manually (Mac)
```bash
# Copy an image to clipboard first
~/bin/claude-paste.sh
# Should show notification and copy path to clipboard
pbpaste  # Should show the remote path
```

### Step 4: Test the hotkey (Mac)
1. Copy an image to clipboard
2. Press Cmd+Shift+V
3. Notification should appear
4. Cmd+V in any text field should paste the remote path

### Step 5: Test with Claude Code (Server)
```
# In Claude Code prompt, paste the path and ask:
/home/ai_dev/.claude/paste-cache/images/2026-02-02_143022_a7f3b2.png

please describe this screenshot
```

### Step 6: Test trigger command (Server)
```
show images
# Should list recent uploads
```

---

## Future Enhancements

1. **Auto-suggest latest image**: Hook that detects "screenshot" in prompt and auto-injects latest image path
2. **Image compression**: Add `sips` resize before upload to reduce bandwidth
3. **Expiry/cleanup**: Cron job to delete images older than 7 days
4. **Multiple servers**: Config file with multiple SSH aliases
5. **Drag-and-drop**: Folder watcher for drag-drop workflow
