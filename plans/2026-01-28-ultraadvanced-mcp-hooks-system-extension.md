# Ultra-Advanced MCP + Hooks System Extension Plan

## Executive Summary

This plan extends the existing CLAUDE-CODE-MCP-HOOKS-SYSTEM.md with an extremely powerful, modular hook architecture providing:

- **150+ new trigger phrases** across all 7 MCP servers
- **Per-server markdown documentation files** with complete tool reference
- **Multi-layer hook architecture** with context passing and state machines
- **Composite workflows** orchestrating multiple MCPs simultaneously
- **Safety gates** with PreToolUse protection patterns
- **Session intelligence** with automatic context detection

---

## Part 1: Advanced Hook Architecture

### 1.1 Multi-Layer Hook System

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          HOOK EXECUTION LAYERS                               │
├─────────────────────────────────────────────────────────────────────────────┤
│ Layer 1: INTENT DETECTION        (UserPromptSubmit)                          │
│ ├── mcp-router.sh                → Detect trigger phrases, route to MCP      │
│ ├── context-detector.sh          → Detect project context, inject hints      │
│ └── safety-validator.sh          → Pre-validate dangerous patterns           │
├─────────────────────────────────────────────────────────────────────────────┤
│ Layer 2: TOOL GATES              (PreToolUse)                                │
│ ├── production-guard.sh          → Block production-destructive operations   │
│ ├── rate-limiter.sh              → Prevent API abuse                         │
│ ├── branch-enforcer.sh           → Enforce git branch policies               │
│ └── cost-guardian.sh             → Block expensive MCP operations            │
├─────────────────────────────────────────────────────────────────────────────┤
│ Layer 3: POST-PROCESSING         (PostToolUse)                               │
│ ├── result-enhancer.sh           → Augment MCP results with context          │
│ ├── audit-logger.sh              → Log all tool executions                   │
│ ├── auto-formatter.sh            → Format code after edits                   │
│ └── pinecone-auto-index.sh       → Auto-index important outputs              │
├─────────────────────────────────────────────────────────────────────────────┤
│ Layer 4: SESSION LIFECYCLE       (Stop/SessionStart)                         │
│ ├── session-start-hook.sh        → Load context from Pinecone                │
│ ├── session-end-reminder.sh      → Remind to save context                    │
│ └── session-summary-gen.sh       → Auto-generate session summary             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 State Management System

**State File Structure:**
```
~/.claude/
├── hook-state/
│   ├── session.json              # Current session metadata
│   ├── mcp-usage.json            # MCP usage counters & rate limits
│   ├── active-workflows.json     # In-progress multi-step workflows
│   ├── tool-history.json         # Recent tool executions (ring buffer)
│   └── context-cache.json        # Cached context from Pinecone
```

### 1.3 Context Passing Between Hooks

**Environment Variables Injected:**
```bash
CLAUDE_SESSION_ID       # Unique session identifier
CLAUDE_PROJECT_ROOT     # Current project directory
CLAUDE_GIT_BRANCH       # Current git branch
CLAUDE_LAST_TOOL        # Last tool executed
CLAUDE_WORKFLOW_ID      # Active composite workflow ID
CLAUDE_USER_INTENT      # Detected user intent category
```

---

## Part 2: Per-MCP Server Documentation & Hooks

### 2.1 File Structure

```
~/workspace/
├── CLAUDE.md/
│   ├── index.md                      # Master index linking all docs
│   ├── PINECONE-ADVANCED.md          # Complete Pinecone reference
│   ├── GITHUB-ADVANCED.md            # Complete GitHub reference
│   ├── GREPTILE-ADVANCED.md          # Complete Greptile reference
│   ├── SERENA-ADVANCED.md            # Complete Serena reference
│   ├── CONTEXT7-ADVANCED.md          # Complete Context7 reference
│   ├── FIREBASE-ADVANCED.md          # Complete Firebase reference
│   ├── SUPABASE-ADVANCED.md          # Complete Supabase reference
│   ├── COMPOSITE-WORKFLOWS.md        # Multi-MCP orchestration
│   └── HOOK-REFERENCE.md             # Complete hook system reference
```

---

## Part 3: Pinecone Advanced Configuration

### 3.1 New Pinecone Triggers (25 total)

