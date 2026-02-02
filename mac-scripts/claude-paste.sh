#!/bin/bash
# =============================================================================
# claude-paste.sh - Paste clipboard image to remote Claude Code server
# =============================================================================
# Usage:
#   1. Copy an image to clipboard (screenshot, etc.)
#   2. Run this script (or press Cmd+Shift+V if Hammerspoon is configured)
#   3. The remote path is copied to clipboard - just paste into Claude prompt
#
# Prerequisites (install on Mac):
#   brew install pngpaste
#
# Configuration:
#   - Uses SSH config alias: linode-sydney
#   - Remote path: ~/.claude/paste-cache/images/
# =============================================================================

set -euo pipefail

# Configuration - adjust if needed
SSH_ALIAS="${CLAUDE_SSH_ALIAS:-linode-sydney}"
REMOTE_PATH=".claude/paste-cache/images"
REMOTE_HOME_FALLBACK="/home/ai_dev"

# Generate unique filename with timestamp
TIMESTAMP=$(date +%Y-%m-%d_%H%M%S)
HASH=$(openssl rand -hex 3)
FILENAME="${TIMESTAMP}_${HASH}.png"
TEMP_FILE="/tmp/claude-paste-${FILENAME}"

# Cleanup function
cleanup() {
    rm -f "$TEMP_FILE"
}
trap cleanup EXIT

# 1. Check if pngpaste is installed
if ! command -v pngpaste &>/dev/null; then
    osascript -e 'display notification "pngpaste not installed. Run: brew install pngpaste" with title "Claude Paste" sound name "Basso"'
    exit 1
fi

# 2. Save clipboard to temp file
if ! pngpaste "$TEMP_FILE" 2>/dev/null; then
    osascript -e 'display notification "No image in clipboard" with title "Claude Paste" sound name "Basso"'
    exit 1
fi

# 3. Get file size for notification
FILE_SIZE=$(ls -lh "$TEMP_FILE" | awk '{print $5}')

# 4. Get remote home directory (with timeout)
REMOTE_HOME=$(timeout 5 ssh "$SSH_ALIAS" 'echo $HOME' 2>/dev/null || echo "$REMOTE_HOME_FALLBACK")

# 5. SCP to server using SSH alias
if scp -q "$TEMP_FILE" "${SSH_ALIAS}:${REMOTE_PATH}/${FILENAME}" 2>/dev/null; then
    # 6. Build full remote path
    FULL_PATH="${REMOTE_HOME}/${REMOTE_PATH}/${FILENAME}"

    # 7. Copy full remote path to clipboard
    echo -n "$FULL_PATH" | pbcopy

    # 8. Notify success with file info
    osascript -e "display notification \"${FILENAME} (${FILE_SIZE})
Path copied to clipboard\" with title \"Claude Paste ✓\" sound name \"Glass\""

    exit 0
else
    osascript -e 'display notification "Upload failed - check SSH connection" with title "Claude Paste" sound name "Basso"'
    exit 1
fi
