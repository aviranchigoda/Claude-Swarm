#!/usr/bin/env bash
# =============================================================================
# pre-tool.sh — PreToolUse Smart Gate
# =============================================================================
# Detects emrakul CLI availability at runtime. When emrakul is in PATH,
# prompts the user to consider external worker delegation for Task tool
# calls (separate billing via Cursor/Codex/Kimi/OpenCode). When emrakul
# is absent, allows Task tool through silently with zero overhead.
#
# Hook output contract:
#   - JSON with permissionDecision "ask"  → Claude prompts user
#   - No output + exit 0                 → tool proceeds silently
# =============================================================================

set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" == "Task" ]]; then
    if command -v emrakul &>/dev/null; then
        cat << 'ENDJSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "ask",
    "permissionDecisionReason": "Emrakul CLI detected. Consider: emrakul delegate <worker> \"task\"\nWorkers: cursor (Opus 4.5), codex (GPT-5.2), kimi (Kimi K2.5), opencode (GLM 4.7)\nAllow Task tool anyway?"
  }
}
ENDJSON
        exit 0
    fi
    exit 0
fi

exit 0