| Trigger | Action | Use Case |
|---------|--------|----------|
| `semantic search: X` | Advanced search with reranking | Deep knowledge retrieval |
| `find similar to: X` | Cosine similarity search | Pattern discovery |
| `index this code` | Auto-index current file | Build code knowledge base |
| `index this file` | Index any file to namespace | Persistent file storage |
| `cascade search: X` | Multi-namespace search | Cross-domain queries |
| `what do you know about X` | Intelligent context query | Context retrieval |
| `remember this: X` | Quick upsert to memory | Fast note-taking |
| `forget X` | Delete specific vector | Memory management |
| `knowledge stats` | Full index statistics | Index health check |
| `rebuild index` | Reindex from sources | Index maintenance |
| `list namespaces` | Show all namespaces | Namespace discovery |
| `search with filter: X` | Filtered semantic search | Precise retrieval |
| `rerank results: X` | Apply reranker to results | Result refinement |
| `export knowledge` | Dump index to markdown | Backup/export |
| `import knowledge` | Load from markdown | Restore/import |
| `show recent memories` | Last N upserted vectors | Activity tracking |
| `search code patterns` | Code-specific search | Code knowledge |
| `search decisions` | ADR-specific search | Architecture context |
| `search sessions` | Session-specific search | History context |
| `search blueprints` | Blueprint-specific search | Documentation context |
| `add to context: X` | Build context window | Context building |
| `clear context cache` | Reset cached context | Cache management |
| `auto-index mode on/off` | Toggle auto-indexing | Workflow control |
| `knowledge health check` | Validate index integrity | Maintenance |
| `migrate namespace X to Y` | Namespace migration | Data management |

### 3.2 Pinecone Advanced Workflows

**Auto-Index Pipeline:**
```
PostToolUse (Edit|Write) → Extract code metadata → Generate embedding → Upsert to code-docs namespace
```

**Intelligent Context Loading:**
```
SessionStart → Query recent sessions → Query active todos → Query relevant blueprints → Inject as systemMessage
```

**Cascading Search:**
```
User: "cascade search: order book implementation"
→ Search blueprints (topK=5)
→ Search architecture (topK=3)
→ Search code-docs (topK=5)
→ Rerank combined results
→ Return unified response
```

---

## Part 4: GitHub Advanced Configuration

### 4.1 New GitHub Triggers (30 total)

| Trigger | Action | Use Case |
|---------|--------|----------|
| `pr status` | Get PR status for current branch | Quick PR check |
| `my prs` | List user's open PRs | Personal PR dashboard |
| `my issues` | List issues assigned to user | Task tracking |
| `review requested` | PRs awaiting your review | Review queue |
| `draft pr` | Create draft PR | WIP sharing |
| `ready for review` | Convert draft to ready | PR workflow |
| `request review from: X` | Add reviewers | Review management |
| `merge pr` | Merge current branch PR | Workflow completion |
| `squash merge` | Squash and merge PR | Clean history |
| `rebase merge` | Rebase and merge PR | Linear history |
| `close pr` | Close without merge | Abort PR |
| `pr diff` | Show PR diff | Review prep |
| `pr files` | List changed files | Impact assessment |
| `pr comments` | Show PR comments | Discussion view |
| `add pr comment: X` | Add comment to PR | Communication |
| `approve pr` | Submit approval | Review completion |
| `request changes: X` | Request changes | Review feedback |
| `copilot review` | Request AI review | Automated review |
| `assign copilot to: X` | Assign Copilot to issue | AI task handling |
| `create branch: X` | Create new branch | Workflow start |
| `delete branch: X` | Delete branch | Cleanup |
| `sync branch` | Update PR branch with base | Merge conflict prevention |
| `search code: X` | Global code search | Pattern finding |
| `search repos: X` | Repository search | Discovery |
| `repo stats` | Repository statistics | Health check |
| `recent commits` | Last N commits | History view |
| `commit by: X` | Commits by author | Attribution |
| `file history: X` | Git log for file | Change tracking |
| `create release: X` | Create new release | Deployment prep |
| `latest release` | Get latest release info | Version check |

### 4.2 GitHub Advanced Workflows

**Smart PR Creation:**
```
User: "create pr"
→ Detect current branch
→ Get diff from main
→ Generate PR description from commits
→ Search for PR template
→ Create PR with template + generated content
→ Auto-request reviewers based on CODEOWNERS
```

