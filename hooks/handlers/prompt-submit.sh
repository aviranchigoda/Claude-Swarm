#!/bin/bash
# =============================================================================
# prompt-submit.sh - Handler for UserPromptSubmit events
# =============================================================================
# Processes user input and matches against configured triggers to inject
# system messages directing Claude to use appropriate MCP tools.
# =============================================================================

set -euo pipefail

# Get script directory and source common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/state.sh"

# Read input from stdin
INPUT=$(cat)

# Convert to lowercase for pattern matching
INPUT_LOWER=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')

# Validate config exists
if [ ! -f "$TRIGGERS_FILE" ]; then
    log_action "CONFIG_MISSING" "triggers.json not found"
    exit 0
fi

# Increment message count for session tracking
increment_message_count

# Try to match against configured triggers
if match_trigger "$INPUT_LOWER"; then
    # Trigger was matched and system message was emitted
    exit 0
fi

# No trigger matched - this is normal, just exit silently
exit 0
