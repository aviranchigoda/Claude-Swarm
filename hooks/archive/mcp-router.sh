#!/bin/bash
# Original MCP Router (archived)
# This was the original hardcoded trigger matching system.
# Now replaced by JSON-driven config/triggers.json

INPUT=$(cat)
INPUT_LOWER=$(echo "$INPUT" | tr '[:upper:]' '[:lower:]')

# PINECONE
if echo "$INPUT_LOWER" | grep -qE "^(start session|load context|what did we work on)"; then
    echo '{"systemMessage": "⚡ PINECONE: Execute SESSION START protocol from CLAUDE.md"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^(end session|done|save session|wrapping up)"; then
    echo '{"systemMessage": "⚡ PINECONE: Execute SESSION END protocol from CLAUDE.md"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^search blueprints"; then
    echo '{"systemMessage": "⚡ PINECONE: Search blueprints namespace"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^search architecture"; then
    echo '{"systemMessage": "⚡ PINECONE: Search architecture namespace"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^add todo"; then
    echo '{"systemMessage": "⚡ PINECONE: Upsert to todos namespace"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^add decision"; then
    echo '{"systemMessage": "⚡ PINECONE: Upsert ADR to decisions namespace"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^pinecone stats"; then
    echo '{"systemMessage": "⚡ PINECONE: Run describe-index-stats"}'
    exit 0
fi

# GITHUB
if echo "$INPUT_LOWER" | grep -qE "^git status"; then
    echo '{"systemMessage": "⚡ GITHUB: Show repo status and recent commits"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^create pr"; then
    echo '{"systemMessage": "⚡ GITHUB: Create pull request"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^list issues"; then
    echo '{"systemMessage": "⚡ GITHUB: List open issues"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^create issue"; then
    echo '{"systemMessage": "⚡ GITHUB: Create new issue"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^review pr"; then
    echo '{"systemMessage": "⚡ GITHUB: Review PR"}'
    exit 0
fi

# GREPTILE
if echo "$INPUT_LOWER" | grep -qE "^explain codebase"; then
    echo '{"systemMessage": "⚡ GREPTILE: Semantic architecture overview"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^find implementation"; then
    echo '{"systemMessage": "⚡ GREPTILE: Search for implementation"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^trace flow"; then
    echo '{"systemMessage": "⚡ GREPTILE: Trace execution path"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^code review"; then
    echo '{"systemMessage": "⚡ GREPTILE: Quality and security review"}'
    exit 0
fi

# SERENA
if echo "$INPUT_LOWER" | grep -qE "^analyze project"; then
    echo '{"systemMessage": "⚡ SERENA: Activate and analyze project"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^list symbols"; then
    echo '{"systemMessage": "⚡ SERENA: Get symbols overview"}'
    exit 0
fi

# CONTEXT7
if echo "$INPUT_LOWER" | grep -qE "^lookup docs"; then
    echo '{"systemMessage": "⚡ CONTEXT7: Find documentation"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^how to use"; then
    echo '{"systemMessage": "⚡ CONTEXT7: Find usage examples"}'
    exit 0
fi

# FIREBASE
if echo "$INPUT_LOWER" | grep -qE "^firebase status"; then
    echo '{"systemMessage": "⚡ FIREBASE: List projects"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^deploy firebase"; then
    echo '{"systemMessage": "⚡ FIREBASE: Deploy"}'
    exit 0
fi

# SUPABASE
if echo "$INPUT_LOWER" | grep -qE "^supabase status"; then
    echo '{"systemMessage": "⚡ SUPABASE: Check connection"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^list tables"; then
    echo '{"systemMessage": "⚡ SUPABASE: Show schema"}'
    exit 0
fi

# COMPOSITE
if echo "$INPUT_LOWER" | grep -qE "^full analysis"; then
    echo '{"systemMessage": "⚡ MULTI-MCP: Use Serena + Greptile + Pinecone + Context7"}'
    exit 0
fi
if echo "$INPUT_LOWER" | grep -qE "^daily standup"; then
    echo '{"systemMessage": "⚡ MULTI-MCP: Pinecone + GitHub status"}'
    exit 0
fi