**Issue Triage Automation:**
```
User: "triage issue #123"
→ Get issue details
→ Analyze labels, description
→ Search codebase for related files (via Greptile)
→ Suggest assignee based on file ownership
→ Add appropriate labels
```

---

## Part 5: Greptile Advanced Configuration

### 5.1 New Greptile Triggers (20 total)

| Trigger | Action | Use Case |
|---------|--------|----------|
| `analyze pr #N` | Deep PR analysis | Pre-review prep |
| `pr risk assessment` | Security/quality scan | Risk identification |
| `find tech debt` | Locate code quality issues | Maintenance planning |
| `security audit` | Security-focused review | Vulnerability detection |
| `performance review` | Performance analysis | Optimization targets |
| `find dead code` | Unused code detection | Cleanup targets |
| `dependency analysis` | Dependency graph | Impact assessment |
| `find duplicates` | Duplicate code detection | DRY violations |
| `code complexity` | Complexity metrics | Refactoring targets |
| `test coverage gaps` | Missing test coverage | Quality improvement |
| `api surface` | Public API analysis | Interface documentation |
| `breaking changes` | Detect breaking changes | Versioning support |
| `migration impact` | Database migration review | Schema change safety |
| `greptile patterns` | Custom pattern search | Pattern enforcement |
| `add pattern: X` | Create custom context | Standard enforcement |
| `list patterns` | Show custom contexts | Pattern inventory |
| `pattern violations` | Find pattern violations | Compliance check |
| `review history` | Past review comments | Learning from feedback |
| `addressed comments` | Resolved review items | Progress tracking |
| `unaddressed comments` | Open review items | Action items |

### 5.2 Greptile Advanced Workflows

**Comprehensive PR Review:**
```
User: "full pr review #123"
→ Get PR diff
→ Run security analysis
→ Run performance analysis
→ Check custom patterns
→ Generate consolidated review
→ Create pending review with comments
```

**Custom Pattern Enforcement:**
```
User: "add pattern: no console.log in production"
→ Create custom context with scope
→ Set pattern regex
→ Configure action (warn/block)
→ Confirm creation
```

---

## Part 6: Serena Advanced Configuration

### 6.1 New Serena Triggers (25 total)

| Trigger | Action | Use Case |
|---------|--------|----------|
| `symbols in: X` | Get file symbols | Code navigation |
| `find class: X` | Search for class | Discovery |
| `find function: X` | Search for function | Discovery |
| `find method: X` | Search for method | Discovery |
| `callers of: X` | Find references | Impact analysis |
| `callees of: X` | Find what X calls | Dependency analysis |
| `rename: X to Y` | Safe refactor rename | Refactoring |
| `move: X to Y` | Move symbol to file | Reorganization |
| `extract method: X` | Extract to method | Refactoring |
| `inline: X` | Inline symbol | Simplification |
| `delete symbol: X` | Safe symbol deletion | Cleanup |
| `add method: X to Y` | Add method to class | Extension |
| `add import: X` | Add import statement | Dependency |
| `remove import: X` | Remove unused import | Cleanup |
| `find pattern: X` | Regex search | Pattern discovery |
| `replace pattern: X with Y` | Bulk replace | Mass refactoring |
| `project structure` | Directory overview | Navigation |
| `file overview: X` | File summary | Understanding |
| `type hierarchy: X` | Inheritance tree | Architecture |
| `interface impl: X` | Implementations | Polymorphism |
| `unused symbols` | Find unused code | Cleanup |
| `circular deps` | Circular dependencies | Architecture issues |
| `symbol stats` | Codebase metrics | Health check |
| `memory note: X` | Save analysis note | Persistence |
| `recall notes` | Read saved notes | Context recall |

### 6.2 Serena Advanced Workflows

**Safe Refactoring Pipeline:**
```
User: "rename: OrderBook to OrderBookEngine"
→ Find symbol across codebase
→ Find all references
→ Preview changes
→ Confirm with user
→ Apply rename
→ Run tests
→ Commit changes
```

**Codebase Understanding:**
```
User: "explain architecture"
→ Activate project
→ Get symbols overview (depth=2)
→ Analyze module dependencies
→ Generate architecture diagram (mermaid)
→ Store in Pinecone
```

---

## Part 7: Context7 Advanced Configuration

### 7.1 New Context7 Triggers (15 total)

