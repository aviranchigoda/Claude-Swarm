#!/bin/bash
# =============================================================================
# claude-paste.sh - Screenshot and upload to remote Claude Code server
# =============================================================================
# Usage:
#   1. Have your Claude Code terminal tab active in iTerm2
#   2. Press Cmd+Shift+V (or run this script directly)
#   3. Select area to screenshot with crosshair
#   4. Path auto-types into your terminal - just add your question!
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

# 2. Capture screenshot to clipboard (interactive selection mode)
#    -i = interactive (select area), -c = copy to clipboard
screencapture -ic 2>/dev/null

# Check if user cancelled (no clipboard content)
sleep 0.2

# 3. Extract from clipboard to temp file
if ! pngpaste "$TEMP_FILE" 2>/dev/null; then
    osascript -e 'display notification "Screenshot cancelled or failed" with title "Claude Paste" sound name "Basso"'
    exit 1
fi

# 3. Get file size for notification
FILE_SIZE=$(ls -lh "$TEMP_FILE" | awk '{print $5}')

# 4. Get remote home directory (hardcoded for speed - no SSH call needed)
REMOTE_HOME="$REMOTE_HOME_FALLBACK"

# 5. SCP to server using SSH alias
if scp -q "$TEMP_FILE" "${SSH_ALIAS}:${REMOTE_PATH}/${FILENAME}" 2>/dev/null; then
    # 6. Build full remote path
    FULL_PATH="${REMOTE_HOME}/${REMOTE_PATH}/${FILENAME}"

    # 7. Copy path to clipboard
    echo -n "$FULL_PATH" | pbcopy

    # 8. Brief delay to ensure terminal is ready
    sleep 0.2

    # 9. Simulate Cmd+V to paste the path into active window
    osascript -e 'tell application "System Events" to keystroke "v" using command down'

    # 10. Play success sound
    afplay /System/Library/Sounds/Glass.aiff &

    exit 0
else
    osascript -e 'display notification "Upload failed - check SSH connection" with title "Claude Paste" sound name "Basso"'
    exit 1
fi
