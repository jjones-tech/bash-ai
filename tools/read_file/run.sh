#!/bin/bash
PARAMS="$1"
filepath=$(echo "$PARAMS" | jq -r '.filepath')

if [ -z "$filepath" ] || [ "$filepath" == "null" ]; then
    echo "Error: 'filepath' parameter is required." >&2
    exit 1
fi

# Security check
if [[ "$filepath" == *".."* ]] || [[ "$filepath" == "/" ]]; then
    echo "Error: Invalid file path." >&2
    exit 1
fi

if [ -f "$filepath" ]; then
    cat "$filepath"
else
    echo "Error: File not found at '$filepath'." >&2
    exit 1
fi