| Trigger | Action | Use Case |
|---------|--------|----------|
| `docs for: X` | Resolve + query docs | Documentation lookup |
| `examples of: X` | Code examples | Learning |
| `api: X` | API reference | Interface details |
| `migration guide: X` | Migration docs | Upgrade help |
| `changelog: X` | Version changes | Update tracking |
| `best practices: X` | Recommended patterns | Quality guidance |
| `troubleshooting: X` | Problem solutions | Debugging help |
| `compare: X vs Y` | Library comparison | Decision support |
| `latest version: X` | Version info | Currency check |
| `deprecated in: X` | Deprecation info | Technical debt |
| `security advisories: X` | Security info | Vulnerability awareness |
| `typescript types: X` | Type definitions | Type safety |
| `react hooks: X` | React-specific docs | Framework support |
| `node modules: X` | Node.js docs | Backend support |
| `web apis: X` | Browser API docs | Frontend support |

### 7.2 Context7 Advanced Workflows

**Smart Documentation Lookup:**
```
User: "docs for: react query"
→ Resolve library ID
→ Query multiple doc sections
→ Extract code examples
→ Format for current project context
→ Cache in Pinecone for future reference
```

---

## Part 8: Firebase Advanced Configuration

### 8.1 New Firebase Triggers (20 total)

| Trigger | Action | Use Case |
|---------|--------|----------|
| `firebase projects` | List all projects | Project discovery |
| `firebase apps` | List apps in project | App inventory |
| `firebase config` | Get SDK config | Client setup |
| `firebase rules` | Get security rules | Security audit |
| `firestore collections` | List collections | Schema discovery |
| `firestore query: X` | Query collection | Data retrieval |
| `firestore add: X` | Add document | Data creation |
| `firestore update: X` | Update document | Data modification |
| `firestore delete: X` | Delete document | Data removal |
| `firebase functions` | List functions | Function inventory |
| `firebase logs` | View function logs | Debugging |
| `firebase deploy` | Deploy services | Deployment |
| `firebase init: X` | Initialize service | Project setup |
| `rtdb query: X` | Realtime DB query | Data retrieval |
| `rtdb set: X` | Set RTDB value | Data creation |
| `firebase auth users` | List auth users | User management |
| `firebase storage` | List storage files | File inventory |
| `firebase hosting` | Hosting status | Deployment status |
| `firebase emulator` | Start emulators | Local development |
| `firebase test` | Run test suite | Quality assurance |

### 8.2 Firebase Advanced Workflows

**Full Deployment Pipeline:**
```
User: "deploy firebase"
→ Check active project
→ Validate security rules
→ Run local tests
→ Deploy functions
→ Deploy hosting
→ Verify deployment
→ Update Pinecone with deployment record
```

---

## Part 9: Supabase Advanced Configuration

### 9.1 New Supabase Triggers (25 total)

| Trigger | Action | Use Case |
|---------|--------|----------|
| `supabase projects` | List projects | Project discovery |
| `supabase tables` | List tables | Schema discovery |
| `supabase schema` | Full schema dump | Schema documentation |
| `supabase types` | Generate TS types | Type safety |
| `select from: X` | Query table | Data retrieval |
| `insert into: X` | Insert records | Data creation |
| `update: X set Y` | Update records | Data modification |
| `delete from: X` | Delete records | Data removal |
| `create table: X` | Create via migration | Schema creation |
| `alter table: X` | Modify via migration | Schema modification |
| `drop table: X` | Drop via migration | Schema deletion |
| `migration status` | List migrations | Schema history |
| `rollback migration` | Undo last migration | Schema recovery |
| `edge functions` | List edge functions | Function inventory |
| `deploy function: X` | Deploy edge function | Function deployment |
| `function logs: X` | View function logs | Debugging |
| `supabase branches` | List branches | Environment management |
| `create branch: X` | Create dev branch | Safe experimentation |
| `merge branch: X` | Merge to production | Deployment |
| `supabase advisors` | Security advisories | Security audit |
| `rls policies: X` | View RLS policies | Security review |
| `enable rls: X` | Enable RLS on table | Security hardening |
| `supabase keys` | Get API keys | Client setup |
| `supabase url` | Get project URL | Configuration |
| `supabase docs: X` | Search Supabase docs | Learning |

### 9.2 Supabase Advanced Workflows

