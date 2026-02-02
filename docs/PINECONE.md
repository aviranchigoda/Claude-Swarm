# Pinecone MCP Reference

Pinecone is a vector database used for persistent context storage across Claude sessions.

## Namespaces

| Namespace | Purpose | Schema |
|-----------|---------|--------|
| `sessions` | Session summaries and context | `{summary, timestamp, project, duration}` |
| `blueprints` | Architecture blueprints | `{name, content, tags, created}` |
| `architecture` | System designs | `{title, description, components}` |
| `todos` | Task tracking | `{task, status, priority, project}` |
| `decisions` | Architecture Decision Records | `{decision, context, consequences, date}` |

## Trigger Commands

| Command | Action | Details |
|---------|--------|---------|
| `start session` | SESSION_START | Load context from sessions, todos, decisions |
| `end session` | SESSION_END | Save session summary |
| `search blueprints` | SEARCH | Query blueprints namespace |
| `search architecture` | SEARCH | Query architecture namespace |
| `search sessions` | SEARCH | Query sessions namespace |
| `search todos` | SEARCH | Query todos namespace |
| `search decisions` | SEARCH | Query decisions namespace |
| `add todo` | UPSERT | Add to todos namespace |
| `add decision` | UPSERT | Add ADR to decisions namespace |
| `pinecone stats` | STATS | Show index statistics |

## Available Tools

### mcp__pinecone__search-records
Search an index for records similar to query text.

**Parameters:**
- `name` (required): Index name
- `namespace` (required): Namespace to search
- `query`: Object with `topK` and `inputs.text`
- `rerank`: Optional reranking configuration

**Example:**
```json
{
  "name": "claude-context",
  "namespace": "sessions",
  "query": {
    "topK": 5,
    "inputs": {"text": "trading system implementation"}
  }
}
```

### mcp__pinecone__upsert-records
Insert or update records in an index.

**Parameters:**
- `name` (required): Index name
- `namespace` (required): Namespace
- `records`: Array of records with `_id` and text field

**Example:**
```json
{
  "name": "claude-context",
  "namespace": "sessions",
  "records": [{
    "_id": "session-2026-02-02",
    "text": "Worked on unified Claude configuration...",
    "project": "/home/ai_dev/.claude",
    "timestamp": "2026-02-02T00:00:00Z"
  }]
}
```

### mcp__pinecone__describe-index-stats
Get statistics about an index.

**Parameters:**
- `name` (required): Index name

### mcp__pinecone__list-indexes
List all available indexes.

### mcp__pinecone__describe-index
Get configuration details for an index.

**Parameters:**
- `name` (required): Index name

## Session Protocols

### Session Start
```
1. Search sessions namespace for recent summaries
2. Search todos namespace for pending tasks
3. Search decisions namespace for recent ADRs
4. Present summarized context to user
```

### Session End
```
1. Generate summary of current session
2. Upsert to sessions namespace
3. Update any todos that were completed
4. Log session end in state
```

## Best Practices

1. **Use consistent schemas** within each namespace
2. **Include timestamps** in all records
3. **Tag content** for easier retrieval
4. **Limit topK** to avoid overwhelming results
5. **Use reranking** for complex queries
