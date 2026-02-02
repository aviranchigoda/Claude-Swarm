#!/bin/bash
FILE="$1"

# Only process files in the plans directory with the random name pattern
if [[ "$FILE" =~ \.claude/plans/[a-z]+-[a-z]+-[a-z]+\.md$ ]]; then
    DIR=$(dirname "$FILE")
    DATE=$(date +%Y-%m-%d-%H%M)

    # Extract first heading for description
    DESC=$(grep -m1 "^#" "$FILE" | sed 's/^#* *//' | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | tr -cd '[:alnum:]-' | cut -c1-40)

    if [ -z "$DESC" ]; then
        DESC="plan"
    fi

    NEW_NAME="${DIR}/${DATE}-${DESC}.md"
    mv "$FILE" "$NEW_NAME"
fi