**Schema Migration Pipeline:**
```
User: "create table: orders"
→ Generate CREATE TABLE SQL
→ Create migration file
→ Apply to dev branch first
→ Run tests
→ Merge to production
→ Generate TypeScript types
→ Update Pinecone schema docs
```

**Security Hardening:**
```
User: "security audit"
→ Get all advisories
→ Check RLS status
→ Review policies
→ Generate security report
→ Create issues for findings
```

---

## Part 10: Composite Workflows

### 10.1 Multi-MCP Orchestration Triggers

| Trigger | MCPs Used | Description |
|---------|-----------|-------------|
| `full analysis` | Serena + Greptile + Context7 + Pinecone | Complete codebase analysis |
| `deploy all` | GitHub + Firebase/Supabase + Pinecone | Full deployment pipeline |
| `daily standup` | Pinecone + GitHub + Greptile | Daily status report |
| `sprint planning` | GitHub + Pinecone + Greptile | Sprint preparation |
| `code review pipeline` | GitHub + Greptile + Serena | Comprehensive review |
| `onboard to codebase` | Serena + Greptile + Pinecone + Context7 | New developer onboarding |
| `security sweep` | Greptile + Supabase + Firebase | Full security audit |
| `performance audit` | Greptile + Serena + Pinecone | Performance analysis |
| `documentation sync` | Serena + Context7 + Pinecone | Sync docs with code |
| `release prep` | GitHub + Greptile + Pinecone | Pre-release checklist |
| `incident response` | GitHub + Supabase/Firebase + Pinecone | Debug production issue |
| `tech debt report` | Greptile + Serena + Pinecone | Debt quantification |
| `knowledge transfer` | Pinecone + Serena + Greptile | Session handoff |
| `architecture review` | Serena + Greptile + Pinecone + Context7 | Architecture assessment |
| `dependency update` | GitHub + Context7 + Greptile | Safe dependency updates |

### 10.2 Composite Workflow Implementation

**Full Analysis Workflow:**
```bash
# Workflow ID: full-analysis
# Steps executed in sequence:

1. Serena: activate_project → get_symbols_overview
2. Greptile: list_custom_context → pattern checks
3. Context7: resolve + query docs for dependencies
4. Pinecone: search blueprints + architecture
5. Generate consolidated report
6. Upsert report to Pinecone sessions
```

**Daily Standup Workflow:**
```bash
# Workflow ID: daily-standup
# Steps executed in parallel where possible:

PARALLEL:
  - Pinecone: search todos (status=active)
  - Pinecone: search sessions (last 24h)
  - GitHub: list_issues (assigned to me)
  - GitHub: list_pull_requests (author=me)
  - Greptile: unaddressed comments

SYNTHESIZE:
  - Generate standup report
  - Highlight blockers
  - List today's priorities
```

---

## Part 11: Safety Gates (PreToolUse Hooks)

### 11.1 Production Protection

```bash
# ~/.claude/hooks/production-guard.sh
# Blocks destructive operations on production resources

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.toolName')

# Supabase production protection
if [[ "$TOOL" == "mcp__supabase__execute_sql" ]]; then
  QUERY=$(echo "$INPUT" | jq -r '.query // empty')
  if echo "$QUERY" | grep -qiE "(DROP|DELETE|TRUNCATE)"; then
    PROJECT=$(echo "$INPUT" | jq -r '.project_id // empty')
    if [[ "$PROJECT" != *"-dev"* ]] && [[ "$PROJECT" != *"-staging"* ]]; then
      echo '{"decision": "block", "reason": "Destructive SQL blocked on production"}'
      exit 0
    fi
  fi
fi

# Firebase production protection
if [[ "$TOOL" == "mcp__firebase__firebase_init" ]]; then
  echo '{"decision": "warn", "message": "Initializing Firebase services - ensure correct project is selected"}'
  exit 0
fi

# GitHub main branch protection
if [[ "$TOOL" == "mcp__github__push_files" ]]; then
  BRANCH=$(echo "$INPUT" | jq -r '.branch // empty')
  if [[ "$BRANCH" == "main" ]] || [[ "$BRANCH" == "master" ]]; then
    echo '{"decision": "block", "reason": "Direct push to main/master blocked - use PR workflow"}'
    exit 0
  fi
fi

echo '{"decision": "allow"}'
```

