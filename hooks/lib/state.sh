#!/bin/bash
# =============================================================================
# state.sh - Session state management for the unified Claude hook system
# =============================================================================

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# Initialize a new session
# =============================================================================
init_session() {
    local project="$1"
    local session_id=$(uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || date +%s)
    local timestamp=$(date -Iseconds)

    mkdir -p "$STATE_DIR"

    cat > "$SESSION_FILE" << EOF
{
  "id": "$session_id",
  "started_at": "$timestamp",
  "project": "$project",
  "triggers_used": [],
  "mcps_called": [],
  "context_loaded": false,
  "message_count": 0
}
EOF

    log_action "SESSION_STARTED" "$session_id"
    echo "$session_id"
}

# =============================================================================
# Update session state
# =============================================================================
update_session() {
    local key="$1"
    local value="$2"

    if [ ! -f "$SESSION_FILE" ]; then
        init_session "unknown"
    fi

    local tmp_file=$(mktemp)
    jq --arg key "$key" --arg value "$value" '.[$key] = $value' "$SESSION_FILE" > "$tmp_file" 2>/dev/null
    mv "$tmp_file" "$SESSION_FILE"
}

# =============================================================================
# Add trigger to session
# =============================================================================
add_trigger_to_session() {
    local trigger="$1"

    if [ -f "$SESSION_FILE" ]; then
        local tmp_file=$(mktemp)
        jq --arg trigger "$trigger" '.triggers_used += [$trigger] | .triggers_used |= unique' \
           "$SESSION_FILE" > "$tmp_file" 2>/dev/null
        mv "$tmp_file" "$SESSION_FILE"
    fi
}

# =============================================================================
# Add MCP to session
# =============================================================================
add_mcp_to_session() {
    local mcp="$1"

    if [ -f "$SESSION_FILE" ]; then
        local tmp_file=$(mktemp)
        jq --arg mcp "$mcp" '.mcps_called += [$mcp] | .mcps_called |= unique' \
           "$SESSION_FILE" > "$tmp_file" 2>/dev/null
        mv "$tmp_file" "$SESSION_FILE"
    fi
}

# =============================================================================
# Increment message count
# =============================================================================
increment_message_count() {
    if [ -f "$SESSION_FILE" ]; then
        local tmp_file=$(mktemp)
        jq '.message_count += 1' "$SESSION_FILE" > "$tmp_file" 2>/dev/null
        mv "$tmp_file" "$SESSION_FILE"
    fi
}

# =============================================================================
# Mark context as loaded
# =============================================================================
mark_context_loaded() {
    update_session "context_loaded" "true"
}

# =============================================================================
# Get session summary
# =============================================================================
get_session_summary() {
    if [ -f "$SESSION_FILE" ]; then
        jq -r '
          "Session: \(.id)\n" +
          "Started: \(.started_at)\n" +
          "Project: \(.project)\n" +
          "Messages: \(.message_count)\n" +
          "Triggers: \(.triggers_used | join(", "))\n" +
          "MCPs: \(.mcps_called | join(", "))"
        ' "$SESSION_FILE" 2>/dev/null
    else
        echo "No active session"
    fi
}

# =============================================================================
# End session
# =============================================================================
end_session() {
    if [ -f "$SESSION_FILE" ]; then
        local session_id=$(jq -r '.id' "$SESSION_FILE")
        local ended_at=$(date -Iseconds)

        # Update with end time
        local tmp_file=$(mktemp)
        jq --arg ended_at "$ended_at" '. + {ended_at: $ended_at}' "$SESSION_FILE" > "$tmp_file"

        # Archive session
        local archive_dir="$STATE_DIR/sessions"
        mkdir -p "$archive_dir"
        mv "$tmp_file" "$archive_dir/${session_id}.json"

        # Clear current session
        rm -f "$SESSION_FILE"

        log_action "SESSION_ENDED" "$session_id"
    fi
}

# =============================================================================
# Get trigger statistics
# =============================================================================
get_trigger_stats() {
    if [ -f "$TRIGGER_HISTORY" ]; then
        jq -r '.stats | to_entries | sort_by(-.value) | .[] | "\(.key): \(.value)"' "$TRIGGER_HISTORY" 2>/dev/null
    else
        echo "No trigger history"
    fi
}

# =============================================================================
# Get recent triggers
# =============================================================================
get_recent_triggers() {
    local count="${1:-10}"

    if [ -f "$TRIGGER_HISTORY" ]; then
        jq -r ".history | .[-${count}:] | .[] | \"\(.timestamp) \(.service): \(.pattern)\"" "$TRIGGER_HISTORY" 2>/dev/null
    else
        echo "No trigger history"
    fi
}

# =============================================================================
# Clear old history (keep last N entries)
# =============================================================================
cleanup_history() {
    local keep="${1:-1000}"

    if [ -f "$TRIGGER_HISTORY" ]; then
        local tmp_file=$(mktemp)
        jq --argjson keep "$keep" '.history |= .[-$keep:]' "$TRIGGER_HISTORY" > "$tmp_file" 2>/dev/null
        mv "$tmp_file" "$TRIGGER_HISTORY"
    fi
}
