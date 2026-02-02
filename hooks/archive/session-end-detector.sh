#!/bin/bash
INPUT=$(cat)
if echo "$INPUT" | grep -qiE "end session|done for today|save session|wrapping up"; then
    echo '{"systemMessage": "⚡ EXECUTE SESSION END PROTOCOL FROM CLAUDE.md - Generate summary and store in Pinecone NOW."}'
fi
