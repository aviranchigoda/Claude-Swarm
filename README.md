# Claude-Swarm

A unified, modular configuration system for Claude Code CLI with intelligent command routing, session management, and multi-MCP orchestration.

## Features

- **45+ Trigger Commands** - Natural language commands routed to 7 MCP servers
- **Session Management** - Persistent context storage via Pinecone
- **Unified Hook System** - Single router handling all Claude Code events
- **State Tracking** - Session, trigger, and MCP usage tracking
- **Comprehensive Documentation** - Per-MCP reference guides

## Quick Start

1. Clone to your `~/.claude` directory:
   ```bash
   git clone https://github.com/aviranchigoda/Claude-Swarm.git ~/.claude
   ```

2. Ensure `jq` is installed (used by hooks):
   ```bash
   sudo apt-get install jq  # Debian/Ubuntu
   brew install jq          # macOS
   ```

3. Make hooks executable:
   ```bash
   chmod +x ~/.claude/hooks/*.sh
   chmod +x ~/.claude/hooks/**/*.sh
   ```

## Architecture

```
~/.claude/
├── CLAUDE.md              # Master documentation
├── settings.json          # Claude Code settings
├── config/                # Unified configuration
│   ├── triggers.json      # 45+ trigger patterns
│   ├── permissions.json   # Permission whitelist
│   └── master.json        # System settings
├── hooks/                 # Unified hook system
│   ├── router.sh          # Main entry point
│   ├── lib/               # Shared utilities
│   └── handlers/          # Event handlers
├── state/                 # Runtime state
│   ├── session.json       # Current session
│   └── trigger-history.json
└── docs/                  # Per-MCP documentation
    ├── PINECONE.md
    ├── GITHUB.md
    ├── GREPTILE.md
    ├── SERENA.md
    ├── CONTEXT7.md
    ├── FIREBASE.md
    └── SUPABASE.md
```

## Trigger Commands

### Session Management (Pinecone)
| Command | Action |
|---------|--------|
| `start session` | Load context from Pinecone |
| `end session` | Save session summary |
| `search blueprints` | Query blueprints |
| `add todo` | Add to todos |
| `add decision` | Store ADR |

### GitHub Operations
| Command | Action |
|---------|--------|
| `git status` | Show repo status |
| `create pr` | Create pull request |
| `list issues` | List open issues |
| `review pr` | Review pull request |

### Code Analysis (Greptile)
| Command | Action |
|---------|--------|
| `explain codebase` | Architecture overview |
| `find implementation` | Search code |
| `trace flow` | Trace execution |
| `code review` | Quality review |

### Composite Commands
| Command | MCPs |
|---------|------|
| `full analysis` | Serena + Greptile + Pinecone + Context7 |
| `deploy all` | GitHub + Firebase + Supabase + Pinecone |
| `daily standup` | Pinecone + GitHub |

## MCP Servers

| Server | Purpose |
|--------|--------|
| **Pinecone** | Vector database for context storage |
| **GitHub** | Repository and PR management |
| **Greptile** | Semantic code analysis |
| **Serena** | Symbol-aware navigation |
| **Context7** | Library documentation |
| **Firebase** | Google Cloud backend |
| **Supabase** | PostgreSQL backend |

## Configuration

### triggers.json

Defines all command patterns and their routing:

```json
{
  "pinecone": [
    {
      "pattern": "^start session",
      "action": "SESSION_START",
      "message": "Execute SESSION START protocol"
    }
  ]
}
```

### permissions.json

Auto-approved operations:

```json
{
  "auto_approve": {
    "bash": ["ls:*", "cat:*", "grep:*"],
    "mcp": ["github.get_file_contents"]
  }
}
```

## Hooks

The hook system processes three Claude Code events:

1. **UserPromptSubmit** - Matches triggers and injects system messages
2. **PostToolUse** - Auto-renames plan files
3. **Stop** - Reminds to save session context

## License

MIT

---

*Built with Claude Opus 4.5*
