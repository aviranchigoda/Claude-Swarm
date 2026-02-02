# GitHub MCP Reference

GitHub MCP provides repository management, issue tracking, and pull request operations.

## Trigger Commands

| Command | Action | Details |
|---------|--------|---------|
| `git status` | STATUS | Show repo status and recent commits |
| `create pr` | CREATE_PR | Create pull request |
| `list issues` | LIST_ISSUES | List open issues |
| `create issue` | CREATE_ISSUE | Create new issue |
| `review pr` | REVIEW_PR | Review pull request |
| `commit changes` | COMMIT | Stage and commit all changes |
| `push changes` | PUSH | Push to remote |
| `list prs` | LIST_PRS | List pull requests |
| `merge pr` | MERGE_PR | Merge pull request |
| `list branches` | LIST_BRANCHES | List branches |

## Available Tools

### Repository Operations

#### mcp__github__get_file_contents
Get contents of a file or directory.

**Parameters:**
- `owner`: Repository owner
- `repo`: Repository name
- `path`: Path to file/directory
- `ref`: Optional git ref (branch/tag/commit)

#### mcp__github__list_commits
Get commit history.

**Parameters:**
- `owner`, `repo`: Repository identifiers
- `sha`: Branch/tag/commit to list from
- `page`, `perPage`: Pagination

#### mcp__github__list_branches
List repository branches.

### Pull Request Operations

#### mcp__github__create_pull_request
Create a new pull request.

**Parameters:**
- `owner`, `repo`: Repository identifiers
- `title`: PR title
- `head`: Source branch
- `base`: Target branch
- `body`: Description
- `draft`: Create as draft (boolean)

#### mcp__github__list_pull_requests
List pull requests.

**Parameters:**
- `owner`, `repo`: Repository identifiers
- `state`: open, closed, or all
- `sort`: created, updated, popularity
- `direction`: asc or desc

#### mcp__github__pull_request_read
Get PR details with various methods.

**Methods:**
- `get`: Get PR details
- `get_diff`: Get the diff
- `get_status`: Get build/check status
- `get_files`: Get changed files
- `get_review_comments`: Get review threads
- `get_reviews`: Get reviews
- `get_comments`: Get comments

#### mcp__github__merge_pull_request
Merge a pull request.

**Parameters:**
- `owner`, `repo`: Repository identifiers
- `pullNumber`: PR number
- `merge_method`: merge, squash, or rebase

### Issue Operations

#### mcp__github__list_issues
List repository issues.

**Parameters:**
- `owner`, `repo`: Repository identifiers
- `state`: OPEN or CLOSED
- `labels`: Filter by labels

#### mcp__github__issue_write
Create or update issues.

**Methods:**
- `create`: Create new issue
- `update`: Update existing issue

#### mcp__github__add_issue_comment
Add comment to an issue.

### Code Search

#### mcp__github__search_code
Search code across repositories.

**Parameters:**
- `query`: Search query with GitHub syntax
- `sort`, `order`: Sort options

**Query Examples:**
- `content:Skill language:Java org:github`
- `repo:owner/repo function_name`

## Best Practices

1. **Always get status first** before making changes
2. **Use draft PRs** for work in progress
3. **Include meaningful PR descriptions**
4. **Link issues** in PR descriptions
5. **Use squash merge** for cleaner history
