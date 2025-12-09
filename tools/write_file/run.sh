#!/bin/bash
PARAMS="$1"
filepath=$(echo "$PARAMS" | jq -r '.filepath')
content=$(echo "$PARAMS" | jq -r '.content')

if [ -z "$filepath" ] || [ "$filepath" == "null" ]; then
    echo "Error: 'filepath' parameter is required." >&2
    exit 1
fi

# Security check
if [[ "$filepath" == *".."* ]] || [[ "$filepath" == "/" ]]; then
    echo "Error: Invalid file path." >&2
    exit 1
fi

# Create directory if needed
dir=$(dirname "$filepath")
if [ ! -d "$dir" ]; then
    mkdir -p "$dir" || {
        echo "Error: Could not create directory '$dir'." >&2
        exit 1
    }
fi

printf '%s' "$content" > "$filepath"
echo "Successfully wrote to '$filepath'."
