#!/usr/bin/env bash
# PreToolUse Handler: Block Task tool, redirect to Emrakul CLI
# Integration from: ai-engineering-elliot/config/hooks/block-task-tool.sh
#
# Purpose: Intercept Claude Code's native Task tool calls and deny them,
# redirecting to Emrakul's external worker delegation system which uses
# separate billing (Cursor, Codex, Kimi, OpenCode) instead of burning quota.

set -euo pipefail

# Read tool call JSON from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Block Task tool - redirect to Emrakul CLI
if [[ "$TOOL_NAME" == "Task" ]]; then
    cat << 'ENDJSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "QUOTA PROTECTION: Task tool burns 20x quota per sub-agent call.\n\nUse 'emrakul delegate <worker> \"task\"' instead:\n\n  Workers:\n  - cursor: Implementation, multi-file refactors (Opus 4.5)\n  - codex: Debugging, tests, call tracing (GPT-5.2)\n  - kimi: Internet research, documentation (Kimi K2.5)\n  - opencode: Quick edits, small fixes (GLM 4.7)\n\n  Examples:\n  - emrakul delegate cursor \"Implement JWT authentication\"\n  - emrakul delegate codex \"Write tests for auth module\"\n  - emrakul delegate kimi \"Research OAuth 2.0 best practices\"\n  - emrakul delegate opencode \"Fix typo in config.py\"\n\n  Parallel execution:\n  - emrakul delegate kimi \"Research A\" --bg &\n  - emrakul delegate cursor \"Implement B\" --bg &\n  - emrakul status all"
  }
}
ENDJSON
    exit 0
fi

# Allow all other tools
exit 0
