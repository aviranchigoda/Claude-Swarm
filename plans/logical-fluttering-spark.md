# Strategic Integration Plan: Emrakul -> .claude Configuration

**Generated:** 2026-02-08
**Source Repository:** `/home/ai_dev/ai-engineering-elliot` (Emrakul)
**Target Directory:** `/home/ai_dev/.claude/`
**Strategy:** High-leverage, reversible integrations with MCP amplification

---

## Executive Summary

### The 5 Highest-Leverage Integrations (Ranked by Impact)

| Rank | Integration | Impact | Effort | ROI |
|------|-------------|--------|--------|-----|
| **1** | PreToolUse Hook for Task Tool Blocking | **Critical** - 20x quota savings | Low | Extreme |
| **2** | CLAUDE.md Worker Delegation Instructions | **High** - Changes Claude's core behavior | Low | Very High |
| **3** | Emrakul CLI Integration (triggers + docs) | **High** - Natural language delegation | Medium | High |
| **4** | Worker System Prompts Library | **Medium** - Optimizes delegation quality | Low | Moderate |
| **5** | Pinecone Delegation Tracking Namespace | **Medium** - Compounding learning | Medium | Moderate |

### Core Value Proposition

Emrakul solves Claude Code's **quota economics problem**: the native Task tool burns 20x quota per sub-agent call. By integrating Emrakul's approach:

- **Immediate savings:** Block Task tool, redirect to external workers
- **Better economics:** Shift work to Cursor ($20k credits), Codex (OpenAI API), Kimi (Moonshot), OpenCode (xAI $200/mo)
- **Compounding advantage:** Track delegation patterns in Pinecone for optimization

---

## Detailed Integration Plan

### Integration 1: PreToolUse Hook for Task Tool Blocking

**IMPACT: CRITICAL - Enables 20x Quota Savings**

#### WHAT
Add a PreToolUse hook that intercepts Claude's native Task tool calls and denies them with a redirect message pointing to Emrakul delegation.

#### WHERE
- Create: `~/.claude/hooks/handlers/pre-tool.sh`
- Modify: `~/.claude/settings.json` (add PreToolUse hook registration)
- Modify: `~/.claude/hooks/router.sh` (add PreToolUse case handling)

#### FROM
- Source: `/home/ai_dev/ai-engineering-elliot/config/hooks/block-task-tool.sh`

#### HOW

**Step 1.1:** Create the PreToolUse handler
```bash
# Copy and adapt Emrakul's block script
cat > ~/.claude/hooks/handlers/pre-tool.sh << 'EOF'
#!/usr/bin/env bash
# PreToolUse Handler: Block Task tool, redirect to Emrakul
# Integration from: ai-engineering-elliot/config/hooks/block-task-tool.sh

set -euo pipefail

# Read tool call from stdin
INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Block Task tool - redirect to Emrakul
if [[ "$TOOL_NAME" == "Task" ]]; then
    cat << 'ENDJSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "QUOTA PROTECTION: Task tool burns 20x quota. Use 'emrakul delegate <worker> \"task\"' instead.\n\nWorkers available:\n- cursor: Implementation, multi-file refactors (Opus 4.5)\n- codex: Debugging, tests, tracing (GPT-5.2)\n- kimi: Internet research, docs (Kimi K2.5)\n- opencode: Quick edits, small fixes (GLM 4.7)\n\nExamples:\n  emrakul delegate cursor \"Implement JWT authentication\"\n  emrakul delegate codex \"Write tests for auth module\"\n  emrakul delegate kimi \"Research OAuth 2.0 best practices\""
  }
}
ENDJSON
    exit 0
fi

# Allow all other tools
exit 0
EOF
chmod +x ~/.claude/hooks/handlers/pre-tool.sh
```

**Step 1.2:** Update router.sh to handle PreToolUse
```bash
# Add case to router.sh's event handling
# (Insert before the default case)
```

