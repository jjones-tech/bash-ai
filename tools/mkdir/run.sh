#!/bin/bash
PARAMS="$1"

path=$(echo "$PARAMS" | jq -r '.path // empty')

if [ -z "$path" ]; then
    echo "Error: path is required" >&2
    exit 1
fi

if [[ "$path" == *".."* ]] && [[ "$path" != "$HOME"* ]]; then
    echo "Error: Invalid path." >&2
    exit 1
fi

if [ -d "$path" ]; then
    echo "Directory already exists: $path"
    exit 0
fi

mkdir -p "$path" && echo "Created directory: $path"
