# Claude Configuration System

This is a unified, modular Claude Code configuration system providing intelligent command routing, session management, and multi-MCP orchestration.

## Quick Reference: Command Triggers

### Session Management (Pinecone)
| Command | Action |
|---------|--------|
| `start session` | Load context from Pinecone (sessions, todos, decisions) |
| `end session` | Save session summary to Pinecone |
| `search blueprints` | Query blueprints namespace |
| `search architecture` | Query architecture namespace |
| `add todo` | Upsert to todos namespace |
| `add decision` | Store ADR in decisions namespace |
| `pinecone stats` | Show index statistics |

### GitHub Operations
| Command | Action |
|---------|--------|
| `git status` | Show repo status and recent commits |
| `create pr` | Create pull request |
| `list issues` | List open issues |
| `create issue` | Create new issue |
| `review pr` | Review pull request |
| `commit changes` | Stage and commit all changes |
| `push changes` | Push to remote |
| `list prs` | List pull requests |
| `list branches` | List branches |

### Code Analysis (Greptile)
| Command | Action |
|---------|--------|
| `explain codebase` | Semantic architecture overview |
| `find implementation` | Search for code implementation |
| `trace flow` | Trace execution path |
| `find callers` | Find all usages |
| `similar code` | Find similar patterns |
| `code review` | Quality and security review |

### Symbol Navigation (Serena)
| Command | Action |
|---------|--------|
| `analyze project` | Activate and analyze project |
| `list symbols` | Get symbols overview |
| `find pattern` | Regex search |
| `find symbol` | Find symbol definition |
| `find references` | Find referencing symbols |
| `serena memories` | List stored memories |

### Documentation (Context7)
| Command | Action |
|---------|--------|
| `lookup docs` | Find documentation |
| `how to use` | Find usage examples |
| `api reference` | Fetch API docs |
| `protocol spec` | Find protocol specification |
| `library docs` | Search library documentation |

### Firebase Operations
| Command | Action |
|---------|--------|
| `firebase status` | List Firebase projects |
| `deploy firebase` | Deploy to Firebase |
| `firebase logs` | View Firebase logs |
| `firestore query` | Query Firestore |
| `firebase apps` | List Firebase apps |

### Supabase Operations
| Command | Action |
|---------|--------|
| `supabase status` | Check connection |
| `list tables` | Show schema |
| `query table` | Execute SELECT |
| `insert into` | Insert record |
| `run migration` | Run migration |
| `deploy function` | Deploy edge function |

### Composite Commands (Multi-MCP)
| Command | MCPs Used | Action |
|---------|-----------|--------|
| `full analysis` | Serena + Greptile + Pinecone + Context7 | Complete codebase analysis |
| `deploy all` | GitHub + Firebase + Supabase + Pinecone | Deploy to all platforms |
| `daily standup` | Pinecone + GitHub | Load context + show status |
| `research topic` | Context7 + Greptile + Pinecone | Research using multiple sources |

---

## Session Protocols

### SESSION START Protocol

When user says "start session", "load context", or "what did we work on":

1. **Query Pinecone sessions namespace** - Get recent session summaries
2. **Query Pinecone todos namespace** - Get pending tasks
3. **Query Pinecone decisions namespace** - Get recent ADRs
4. **Summarize context** - Present what was worked on previously
5. **Mark context as loaded** in session state

### SESSION END Protocol

When user says "end session", "done", "save session", or "wrapping up":

1. **Generate session summary** including:
   - What was accomplished
   - Key decisions made
   - Outstanding issues
   - Next steps
2. **Upsert to Pinecone sessions namespace**
3. **Update todos status** if applicable
4. **Archive session state**

---

## Architecture Overview

```
~/.claude/
├── CLAUDE.md                    # This file - master documentation
├── config/                      # Unified configuration
│   ├── master.json              # System settings
│   ├── triggers.json            # All trigger definitions (45+)
│   └── permissions.json         # Permission whitelist
├── hooks/                       # Unified hook system
│   ├── router.sh                # Main entry point
│   ├── lib/                     # Shared utilities
│   │   ├── common.sh            # Common functions
│   │   └── state.sh             # State management
│   └── handlers/                # Event handlers
│       ├── prompt-submit.sh     # UserPromptSubmit
│       ├── post-tool.sh         # PostToolUse
│       └── session.sh           # Stop
├── state/                       # Runtime state
│   ├── session.json             # Current session
│   ├── trigger-history.json     # Trigger usage
│   └── mcp-usage.json           # MCP call tracking
├── docs/                        # Per-MCP documentation
│   ├── PINECONE.md
│   ├── GITHUB.md
│   ├── GREPTILE.md
│   ├── SERENA.md
│   ├── CONTEXT7.md
│   ├── FIREBASE.md
│   └── SUPABASE.md
├── plans/                       # Auto-renamed planning docs
├── projects/                    # Per-project workspaces
└── plugins/                     # Installed plugins
```

