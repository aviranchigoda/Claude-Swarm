#!/bin/bash
# =============================================================================
# session.sh - Handler for Stop (session end) events
# =============================================================================
# Processes session end events, reminding the user to save context and
# performing session cleanup.
# =============================================================================

set -euo pipefail

# Get script directory and source common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"
source "$SCRIPT_DIR/../lib/state.sh"

# Read input from stdin (may contain session end info)
INPUT=$(cat)

# Emit reminder to save session context
emit "📌" "REMINDER: Say \"end session\" to save context to Pinecone before leaving."

# Log the session end event
log_action "SESSION_STOP" "Stop hook triggered"

# Future enhancements:
# - Auto-generate session summary
# - Check for unsaved changes
# - Prompt for context save if significant work was done

exit 0
