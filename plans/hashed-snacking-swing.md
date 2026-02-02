# Plan: Emrakul Codebase Analysis

## Task Summary
Clone `https://github.com/Infatoshi/emrakul.git` into `ai-engineering-elliot/` and produce a comprehensive Markdown analysis document explaining the entire system from first principles.

---

## Phase 1: Clone Repository

```bash
git clone https://github.com/Infatoshi/emrakul.git ai-engineering-elliot
```

---

## Phase 2: Create Analysis Document

Create `ai-engineering-elliot/ANALYSIS.md` with the following comprehensive breakdown:

### Document Structure

1. **Executive Summary** - What Emrakul does and why it exists
2. **The Problem It Solves** - Claude Code quota economics (20x multiplier)
3. **Architecture Overview** - High-level system design with ASCII diagrams
4. **Directory Structure** - Complete file tree with explanations
5. **Core Components Deep Dive**:
   - CLI (`cli.py`) - Command-line interface and argument parsing
   - Workers (`workers.py`) - External AI service adapters
   - Swarm (`swarm.py`) - Priority queue task orchestration
   - MCP Server (`mcp_server.py`) - Model Context Protocol integration
6. **Configuration System** - Hooks, prompts, and worker configs
7. **Cost Analysis** - Detailed breakdown of API costs vs Claude quota
8. **Memory & Networking** - Process management, SSH tunneling, async patterns
9. **Installation Flow** - Step-by-step setup mechanics
10. **Data Flow Diagrams** - How tasks move through the system
11. **Security Considerations** - Hook-based enforcement mechanism

---

## Key Findings from Exploration

### The Core Problem
Claude Code's native `Task` tool spawns sub-agents that consume quota at **20x the normal rate**. Heavy parallel work quickly hits rate limits, making agentic swarms economically infeasible.

### The Solution Architecture
Emrakul intercepts Claude's Task tool calls via a **PreToolUse hook** and redirects work to external AI services:

| Worker | Model | API | Best For |
|--------|-------|-----|----------|
| cursor | Opus 4.5 Thinking | Cursor API ($20k credits) | Implementation, multi-file refactors |
| codex | GPT-5.2 Codex | OpenAI API (xhigh reasoning) | Debugging, test writing |
| kimi | Kimi K2.5 | Moonshot API | Internet research |
| opencode | ZAI GLM 4.7 | xAI API ($200/month) | Quick edits |

### Key Files to Analyze

```
emrakul/
├── __init__.py          # Package init, version
├── cli.py               # Main CLI entry point (delegate, serve, status)
├── workers.py           # Worker adapters for 4 external CLIs
├── swarm.py             # Priority queue with dependency resolution
└── mcp_server.py        # FastMCP server exposing delegation tools

config/
├── claude/CLAUDE.md     # Instructions for Claude Code
├── hooks/block-task-tool.sh  # PreToolUse hook to block Task
├── codex/AGENTS.md      # Instructions for Codex workers
└── cursor/emrakul.mdc   # Cursor rules file

prompts/
├── cursor.md            # System prompt for Cursor workers
├── codex.md             # System prompt for Codex workers
├── kimi.md              # System prompt for Kimi workers
└── opencode.md          # System prompt for OpenCode workers
```

### Technical Highlights

1. **Async Process Management**: Uses `asyncio.create_subprocess_exec()` with proper timeout handling and process cleanup

2. **SSH Tunneling**: Supports remote execution on "theodolos" (GPU workstation) via SSH config

3. **Output Parsing**: Each worker has custom JSON/JSONL parsers for their specific output formats

4. **Priority Scheduling**: P0-P3 priority levels with dependency resolution before task dispatch

5. **Background Execution**: `--bg &` pattern for true shell-level parallelism with file-based result persistence

6. **Hook Enforcement**: Shell script reads stdin JSON, checks tool_name, returns deny decision with redirect instructions

---

## Verification Plan

After creating the analysis document:
1. Verify the cloned repo structure matches analysis
2. Confirm all file paths referenced exist
3. Validate code snippets against actual source

---

## Output

Final deliverable: `ai-engineering-elliot/ANALYSIS.md` - A comprehensive ~3000-4000 line Markdown document explaining every aspect of Emrakul from first principles.
