#!/bin/bash
# =============================================================================
# common.sh - Shared utilities for the unified Claude hook system
# =============================================================================

# Directories
export CLAUDE_DIR="$HOME/.claude"
export CONFIG_DIR="$CLAUDE_DIR/config"
export STATE_DIR="$CLAUDE_DIR/state"
export HOOKS_DIR="$CLAUDE_DIR/hooks"
export DOCS_DIR="$CLAUDE_DIR/docs"

# Config files
export TRIGGERS_FILE="$CONFIG_DIR/triggers.json"
export PERMISSIONS_FILE="$CONFIG_DIR/permissions.json"
export MASTER_CONFIG="$CONFIG_DIR/master.json"

# State files
export SESSION_FILE="$STATE_DIR/session.json"
export TRIGGER_HISTORY="$STATE_DIR/trigger-history.json"
export AUDIT_LOG="$STATE_DIR/audit.jsonl"

# =============================================================================
# Emit system message to Claude
# =============================================================================
emit() {
    local icon="$1"
    local msg="$2"
    echo "{\"systemMessage\": \"$icon $msg\"}"
}

# =============================================================================
# Log action to audit file
# =============================================================================
log_action() {
    local action="$1"
    local details="$2"
    local timestamp=$(date -Iseconds)

    # Ensure state directory exists
    mkdir -p "$STATE_DIR"

    # Append to audit log
    echo "{\"timestamp\":\"$timestamp\",\"action\":\"$action\",\"details\":\"$details\"}" >> "$AUDIT_LOG"
}

# =============================================================================
# Get trigger count for a service
# =============================================================================
get_trigger_count() {
    local service="$1"
    jq -r ".${service} | length // 0" "$TRIGGERS_FILE" 2>/dev/null || echo "0"
}

# =============================================================================
# Get trigger pattern at index
# =============================================================================
get_trigger_pattern() {
    local service="$1"
    local index="$2"
    jq -r ".${service}[$index].pattern // empty" "$TRIGGERS_FILE" 2>/dev/null
}

# =============================================================================
# Get trigger message at index
# =============================================================================
get_trigger_message() {
    local service="$1"
    local index="$2"
    jq -r ".${service}[$index].message // .${service}[$index].action // empty" "$TRIGGERS_FILE" 2>/dev/null
}

# =============================================================================
# Match input against all triggers and emit system message if matched
# Returns 0 if matched, 1 if no match
# =============================================================================
match_trigger() {
    local input="$1"
    local services=("pinecone" "github" "greptile" "serena" "context7" "firebase" "supabase" "image" "composite")

    for service in "${services[@]}"; do
        local count=$(get_trigger_count "$service")

        for ((i=0; i<count; i++)); do
            local pattern=$(get_trigger_pattern "$service" "$i")
            local message=$(get_trigger_message "$service" "$i")

            if [ -n "$pattern" ] && echo "$input" | grep -qiE "$pattern"; then
                # Emit the system message
                emit "⚡" "${service^^}: $message"

                # Track the trigger (non-blocking)
                track_trigger "$service" "$pattern" &

                # Log the action
                log_action "TRIGGER_MATCHED" "$service:$pattern"

                return 0
            fi
        done
    done

    return 1
}

# =============================================================================
# Track trigger usage in history
# =============================================================================
track_trigger() {
    local service="$1"
    local pattern="$2"
    local timestamp=$(date -Iseconds)

    # Ensure state directory exists
    mkdir -p "$STATE_DIR"

    # Initialize trigger history if it doesn't exist
    if [ ! -f "$TRIGGER_HISTORY" ]; then
        echo '{"history":[],"stats":{}}' > "$TRIGGER_HISTORY"
    fi

    # Add to history and update stats
    local tmp_file=$(mktemp)
    jq --arg service "$service" \
       --arg pattern "$pattern" \
       --arg timestamp "$timestamp" \
       '.history += [{"service": $service, "pattern": $pattern, "timestamp": $timestamp}] |
        .stats[$service] = ((.stats[$service] // 0) + 1)' \
       "$TRIGGER_HISTORY" > "$tmp_file" 2>/dev/null && mv "$tmp_file" "$TRIGGER_HISTORY"
}

# =============================================================================
# Get current session ID
# =============================================================================
get_session_id() {
    if [ -f "$SESSION_FILE" ]; then
        jq -r '.id // empty' "$SESSION_FILE" 2>/dev/null
    fi
}

# =============================================================================
# Rename plan file from random name to dated name
# =============================================================================
rename_plan_file() {
    local file="$1"
    local dir=$(dirname "$file")
    local date_prefix=$(date +%Y-%m-%d-%H%M)

    # Extract first heading for description
    local desc=$(grep -m1 "^#" "$file" 2>/dev/null | \
                 sed 's/^#* *//' | \
                 tr '[:upper:]' '[:lower:]' | \
                 tr ' ' '-' | \
                 tr -cd '[:alnum:]-' | \
                 cut -c1-40)

    if [ -z "$desc" ]; then
        desc="plan"
    fi

    local new_name="${dir}/${date_prefix}-${desc}.md"

    # Only rename if file still exists and new name is different
    if [ -f "$file" ] && [ "$file" != "$new_name" ]; then
        mv "$file" "$new_name" 2>/dev/null
        log_action "PLAN_RENAMED" "$file -> $new_name"
    fi
}

# =============================================================================
# Check if config is valid
# =============================================================================
validate_config() {
    local errors=0

    if [ ! -f "$TRIGGERS_FILE" ]; then
        echo "ERROR: triggers.json not found" >&2
        ((errors++))
    fi

    if [ ! -f "$MASTER_CONFIG" ]; then
        echo "ERROR: master.json not found" >&2
        ((errors++))
    fi

    # Validate JSON syntax
    if [ -f "$TRIGGERS_FILE" ] && ! jq empty "$TRIGGERS_FILE" 2>/dev/null; then
        echo "ERROR: triggers.json has invalid JSON" >&2
        ((errors++))
    fi

    return $errors
}