**Step 1.3:** Register hook in settings.json
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Task",
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/handlers/pre-tool.sh"
          }
        ]
      }
    ]
  }
}
```

#### REVERSIBILITY
```bash
# To reverse:
rm ~/.claude/hooks/handlers/pre-tool.sh
# Remove PreToolUse entry from settings.json hooks
git checkout ~/.claude/settings.json  # if in git
```

#### MCP LEVERAGE
- **None directly** - This is infrastructure that enables external delegation
- **Indirectly amplifies ALL MCPs** by preserving quota for MCP tool calls

---

### Integration 2: CLAUDE.md Worker Delegation Instructions

**IMPACT: HIGH - Changes Claude's Core Behavior**

#### WHAT
Add a dedicated section to CLAUDE.md teaching Claude to use Emrakul delegation instead of the Task tool.

#### WHERE
- Modify: `~/.claude/CLAUDE.md`

#### FROM
- Source: `/home/ai_dev/ai-engineering-elliot/config/claude/CLAUDE.md`
- Source: `/home/ai_dev/ai-engineering-elliot/docs/LLM_INSTRUCTIONS.md`

#### HOW

**Step 2.1:** Add delegation section to CLAUDE.md (insert after Quick Reference table)

```markdown
---

## Worker Delegation System (Emrakul)

> **CRITICAL:** Never use Claude Code's native Task tool - it burns 20x quota.
> Use `emrakul delegate` for all work that would use sub-agents.

### Worker Selection Guide

| Worker | Model | Best For | Command |
|--------|-------|----------|---------|
| `cursor` | Opus 4.5 Thinking | Implementation, multi-file refactors | `emrakul delegate cursor "task"` |
| `codex` | GPT-5.2 Codex | Debugging, tests, call tracing | `emrakul delegate codex "task"` |
| `kimi` | Kimi K2.5 | Internet research, documentation | `emrakul delegate kimi "task"` |
| `opencode` | GLM 4.7 | Quick edits, small fixes | `emrakul delegate opencode "task"` |

### Delegation Options

```bash
emrakul delegate <worker> "task description"
  --device local|theodolos   # Where to run (default: local)
  --dir /path/to/project     # Working directory
  --files file1.py file2.py  # Context files
  --bg                       # Background mode (fire and forget)
```

### Parallel Execution

```bash
# Fire multiple tasks in parallel
emrakul delegate kimi "Research authentication methods" --bg &
emrakul delegate kimi "Research database patterns" --bg &
emrakul delegate cursor "Implement user service" --bg &

# Check all results
emrakul status all
```

### Decision Tree: When to Delegate