### 11.2 Rate Limiting

```bash
# ~/.claude/hooks/rate-limiter.sh
# Prevents API abuse

USAGE_FILE=~/.claude/hook-state/mcp-usage.json
TOOL=$(cat | jq -r '.toolName')

# Initialize if needed
if [ ! -f "$USAGE_FILE" ]; then
  echo '{}' > "$USAGE_FILE"
fi

# Get current count
COUNT=$(jq -r ".[\"$TOOL\"] // 0" "$USAGE_FILE")
LIMIT=100  # Per-hour limit

if [ "$COUNT" -ge "$LIMIT" ]; then
  echo '{"decision": "block", "reason": "Rate limit exceeded for '$TOOL'"}'
  exit 0
fi

# Increment counter
jq ".[\"$TOOL\"] = ($COUNT + 1)" "$USAGE_FILE" > "$USAGE_FILE.tmp"
mv "$USAGE_FILE.tmp" "$USAGE_FILE"

echo '{"decision": "allow"}'
```

### 11.3 Cost Guardian

```bash
# ~/.claude/hooks/cost-guardian.sh
# Blocks expensive operations without confirmation

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.toolName')

# Supabase branch creation costs money
if [[ "$TOOL" == "mcp__supabase__create_branch" ]]; then
  echo '{"decision": "warn", "message": "Creating branch incurs hourly cost - confirm to proceed"}'
  exit 0
fi

# Pinecone index creation
if [[ "$TOOL" == "mcp__pinecone__create-index-for-model" ]]; then
  echo '{"decision": "warn", "message": "Creating Pinecone index - verify configuration"}'
  exit 0
fi

echo '{"decision": "allow"}'
```

---

## Part 12: Observability & Audit

### 12.1 Audit Logger

```bash
# ~/.claude/hooks/audit-logger.sh
# Logs all MCP tool executions

INPUT=$(cat)
TIMESTAMP=$(date -Iseconds)
TOOL=$(echo "$INPUT" | jq -r '.toolName')
SESSION_ID=${CLAUDE_SESSION_ID:-"unknown"}

LOG_FILE=~/.claude/audit/$(date +%Y-%m-%d).jsonl

mkdir -p ~/.claude/audit

echo "{\"timestamp\":\"$TIMESTAMP\",\"session\":\"$SESSION_ID\",\"tool\":\"$TOOL\",\"input\":$INPUT}" >> "$LOG_FILE"

# Continue without blocking
exit 0
```

### 12.2 Metrics Collection

```bash
# ~/.claude/hooks/metrics-collector.sh
# Collects usage metrics for analysis

METRICS_FILE=~/.claude/hook-state/metrics.json

# ... implementation details ...
```

---

## Part 13: Implementation Steps

### Phase 1: Core Infrastructure
1. Create directory structure for documentation files
2. Create hook-state directory and initialize state files
3. Update settings.json with multi-layer hook configuration
4. Test basic hook execution

### Phase 2: MCP Documentation Files
5. Create PINECONE-ADVANCED.md with complete tool reference
6. Create GITHUB-ADVANCED.md with complete tool reference
7. Create GREPTILE-ADVANCED.md with complete tool reference
8. Create SERENA-ADVANCED.md with complete tool reference
9. Create CONTEXT7-ADVANCED.md with complete tool reference
10. Create FIREBASE-ADVANCED.md with complete tool reference
11. Create SUPABASE-ADVANCED.md with complete tool reference
12. Create index.md linking all documentation

### Phase 3: Hook Scripts
13. Create enhanced mcp-router.sh with 150+ triggers
14. Create production-guard.sh (PreToolUse)
15. Create rate-limiter.sh (PreToolUse)
16. Create cost-guardian.sh (PreToolUse)
17. Create audit-logger.sh (PostToolUse)
18. Create auto-formatter.sh (PostToolUse)
19. Create pinecone-auto-index.sh (PostToolUse)
20. Create session-intelligence.sh (UserPromptSubmit)

### Phase 4: Composite Workflows
21. Create COMPOSITE-WORKFLOWS.md documentation
22. Implement full-analysis workflow
23. Implement daily-standup workflow
24. Implement deploy-all workflow
25. Implement code-review-pipeline workflow

