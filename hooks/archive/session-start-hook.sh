#!/bin/bash
INPUT=$(cat)
if echo "$INPUT" | grep -qiE "start session|load context|what did we work on"; then
    echo '{"systemMessage": "⚡ EXECUTE SESSION START PROTOCOL FROM CLAUDE.md - Query Pinecone sessions, todos, and decisions namespaces NOW."}'
fi
