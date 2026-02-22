#!/bin/bash
# =============================================================================
# post-tool.sh - Handler for PostToolUse events
# =============================================================================
# Processes post-tool events, primarily for auto-renaming plan files from
# random names to descriptive dated names.
# =============================================================================

set -euo pipefail

# Get script directory and source common utilities
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../lib/common.sh"

# Read input from stdin (not used currently, but available for future)
INPUT=$(cat)

# Get the file path from environment variable (set by Claude)
FILE="${CLAUDE_FILE_PATH:-}"

# Exit if no file path provided
if [ -z "$FILE" ]; then
    exit 0
fi

# Check if this is a plan file with a random name pattern
# Pattern: three lowercase words separated by hyphens, ending in .md
if [[ "$FILE" =~ \.claude/plans/[a-z]+-[a-z]+-[a-z]+\.md$ ]]; then
    # Rename the plan file to a dated, descriptive name
    rename_plan_file "$FILE"
fi

# Future: Add other post-tool processing here
# Examples:
# - Auto-format code after edits
# - Update file indexes
# - Trigger notifications

exit 0
