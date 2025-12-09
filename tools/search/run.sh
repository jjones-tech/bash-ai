#!/bin/bash
PARAMS="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

query=$(echo "$PARAMS" | jq -r '.query // empty')

if [ -z "$query" ]; then
    echo "Error: query is required" >&2
    exit 1
fi

"$SCRIPT_DIR/../../gemini_chat.sh" --search "$query"
