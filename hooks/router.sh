#!/bin/bash
# =============================================================================
# router.sh - Unified Claude Hook Router
# =============================================================================
# Main entry point for all hook events. Routes to appropriate handlers based
# on the CLAUDE_HOOK_EVENT environment variable.
# =============================================================================

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source shared utilities
source "$SCRIPT_DIR/lib/common.sh"

# Read input from stdin
INPUT=$(cat)

# Get the hook event type (defaults to UserPromptSubmit)
EVENT="${CLAUDE_HOOK_EVENT:-UserPromptSubmit}"

# Route to appropriate handler
case "$EVENT" in
    UserPromptSubmit)
        # Pass input to prompt handler
        echo "$INPUT" | "$SCRIPT_DIR/handlers/prompt-submit.sh"
        ;;

    PostToolUse)
        # Pass to post-tool handler
        echo "$INPUT" | "$SCRIPT_DIR/handlers/post-tool.sh"
        ;;

    Stop)
        # Pass to session handler
        echo "$INPUT" | "$SCRIPT_DIR/handlers/session.sh"
        ;;

    PreToolUse)
        echo "$INPUT" | "$SCRIPT_DIR/handlers/pre-tool.sh"
        ;;

    *)
        # Unknown event - log and ignore
        log_action "UNKNOWN_EVENT" "$EVENT"
        ;;
esac
