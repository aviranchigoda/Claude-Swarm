# Context7 MCP Reference

Context7 provides up-to-date documentation and code examples for programming libraries.

## Trigger Commands

| Command | Action | Details |
|---------|--------|---------|
| `lookup docs` | SEARCH | Find documentation |
| `how to use` | EXAMPLES | Find usage examples |
| `api reference` | API | Fetch API docs |
| `protocol spec` | SPEC | Find protocol specification |
| `library docs` | LIBRARY | Search library documentation |

## Available Tools

### mcp__context7__resolve-library-id
Resolve a library name to Context7 library ID.

**IMPORTANT:** Call this first before `query-docs` unless you have an explicit library ID.

**Parameters:**
- `libraryName`: Library name to search (e.g., "react", "express")
- `query`: User's question for relevance ranking

**Returns:**
- Library ID in format `/org/project` or `/org/project/version`
- Relevance score and description

**Selection Criteria:**
1. Name similarity to query
2. Description relevance
3. Documentation coverage (Code Snippet counts)
4. Source reputation (High/Medium)
5. Benchmark Score (100 = highest)

### mcp__context7__query-docs
Query documentation for a specific library.

**Parameters:**
- `libraryId`: Context7 library ID (from resolve-library-id)
- `query`: Question or task description

**Query Examples:**
- Good: "How to set up authentication with JWT in Express.js"
- Good: "React useEffect cleanup function examples"
- Bad: "auth" (too vague)
- Bad: "hooks" (too generic)

## Usage Pattern

```
1. User asks: "How do I use hooks in React?"

2. Call resolve-library-id:
   - libraryName: "react"
   - query: "how to use hooks"

3. Get library ID: "/facebook/react"

4. Call query-docs:
   - libraryId: "/facebook/react"
   - query: "how to use hooks, useState, useEffect examples"

5. Present documentation to user
```

## Best Practices

1. **Always resolve library ID first** unless explicitly provided
2. **Be specific in queries** - include context
3. **Limit to 3 calls per question** - use best result
4. **Check version** if library ID includes version
5. **Never include sensitive data** in queries
