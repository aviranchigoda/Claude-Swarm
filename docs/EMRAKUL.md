# Emrakul Worker Delegation

## Overview

Emrakul is a quota-saving orchestration framework. Instead of using Claude Code's native Task tool (which burns **20x quota** per sub-agent call), delegate work to external AI workers that operate on separate billing.

Named after the Eldrazi titan from Magic: The Gathering, Emrakul positions Claude as an **orchestrator** rather than an implementer.

## Quick Reference

| Command | Worker | Model | Best For |
|---------|--------|-------|----------|
| `emrakul delegate cursor "..."` | cursor | Opus 4.5 Thinking | Implementation, multi-file refactors |
| `emrakul delegate codex "..."` | codex | GPT-5.2 Codex | Debugging, tests, call tracing |
| `emrakul delegate kimi "..."` | kimi | Kimi K2.5 | Internet research, documentation |
| `emrakul delegate opencode "..."` | opencode | GLM 4.7 | Quick edits, small fixes |

## Workers

### Cursor (Primary Implementation)
- **Model:** Opus 4.5 Thinking
- **Billing:** Cursor credits ($20k)
- **Use for:** Multi-file implementations, refactors, complex features
- **Timeout:** None (no limit for complex work)

### Codex (Debugging/Testing)
- **Model:** GPT-5.2 Codex
- **Billing:** OpenAI API
- **Use for:** Debugging, writing tests, recursive call tracing
- **Timeout:** 600s (10 min)

### Kimi (Research)
- **Model:** Kimi K2.5
- **Billing:** Moonshot API
- **Use for:** Internet research, documentation lookup
- **Timeout:** 300s (5 min)
- **Note:** Does not accept context files

### OpenCode (Quick Edits)
- **Model:** GLM 4.7
- **Billing:** xAI API ($200/mo)
- **Use for:** Quick single-file edits, small fixes
- **Timeout:** 180s (3 min)

## CLI Options

```bash
emrakul delegate <worker> "task description"
  --device local|theodolos   # Execution target (default: local)
  --dir /path/to/project     # Working directory
  --files file1.py file2.py  # Context files (cursor/codex/opencode)
  --bg                       # Background mode (fire and forget)
  --output /path/to/out.json # Custom output location
  --json                     # JSON output format
```

## Status Commands

```bash
emrakul status           # Check most recent task
emrakul status all       # Check all background tasks
emrakul status <task-id> # Check specific task
```

## Parallel Execution

For tasks that can run concurrently, use background mode:

```bash
# Fire multiple tasks in parallel
emrakul delegate kimi "Research topic A" --bg &
emrakul delegate kimi "Research topic B" --bg &
emrakul delegate cursor "Implement feature" --bg &

# Wait for completion and check results
emrakul status all
```

## Output Location

Background task outputs are saved to: `~/.emrakul/outputs/`

Each task gets a unique ID in the format: `{worker}-{uuid}.json`

## Decision Tree

When to delegate vs do it yourself:

1. **Multi-file implementation** -> `cursor`
2. **Debugging complex issues** -> `codex`
3. **Need internet research** -> `kimi`
4. **Quick single-file fix** -> `opencode`
5. **Simple read/edit operation** -> Do it yourself (no delegation needed)
6. **Need to understand code** -> Use Serena MCP first, then delegate

## Integration with MCPs

Emrakul works well with other MCP servers:

- **Serena:** Use `find_symbol` to understand code before delegating
- **Greptile:** Use semantic search to identify what needs work
- **Pinecone:** Store delegation patterns in 'delegations' namespace
- **GitHub:** Create PRs from worker output
- **Context7:** Research library docs before delegating implementation

## Example Workflows

### Implement a Feature

```bash
# 1. Research the approach
emrakul delegate kimi "Research JWT authentication best practices for Python"

# 2. Implement the feature
emrakul delegate cursor "Implement JWT authentication using the python-jose library" --files auth.py config.py

# 3. Write tests
emrakul delegate codex "Write comprehensive tests for the JWT auth module" --files auth.py tests/
```

### Debug an Issue

```bash
# 1. Trace the issue
emrakul delegate codex "Trace the recursive calls in process_data() to find the infinite loop" --files processor.py

# 2. Apply the fix
emrakul delegate opencode "Fix the base case in process_data() recursive function" --files processor.py
```

### Parallel Research

```bash
# Fire all research tasks at once
emrakul delegate kimi "Research OAuth 2.0 implementation patterns" --bg &
emrakul delegate kimi "Research secure token storage methods" --bg &
emrakul delegate kimi "Research session management best practices" --bg &

# Check results
emrakul status all
```

## System Prompts

Worker-specific system prompts are stored in `~/.claude/prompts/`:

- `cursor.md` - Multi-file implementation specialist
- `codex.md` - Debugging and testing specialist
- `kimi.md` - Research specialist
- `opencode.md` - Quick edit specialist

These prompts optimize each worker's output for their specific use case.

## Troubleshooting

**Worker not responding?**
- Check if the CLI is installed: `which emrakul`
- Verify authentication for the specific worker

**Task timing out?**
- Cursor has no timeout (complex work)
- Other workers: codex 600s, kimi 300s, opencode 180s
- Consider breaking into smaller tasks

**Output not found?**
- Check `~/.emrakul/outputs/` directory
- Use `emrakul status <task-id>` to get specific output

## Source

Integrated from: `/home/ai_dev/ai-engineering-elliot` (Emrakul repository)

See also: [ANALYSIS.md](/home/ai_dev/ai-engineering-elliot/ANALYSIS.md) for comprehensive technical details.