### Phase 5: Testing & Verification
26. Test each trigger phrase individually
27. Test PreToolUse blocking scenarios
28. Test PostToolUse processing
29. Test composite workflows end-to-end
30. Validate audit logging

---

## Part 14: Updated settings.json Structure

```json
{
  "env": {
    "DISABLE_AUTOUPDATER": "1",
    "CLAUDE_HOOKS_DEBUG": "0"
  },
  "alwaysThinkingEnabled": true,
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {"type": "command", "command": "bash ~/.claude/hooks/session-intelligence.sh"},
          {"type": "command", "command": "bash ~/.claude/hooks/mcp-router.sh"}
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "mcp__supabase|mcp__firebase",
        "hooks": [
          {"type": "command", "command": "bash ~/.claude/hooks/production-guard.sh"}
        ]
      },
      {
        "matcher": "mcp__",
        "hooks": [
          {"type": "command", "command": "bash ~/.claude/hooks/rate-limiter.sh"},
          {"type": "command", "command": "bash ~/.claude/hooks/cost-guardian.sh"}
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {"type": "command", "command": "bash ~/.claude/hooks/auto-formatter.sh"}
        ]
      },
      {
        "matcher": "mcp__",
        "hooks": [
          {"type": "command", "command": "bash ~/.claude/hooks/audit-logger.sh"},
          {"type": "command", "command": "bash ~/.claude/hooks/pinecone-auto-index.sh"}
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {"type": "command", "command": "bash ~/.claude/hooks/session-end-reminder.sh"}
        ]
      }
    ]
  }
}
```

---

## Critical Files to Create/Modify

### New Files (18 total)
1. `~/workspace/CLAUDE.md/index.md`
2. `~/workspace/CLAUDE.md/PINECONE-ADVANCED.md`
3. `~/workspace/CLAUDE.md/GITHUB-ADVANCED.md`
4. `~/workspace/CLAUDE.md/GREPTILE-ADVANCED.md`
5. `~/workspace/CLAUDE.md/SERENA-ADVANCED.md`
6. `~/workspace/CLAUDE.md/CONTEXT7-ADVANCED.md`
7. `~/workspace/CLAUDE.md/FIREBASE-ADVANCED.md`
8. `~/workspace/CLAUDE.md/SUPABASE-ADVANCED.md`
9. `~/workspace/CLAUDE.md/COMPOSITE-WORKFLOWS.md`
10. `~/workspace/CLAUDE.md/HOOK-REFERENCE.md`
11. `~/.claude/hooks/production-guard.sh`
12. `~/.claude/hooks/rate-limiter.sh`
13. `~/.claude/hooks/cost-guardian.sh`
14. `~/.claude/hooks/audit-logger.sh`
15. `~/.claude/hooks/auto-formatter.sh`
16. `~/.claude/hooks/pinecone-auto-index.sh`
17. `~/.claude/hooks/session-intelligence.sh`
18. `~/.claude/hook-state/` (directory with JSON state files)

### Modified Files (2 total)
1. `~/.claude/settings.json` - Add new hook configuration
2. `~/.claude/hooks/mcp-router.sh` - Expand to 150+ triggers

---

## Verification Plan

1. **Hook Execution Test:**
   ```bash
   echo "semantic search: test" | bash ~/.claude/hooks/mcp-router.sh
   # Should output appropriate systemMessage
   ```

2. **PreToolUse Test:**
   ```bash
   echo '{"toolName":"mcp__supabase__execute_sql","query":"DROP TABLE users"}' | bash ~/.claude/hooks/production-guard.sh
   # Should return block decision
   ```

3. **Composite Workflow Test:**
   - Type "daily standup" in Claude session
   - Verify all MCPs are queried
   - Verify report is generated

4. **Audit Log Test:**
   - Execute any MCP tool
   - Check ~/.claude/audit/*.jsonl for entry

---

## Summary

This plan provides:

- **150+ new triggers** across 7 MCP servers
- **10 new hook scripts** for different purposes
- **8 comprehensive documentation files**
- **Multi-layer safety architecture** with PreToolUse gates
- **Full observability** with audit logging
- **15 composite workflows** for complex operations
- **State management** for cross-hook communication

The system transforms Claude Code into an enterprise-grade AI development environment with:
- Intent detection and intelligent routing
- Production safety guardrails
- Usage monitoring and rate limiting
- Automatic knowledge indexing
- Cross-session context persistence
