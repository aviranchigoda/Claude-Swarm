# Greptile MCP Reference

Greptile provides semantic code analysis and intelligent code review.

## Trigger Commands

| Command | Action | Details |
|---------|--------|---------|
| `explain codebase` | OVERVIEW | Semantic architecture overview |
| `find implementation` | SEARCH | Search for code implementation |
| `trace flow` | TRACE | Trace execution path |
| `find callers` | REFERENCES | Find all usages |
| `similar code` | SIMILAR | Find similar patterns |
| `code review` | REVIEW | Quality and security review |
| `greptile search` | SEARCH | General codebase search |

## Available Tools

### Code Review

#### mcp__greptile__trigger_code_review
Trigger a code review for a PR.

**Parameters:**
- `name`: Repository name (owner/repo)
- `remote`: github, gitlab, azure, bitbucket
- `prNumber`: PR number
- `defaultBranch`: Default branch name

#### mcp__greptile__get_code_review
Get detailed code review information.

**Parameters:**
- `codeReviewId`: Review ID

#### mcp__greptile__list_code_reviews
List code reviews with optional filters.

### Merge Request Operations

#### mcp__greptile__list_merge_requests
List PRs/MRs with various filters.

**Parameters:**
- `name`, `remote`, `defaultBranch`: Repository identifiers
- `sourceBranch`: Filter by source branch
- `authorLogin`: Filter by author
- `state`: open, closed, merged

#### mcp__greptile__get_merge_request
Get detailed MR information including review analysis.

#### mcp__greptile__list_merge_request_comments
Get all comments on a MR including Greptile reviews.

**Parameters:**
- `greptileGenerated`: Filter for only Greptile comments
- `addressed`: Filter by addressed status
- `createdAfter`, `createdBefore`: Date range filters

### Custom Context

#### mcp__greptile__list_custom_context
List organization custom context.

#### mcp__greptile__search_custom_context
Search custom context by content.

#### mcp__greptile__create_custom_context
Create new custom context.

**Parameters:**
- `body`: Context content
- `type`: CUSTOM_INSTRUCTION or PATTERN
- `scopes`: Boolean expression for scope

### Comment Search

#### mcp__greptile__search_greptile_comments
Search Greptile review comments.

**Parameters:**
- `query`: Search text
- `includeAddressed`: Include addressed comments
- `createdAfter`: Date filter

## Best Practices

1. **Use trigger_code_review** for automated feedback
2. **Check addressed status** on review comments
3. **Create custom context** for team conventions
4. **Use semantic search** for implementation discovery
5. **Review Greptile comments** before merging PRs
