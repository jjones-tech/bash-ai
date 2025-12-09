#!/bin/bash
PARAMS="$1"

files=$(echo "$PARAMS" | jq -r '.files[]' 2>/dev/null)
number_lines=$(echo "$PARAMS" | jq -r '.number_lines // false')

if [ -z "$files" ]; then
    echo "Error: No files specified." >&2
    exit 1
fi

output=""
while IFS= read -r filepath; do
    [ -z "$filepath" ] && continue
    
    if [[ "$filepath" == *".."* ]]; then
        echo "Error: Invalid path: $filepath" >&2
        exit 1
    fi
    
    if [ ! -f "$filepath" ]; then
        echo "Error: File not found: $filepath" >&2
        exit 1
    fi
    
    if [ -z "$output" ]; then
        output=$(cat "$filepath")
    else
        output="${output}"$'\n'"$(cat "$filepath")"
    fi
done <<< "$files"

if [ "$number_lines" = "true" ]; then
    echo "$output" | nl -ba
else
    echo "$output"
fi
