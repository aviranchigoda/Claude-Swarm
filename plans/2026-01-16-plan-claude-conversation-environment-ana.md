# Plan: Claude Conversation Environment Analyzer Script

## Goal
Create a cross-platform script that analyzes Claude Code conversations and identifies which environment they were created on.

## Key Findings from Research
- Conversations stored in: `~/.claude/projects/<project-path>/*.jsonl`
- Each conversation file contains JSONL with metadata including:
  - `cwd`: working directory (can infer platform: `/Users/...` = macOS, `/home/...` = Linux)
  - `sessionId`: unique conversation identifier
  - `timestamp`: when created
  - `version`: Claude Code version
  - First user message content

## Implementation

### Script: `claude-conversation-analyzer.py`

**Features:**
1. Auto-detect current platform (`darwin`/`linux`)
2. Scan `~/.claude/projects/` for all `.jsonl` conversation files
3. Parse each conversation and extract:
   - Session ID
   - First timestamp
   - Working directory (`cwd`)
   - First user message (truncated preview)
   - Inferred platform from path pattern
4. Output summary table showing:
   - Conversation count by inferred platform
   - List of all conversations with metadata
5. Optional JSON export for combining results from multiple machines

**Platform Detection Logic:**
- `/Users/` prefix → macOS (darwin)
- `/home/` prefix → Linux
- Other → Unknown

**Output Formats:**
- Human-readable table (default)
- JSON export (`--json`) for programmatic use or merging data from both machines

### Usage
```bash
# Run on macOS desktop
python3 claude-conversation-analyzer.py

# Run on Linux machine
python3 claude-conversation-analyzer.py

# Export JSON for later comparison
python3 claude-conversation-analyzer.py --json > conversations.json
```

## Files to Create
1. `~/Desktop/claude-conversation-analyzer.py` - Main script

## Verification
- Run script on current macOS machine
- Confirm it lists conversations with correct metadata
- Verify platform inference works for paths