1. **Multi-file implementation** -> `cursor`
2. **Debugging/testing** -> `codex`
3. **Internet research** -> `kimi`
4. **Quick single-file fix** -> `opencode`
5. **Simple read/edit** -> Do it yourself (no delegation needed)
```

#### REVERSIBILITY
```bash
# CLAUDE.md is already in git (assumed)
git diff ~/.claude/CLAUDE.md  # see changes
git checkout ~/.claude/CLAUDE.md  # revert
```

#### MCP LEVERAGE
- **Serena MCP:** When Claude needs to understand code before delegating, Serena's symbol analysis helps identify WHAT to delegate
- **Greptile MCP:** Semantic code search informs WHICH worker should handle the task
- **Context7 MCP:** Documentation lookup before delegation improves task quality

---

### Integration 3: Emrakul CLI Integration (Triggers + Docs)

**IMPACT: HIGH - Natural Language Delegation**

#### WHAT
Add trigger patterns for Emrakul delegation commands and create documentation file.

#### WHERE
- Modify: `~/.claude/config/triggers.json` (add emrakul triggers)
- Create: `~/.claude/docs/EMRAKUL.md`

#### FROM
- Concepts from: `/home/ai_dev/ai-engineering-elliot/README.md`
- CLI reference: `/home/ai_dev/ai-engineering-elliot/emrakul/cli.py`

#### HOW

**Step 3.1:** Add triggers to triggers.json
```json
{
  "emrakul": [
    {
      "pattern": "^delegate to cursor|^cursor implement",
      "action": "DELEGATE_CURSOR",
      "message": "Use 'emrakul delegate cursor \"<task>\"' for implementation work. Include --files for context."
    },
    {
      "pattern": "^delegate to codex|^debug with codex",
      "action": "DELEGATE_CODEX",
      "message": "Use 'emrakul delegate codex \"<task>\"' for debugging and tests."
    },
    {
      "pattern": "^delegate to kimi|^research with kimi",
      "action": "DELEGATE_KIMI",
      "message": "Use 'emrakul delegate kimi \"<task>\"' for internet research."
    },
    {
      "pattern": "^delegate to opencode|^quick fix",
      "action": "DELEGATE_OPENCODE",
      "message": "Use 'emrakul delegate opencode \"<task>\"' for quick edits."
    },
    {
      "pattern": "^check workers|^worker status|^emrakul status",
      "action": "EMRAKUL_STATUS",
      "message": "Run 'emrakul status all' to check background task outputs."
    },
    {
      "pattern": "^parallel tasks|^batch delegate",
      "action": "EMRAKUL_BATCH",
      "message": "For parallel execution: 'emrakul delegate <worker> \"task\" --bg &' for each task, then 'emrakul status all' to check results."
    }
  ]
}
```

**Step 3.2:** Create EMRAKUL.md documentation

**Step 3.3:** Update match_trigger() in common.sh to include emrakul category

#### REVERSIBILITY
```bash
# Remove emrakul array from triggers.json
# Remove ~/.claude/docs/EMRAKUL.md
# Revert common.sh changes
```

#### MCP LEVERAGE
- **Pinecone MCP:** Store delegation history for pattern analysis
- **GitHub MCP:** Combine with PR creation - delegate implementation, then create PR

---

### Integration 4: Worker System Prompts Library

**IMPACT: MEDIUM - Optimizes Delegation Quality**

#### WHAT
Import Emrakul's worker-specific system prompts that optimize each AI model's output.

#### WHERE
- Create: `~/.claude/prompts/` directory
- Create: `~/.claude/prompts/cursor.md`
- Create: `~/.claude/prompts/codex.md`
- Create: `~/.claude/prompts/kimi.md`
- Create: `~/.claude/prompts/opencode.md`

#### FROM
- Source: `/home/ai_dev/ai-engineering-elliot/prompts/cursor.md`
- Source: `/home/ai_dev/ai-engineering-elliot/prompts/codex.md`
- Source: `/home/ai_dev/ai-engineering-elliot/prompts/kimi.md`
- Source: `/home/ai_dev/ai-engineering-elliot/prompts/opencode.md`

#### HOW

```bash
mkdir -p ~/.claude/prompts
cp /home/ai_dev/ai-engineering-elliot/prompts/*.md ~/.claude/prompts/
```

#### REVERSIBILITY
```bash
rm -rf ~/.claude/prompts/
```

#### MCP LEVERAGE
- **None needed** - These are static files used by Emrakul CLI

---

### Integration 5: Pinecone Delegation Tracking Namespace

**IMPACT: MEDIUM - Compounding Learning Advantage**

#### WHAT
Add a new Pinecone namespace for tracking delegation patterns, outcomes, and optimization.

#### WHERE
- Modify: `~/.claude/config/master.json` (add namespace)
- Modify: `~/.claude/docs/PINECONE.md` (document namespace)
- Create: State tracking in hooks

#### FROM
- Concept inspired by Emrakul's output persistence pattern
- Schema designed for optimization

#### HOW

**Step 5.1:** Add namespace to master.json
```json
{
  "mcp_servers": {
    "pinecone": {
      "namespaces": [
        "sessions",
        "blueprints",
        "architecture",
        "todos",
        "decisions",
        "delegations"  // NEW
      ]
    }
  }
}
```

**Step 5.2:** Define delegation record schema
```json
{
  "_id": "delegation-{timestamp}",
  "worker": "cursor|codex|kimi|opencode",
  "task": "task description",
  "project": "/path/to/project",
  "success": true|false,
  "duration_seconds": 120,
  "complexity": "simple|moderate|complex",
  "timestamp": "2026-02-08T10:00:00Z"
}
```

**Step 5.3:** Add triggers for delegation search
```json
{
  "pattern": "^search delegations|^delegation history",
  "action": "SEARCH_DELEGATIONS",
  "message": "Search Pinecone 'delegations' namespace for past delegation patterns and outcomes."
}
```

#### REVERSIBILITY
```bash
# Remove 'delegations' from namespace list in master.json
# Remove delegation triggers from triggers.json
# Note: Pinecone data persists but is just ignored
```

#### MCP LEVERAGE
- **Pinecone MCP (PRIMARY):** This IS the Pinecone integration
- **Serena MCP:** Combine with code analysis to recommend optimal worker
- **Greptile MCP:** Semantic task understanding improves delegation records

---

## Game Theory Analysis

### Compounding Advantages

| Integration | Immediate Value | Compounding Value | Lock-in Effect |
|-------------|-----------------|-------------------|----------------|
| PreToolUse Hook | 20x quota savings | Enforces behavior change | Medium - easy to remove |
| CLAUDE.md Instructions | Teaches delegation | Claude learns preferences | Low - just documentation |
| Triggers + Docs | Natural language access | Usage patterns emerge | Medium - habit forming |
| System Prompts | Better worker output | Optimized for tasks | Low - optional use |
| Pinecone Tracking | History visibility | **Learns optimal routing** | **High - data accumulates** |

### Synergy Matrix: MCP Combinations

| Primary MCP | Combined With | Emergent Capability |
|-------------|---------------|---------------------|
| **Serena** | Emrakul delegation | Understand code structure -> delegate precisely |
| **Greptile** | Emrakul delegation | Semantic search -> identify what to delegate |
| **Pinecone** | Delegation tracking | Build optimization dataset over time |
| **Context7** | Pre-delegation research | Better task specifications for workers |
| **GitHub** | Post-delegation | Create PRs from worker output |

### Optimal Implementation Order (Dependency Graph)

```
[1] PreToolUse Hook ──┐
                      ├──> [3] Triggers + Docs ──> [5] Pinecone Tracking
[2] CLAUDE.md ────────┘

[4] System Prompts (independent, can be done anytime)
```

**Reasoning:**
1. **Hook first** - Must block Task tool before teaching alternative
2. **CLAUDE.md second** - Teaches the alternative behavior
3. **Triggers third** - Depends on understanding delegation (from CLAUDE.md)
4. **Prompts anytime** - No dependencies, just file copies
5. **Pinecone tracking last** - Requires delegation to be working first

### Decision: What NOT to Integrate

| Emrakul Component | Decision | Reason |
|-------------------|----------|--------|
| MCP Server mode | **Skip** | .claude already has 7 MCPs; CLI is simpler |
| Swarm scheduler | **Skip for now** | Over-engineering for typical use |
| SSH remote (theodolos) | **Skip** | Hardware-specific, not generalizable |
| Redis integration | **Skip** | Unused in Emrakul, future feature |

---

## Implementation Script

### Prerequisites
```bash
# Verify Emrakul is installed and accessible
which emrakul || echo "ERROR: Install Emrakul first with: cd /home/ai_dev/ai-engineering-elliot && ./install.sh"

# Verify jq is available (required for hooks)
which jq || sudo apt-get install -y jq
```

### Phase 0: Create Safety Branch
```bash
# Create backup branch for all changes
cd ~/.claude
git status || git init  # Initialize if not a repo
git checkout -b pre-emrakul-integration-backup-$(date +%Y%m%d-%H%M%S)
git add -A && git commit -m "Backup before Emrakul integration" || true
git checkout -b emrakul-integration
```

### Phase 1: PreToolUse Hook (Integration 1)
```bash
# Step 1.1: Create the handler
cat > ~/.claude/hooks/handlers/pre-tool.sh << 'HOOKEOF'
#!/usr/bin/env bash
# PreToolUse Handler: Block Task tool, redirect to Emrakul
set -euo pipefail

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')

if [[ "$TOOL_NAME" == "Task" ]]; then
    cat << 'ENDJSON'
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "QUOTA PROTECTION: Task tool burns 20x quota. Use 'emrakul delegate <worker> \"task\"' instead.\n\nWorkers:\n- cursor: Implementation (Opus 4.5)\n- codex: Debug/tests (GPT-5.2)\n- kimi: Research (Kimi K2.5)\n- opencode: Quick fixes (GLM 4.7)\n\nExample: emrakul delegate cursor \"Implement feature X\""
  }
}
ENDJSON
    exit 0
fi
exit 0
HOOKEOF
chmod +x ~/.claude/hooks/handlers/pre-tool.sh

# Step 1.2: Verify hook exists
test -x ~/.claude/hooks/handlers/pre-tool.sh && echo "PASS: pre-tool.sh created and executable"
```

### Phase 2: Update settings.json for PreToolUse
```bash
# Use jq to add PreToolUse hook (preserving existing hooks)
# NOTE: This requires careful JSON manipulation
cp ~/.claude/settings.json ~/.claude/settings.json.backup

# Add PreToolUse hook entry
jq '.hooks.PreToolUse = [{"matcher": "Task", "hooks": [{"type": "command", "command": "bash ~/.claude/hooks/handlers/pre-tool.sh"}]}]' \
  ~/.claude/settings.json > ~/.claude/settings.json.tmp && \
  mv ~/.claude/settings.json.tmp ~/.claude/settings.json

# Verify
jq '.hooks.PreToolUse' ~/.claude/settings.json && echo "PASS: PreToolUse hook registered"
```

### Phase 3: Update CLAUDE.md (Integration 2)
```bash
# Add delegation section after the Quick Reference section
# Find the line "## Session Protocols" and insert before it

cat >> ~/.claude/CLAUDE.md.addition << 'MDEOF'

---

## Worker Delegation System (Emrakul)

> **CRITICAL:** Never use Claude Code's native Task tool - it burns 20x quota.
> Use `emrakul delegate` for all sub-agent work.

### Worker Selection

| Worker | Model | Use For | Example |
|--------|-------|---------|---------|
| `cursor` | Opus 4.5 | Implementation, refactors | `emrakul delegate cursor "Add auth"` |
| `codex` | GPT-5.2 | Debugging, tests | `emrakul delegate codex "Fix bug in X"` |
| `kimi` | Kimi K2.5 | Research, docs | `emrakul delegate kimi "Research OAuth"` |
| `opencode` | GLM 4.7 | Quick edits | `emrakul delegate opencode "Fix typo"` |

### Options
- `--device local|theodolos` - Execution target
- `--files f1.py f2.py` - Context files
- `--bg` - Background mode (parallel)
- `--dir /path` - Working directory

### Parallel Execution
```bash
emrakul delegate kimi "Research A" --bg &
emrakul delegate cursor "Implement B" --bg &
emrakul status all  # Check results
```

MDEOF

# Insert before "## Session Protocols" line
# This preserves existing content
sed -i '/^## Session Protocols/r ~/.claude/CLAUDE.md.addition' ~/.claude/CLAUDE.md
rm ~/.claude/CLAUDE.md.addition

echo "PASS: CLAUDE.md updated with delegation section"
```

### Phase 4: Add Emrakul Triggers (Integration 3)
```bash
# Add emrakul triggers to triggers.json
jq '.emrakul = [
  {"pattern": "^delegate to cursor", "action": "DELEGATE_CURSOR", "message": "Use: emrakul delegate cursor \"<task>\" --files <context>"},
  {"pattern": "^delegate to codex", "action": "DELEGATE_CODEX", "message": "Use: emrakul delegate codex \"<task>\""},
  {"pattern": "^delegate to kimi", "action": "DELEGATE_KIMI", "message": "Use: emrakul delegate kimi \"<task>\""},
  {"pattern": "^delegate to opencode", "action": "DELEGATE_OPENCODE", "message": "Use: emrakul delegate opencode \"<task>\""},
  {"pattern": "^emrakul status|^check workers", "action": "EMRAKUL_STATUS", "message": "Run: emrakul status all"},
  {"pattern": "^parallel delegate|^batch tasks", "action": "EMRAKUL_BATCH", "message": "Use --bg & for parallel: emrakul delegate worker \"task\" --bg &"}
]' ~/.claude/config/triggers.json > ~/.claude/config/triggers.json.tmp && \
mv ~/.claude/config/triggers.json.tmp ~/.claude/config/triggers.json

echo "PASS: Emrakul triggers added"
```

### Phase 5: Copy System Prompts (Integration 4)
```bash
mkdir -p ~/.claude/prompts
cp /home/ai_dev/ai-engineering-elliot/prompts/cursor.md ~/.claude/prompts/
cp /home/ai_dev/ai-engineering-elliot/prompts/codex.md ~/.claude/prompts/
cp /home/ai_dev/ai-engineering-elliot/prompts/kimi.md ~/.claude/prompts/
cp /home/ai_dev/ai-engineering-elliot/prompts/opencode.md ~/.claude/prompts/

ls -la ~/.claude/prompts/ && echo "PASS: System prompts copied"
```

### Phase 6: Create Emrakul Documentation
```bash
cat > ~/.claude/docs/EMRAKUL.md << 'DOCEOF'
# Emrakul Worker Delegation

## Overview

Emrakul is a quota-saving orchestration framework. Instead of using Claude Code's native Task tool (which burns 20x quota), delegate work to external AI workers.

## Quick Reference

| Command | Worker | Model | Best For |
|---------|--------|-------|----------|
| `emrakul delegate cursor "..."` | cursor | Opus 4.5 | Implementation |
| `emrakul delegate codex "..."` | codex | GPT-5.2 | Debug/tests |
| `emrakul delegate kimi "..."` | kimi | Kimi K2.5 | Research |
| `emrakul delegate opencode "..."` | opencode | GLM 4.7 | Quick edits |

## Options

- `--device local|theodolos` - Execution target
- `--files file1.py file2.py` - Include context files
- `--bg` - Background mode (fire and forget)
- `--dir /path/to/project` - Working directory
- `--output /path/to/output.json` - Custom output location
- `--json` - JSON output format

## Status Commands

```bash
emrakul status           # Check most recent task
emrakul status all       # Check all background tasks
emrakul status <task-id> # Check specific task
```

## Parallel Execution

```bash
# Fire multiple tasks in parallel
emrakul delegate kimi "Research topic A" --bg &
emrakul delegate kimi "Research topic B" --bg &
emrakul delegate cursor "Implement feature" --bg &

# Wait and check results
emrakul status all
```

## Output Location

Background task outputs saved to: `~/.emrakul/outputs/`

## Integration with MCPs

- **Serena:** Use `find_symbol` to understand code before delegating
- **Greptile:** Use semantic search to identify what needs work
- **Pinecone:** Store delegation patterns in 'delegations' namespace
- **GitHub:** Create PRs from worker output
DOCEOF

echo "PASS: EMRAKUL.md created"
```

### Phase 7: Add Delegations Namespace to Pinecone Config (Integration 5)
```bash
jq '.mcp_servers.pinecone.namespaces += ["delegations"]' \
  ~/.claude/config/master.json > ~/.claude/config/master.json.tmp && \
  mv ~/.claude/config/master.json.tmp ~/.claude/config/master.json

# Add delegation search trigger
jq '.pinecone += [{"pattern": "^search delegations|^delegation history", "action": "SEARCH_DELEGATIONS", "message": "Search Pinecone delegations namespace for past patterns"}]' \
  ~/.claude/config/triggers.json > ~/.claude/config/triggers.json.tmp && \
  mv ~/.claude/config/triggers.json.tmp ~/.claude/config/triggers.json

echo "PASS: Delegations namespace configured"
```

### Phase 8: Update common.sh for Emrakul Triggers
```bash
# Add emrakul to the trigger matching function
# Find match_trigger function and add emrakul category

sed -i 's/for category in pinecone github/for category in pinecone github emrakul/' \
  ~/.claude/hooks/lib/common.sh

echo "PASS: common.sh updated for emrakul triggers"
```

### Phase 9: Commit Integration
```bash
cd ~/.claude
git add -A
git commit -m "Integrate Emrakul worker delegation system

Integrations:
1. PreToolUse hook blocks Task tool (20x quota savings)
2. CLAUDE.md updated with delegation instructions
3. Emrakul triggers added for natural language commands
4. Worker system prompts copied
5. Pinecone delegations namespace configured

Reversibility: git checkout pre-emrakul-integration-backup-*"
```

### Phase 10: Validation
```bash
echo "=== VALIDATION CHECKLIST ==="

# Check 1: PreToolUse hook exists and is executable
test -x ~/.claude/hooks/handlers/pre-tool.sh && echo "[OK] PreToolUse handler exists" || echo "[FAIL] PreToolUse handler missing"

# Check 2: settings.json has PreToolUse
jq -e '.hooks.PreToolUse' ~/.claude/settings.json > /dev/null && echo "[OK] PreToolUse registered in settings" || echo "[FAIL] PreToolUse not in settings"

# Check 3: CLAUDE.md has delegation section
grep -q "Worker Delegation System" ~/.claude/CLAUDE.md && echo "[OK] CLAUDE.md has delegation section" || echo "[FAIL] Delegation section missing"

# Check 4: Triggers include emrakul
jq -e '.emrakul' ~/.claude/config/triggers.json > /dev/null && echo "[OK] Emrakul triggers exist" || echo "[FAIL] Emrakul triggers missing"

# Check 5: Prompts directory has files
test -f ~/.claude/prompts/cursor.md && echo "[OK] System prompts exist" || echo "[FAIL] System prompts missing"

# Check 6: Emrakul docs exist
test -f ~/.claude/docs/EMRAKUL.md && echo "[OK] EMRAKUL.md exists" || echo "[FAIL] EMRAKUL.md missing"

# Check 7: Delegations namespace configured
jq -e '.mcp_servers.pinecone.namespaces | index("delegations")' ~/.claude/config/master.json > /dev/null && echo "[OK] Delegations namespace configured" || echo "[FAIL] Delegations namespace missing"

# Check 8: Emrakul CLI accessible
which emrakul && echo "[OK] Emrakul CLI in PATH" || echo "[WARN] Emrakul CLI not in PATH - run install.sh"

echo "=== VALIDATION COMPLETE ==="
```

### Rollback Procedure (If Needed)
```bash
cd ~/.claude
git log --oneline -5  # Find the backup commit
git checkout pre-emrakul-integration-backup-*  # Switch to backup branch

# Or selective rollback:
rm ~/.claude/hooks/handlers/pre-tool.sh
rm -rf ~/.claude/prompts/
rm ~/.claude/docs/EMRAKUL.md
git checkout settings.json CLAUDE.md config/triggers.json config/master.json hooks/lib/common.sh
```

---

## Post-Integration Testing

### Test 1: Verify Task Tool is Blocked
In a new Claude Code session, attempt to use the Task tool. Expected behavior: Hook denies with redirect message.

### Test 2: Verify Delegation Works
```bash
emrakul delegate opencode "Create a hello world Python script" --dir /tmp
cat ~/.emrakul/outputs/*.json | jq .
```

### Test 3: Verify Triggers Work
Say "delegate to cursor implement a factorial function" - should see trigger message.

### Test 4: Verify Parallel Execution
```bash
emrakul delegate kimi "What is Python" --bg &
emrakul delegate kimi "What is JavaScript" --bg &
sleep 30
emrakul status all
```

---

## Summary

This integration brings Emrakul's quota-saving architecture into the existing .claude configuration system:

1. **Immediate impact:** Task tool blocked, 20x quota saved
2. **Behavioral change:** CLAUDE.md teaches delegation patterns
3. **UX improvement:** Natural language triggers for delegation
4. **Quality improvement:** Optimized worker prompts
5. **Long-term optimization:** Pinecone tracking enables learning

All changes are reversible via git, and each integration is independently testable.
