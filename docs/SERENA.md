# Serena MCP Reference

Serena provides symbol-aware code navigation and intelligent editing.

## Trigger Commands

| Command | Action | Details |
|---------|--------|---------|
| `analyze project` | ACTIVATE | Activate and analyze project |
| `list symbols` | SYMBOLS | Get symbols overview |
| `find pattern` | SEARCH | Regex search in codebase |
| `read file` | READ | Read file contents |
| `list dir` | LIST | List directory contents |
| `find symbol` | FIND_SYMBOL | Find symbol definition |
| `find references` | FIND_REFS | Find referencing symbols |
| `serena memories` | LIST_MEMORIES | List stored memories |

## Available Tools

### Project Management

#### mcp__serena__activate_project
Activate a project for analysis.

**Parameters:**
- `project`: Project name or path

#### mcp__serena__get_current_config
Get current configuration including active project.

#### mcp__serena__check_onboarding_performed
Check if project onboarding was done.

### Symbol Operations

#### mcp__serena__get_symbols_overview
Get high-level overview of symbols in a file.

**Parameters:**
- `relative_path`: Path to file
- `depth`: Depth for descendants (default 0)

#### mcp__serena__find_symbol
Find symbols by name path pattern.

**Parameters:**
- `name_path_pattern`: Pattern to match (e.g., "Foo/method")
- `relative_path`: Optional path restriction
- `include_body`: Include source code
- `include_info`: Include docstring/signature
- `depth`: Depth for descendants
- `substring_matching`: Enable fuzzy matching

**Name Path Patterns:**
- `method` - Match any symbol named "method"
- `Class/method` - Match method in Class
- `/Class/method` - Exact match from root

#### mcp__serena__find_referencing_symbols
Find references to a symbol.

**Parameters:**
- `name_path`: Symbol to find references for
- `relative_path`: File containing the symbol

### File Operations

#### mcp__serena__read_file
Read file contents.

**Parameters:**
- `relative_path`: Path to file
- `start_line`, `end_line`: Optional line range

#### mcp__serena__list_dir
List directory contents.

**Parameters:**
- `relative_path`: Path to directory
- `recursive`: Scan subdirectories

#### mcp__serena__find_file
Find files matching a mask.

**Parameters:**
- `file_mask`: Filename or pattern (e.g., "*.py")
- `relative_path`: Directory to search

### Search

#### mcp__serena__search_for_pattern
Regex search across codebase.

**Parameters:**
- `substring_pattern`: Regex pattern
- `relative_path`: Optional path restriction
- `restrict_search_to_code_files`: Only search code files
- `paths_include_glob`, `paths_exclude_glob`: File filters
- `context_lines_before`, `context_lines_after`: Context

### Editing (when in edit mode)

#### mcp__serena__replace_symbol_body
Replace entire symbol definition.

#### mcp__serena__insert_after_symbol
Insert code after a symbol.

#### mcp__serena__insert_before_symbol
Insert code before a symbol.

#### mcp__serena__replace_content
Regex-based content replacement.

#### mcp__serena__rename_symbol
Rename symbol across codebase.

### Memories

#### mcp__serena__list_memories
List available memory files.

#### mcp__serena__read_memory
Read a memory file.

#### mcp__serena__write_memory
Write project information to memory.

## Best Practices

1. **Activate project first** before using other tools
2. **Use symbol tools** for precise navigation
3. **Prefer find_symbol** over grep for code
4. **Use relative paths** from project root
5. **Check onboarding** for new projects