---

## MCP Server Details

### Pinecone
Vector database for persistent context storage.

**Namespaces:**
- `sessions` - Session summaries and context
- `blueprints` - Architecture blueprints
- `architecture` - System designs
- `todos` - Task tracking
- `decisions` - Architecture Decision Records

**Key Tools:**
- `mcp__pinecone__search-records` - Semantic search
- `mcp__pinecone__upsert-records` - Store records
- `mcp__pinecone__describe-index-stats` - Index statistics

See: [docs/PINECONE.md](docs/PINECONE.md)

### GitHub
Repository management and collaboration.

**Key Tools:**
- `mcp__github__list_pull_requests` - List PRs
- `mcp__github__create_pull_request` - Create PR
- `mcp__github__list_issues` - List issues
- `mcp__github__get_file_contents` - Read files

See: [docs/GITHUB.md](docs/GITHUB.md)

### Greptile
Semantic code analysis and search.

**Key Tools:**
- `mcp__greptile__list_merge_requests` - List PRs
- `mcp__greptile__get_merge_request` - PR details
- `mcp__greptile__search_greptile_comments` - Search comments

See: [docs/GREPTILE.md](docs/GREPTILE.md)

### Serena
Symbol-aware code navigation.

**Key Tools:**
- `mcp__serena__find_symbol` - Find symbols
- `mcp__serena__get_symbols_overview` - Symbol overview
- `mcp__serena__find_referencing_symbols` - Find references
- `mcp__serena__read_file` - Read file content

See: [docs/SERENA.md](docs/SERENA.md)

### Context7
Up-to-date library documentation.

**Key Tools:**
- `mcp__context7__resolve-library-id` - Find library
- `mcp__context7__query-docs` - Query documentation

See: [docs/CONTEXT7.md](docs/CONTEXT7.md)

### Firebase
Google Cloud Firebase services.

**Key Tools:**
- `mcp__firebase__firebase_list_projects` - List projects
- `mcp__firebase__firebase_get_environment` - Get config
- `mcp__firebase__firebase_init` - Initialize

See: [docs/FIREBASE.md](docs/FIREBASE.md)

### Supabase
PostgreSQL-based backend services.

**Key Tools:**
- `mcp__supabase__list_projects` - List projects
- `mcp__supabase__execute_sql` - Run SQL
- `mcp__supabase__apply_migration` - Run migrations

See: [docs/SUPABASE.md](docs/SUPABASE.md)

---

## Installed Plugins

| Plugin | Purpose |
|--------|--------|
| `clangd-lsp` | C/C++ language server |
| `rust-analyzer-lsp` | Rust language server |
| `code-review` | PR code review |
| `feature-dev` | Guided feature development |
| `pr-review-toolkit` | Comprehensive PR analysis |
| `code-simplifier` | Code simplification |
| `hookify` | Behavior prevention hooks |
| `ralph-loop` | Iterative development |

---

## Configuration Files

### config/triggers.json
Contains all 45+ trigger patterns organized by MCP service. Each trigger has:
- `pattern` - Regex pattern to match
- `action` - Action type
- `message` - System message to inject

### config/permissions.json
Auto-approved operations that don't require confirmation.

### config/master.json
System-wide settings including:
- Thinking mode (always enabled)
- State tracking options
- Logging configuration
- Plugin list

---

## Best Practices

1. **Start sessions explicitly** - Say "start session" to load context
2. **End sessions explicitly** - Say "end session" to save context
3. **Use trigger commands** - They route to the right MCP automatically
4. **Check docs/ for details** - Each MCP has detailed documentation
5. **Review trigger history** - State files track what you've used

---

## Troubleshooting

**Triggers not working?**
- Check `~/.claude/config/triggers.json` exists and is valid JSON
- Ensure `jq` is installed: `which jq`
- Check hook permissions: `ls -la ~/.claude/hooks/`

**State not persisting?**
- Check `~/.claude/state/` directory exists
- Verify write permissions

**MCP not responding?**
- Check the specific MCP documentation in `docs/`
- Verify MCP server is configured correctly

---

## File Locations

| File | Purpose |
|------|--------|
| `~/.claude/CLAUDE.md` | This documentation |
| `~/.claude/config/triggers.json` | Trigger definitions |
| `~/.claude/config/permissions.json` | Permission whitelist |
| `~/.claude/hooks/router.sh` | Main hook entry point |
| `~/.claude/state/session.json` | Current session |
| `~/.claude/state/trigger-history.json` | Usage tracking |
| `~/.claude/settings.json` | Claude Code settings |
