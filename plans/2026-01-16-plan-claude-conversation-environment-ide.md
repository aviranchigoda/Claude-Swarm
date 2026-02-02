# Plan: Claude Conversation Environment Identifier Script

## Goal
Create a portable script to identify which Claude Code conversations were created on macOS (Desktop) vs Linux, running locally on each machine for maximum privacy.

## Approach
Write a single Python script that:
1. Scans `~/.claude/projects/` for conversation files (`.jsonl`)
2. Extracts metadata: session ID, timestamp, working directory (`cwd`)
3. Determines platform from the `cwd` path pattern:
   - `/Users/...` → macOS
   - `/home/...` → Linux
4. Outputs a clean summary report

## Key Files
- **Input**: `~/.claude/projects/*/*.jsonl` (conversation files)
- **Output**: Summary to stdout (no files written, maximum privacy)

## Script Features
- Single file, no dependencies beyond Python 3 standard library
- Works identically on macOS and Linux
- Reads only, never modifies conversation data
- Outputs: conversation ID, date created, platform detected, working directory

## Output Format
```
CONVERSATION SUMMARY
====================
ID: 6d39b362-7eab-40a7-a927-90fcfc78ec4c
Date: 2025-01-14 10:30:45
Platform: macOS
Directory: /Users/aviranchigoda/Desktop
---
```

## Implementation Steps
1. Create `claude-conversations.py` script
2. Parse JSONL files to extract first message with `cwd` and `timestamp`
3. Classify platform based on path prefix
4. Format and print summary

## Verification
- Run script on this Mac: `python3 claude-conversations.py`
- Copy script to Linux machine and run there
- Compare outputs to see which conversations originated where

## Privacy Benefits
- No data leaves either machine
- No sync services involved
- Script outputs summary only (not conversation content)
- Can delete script after use
