#!/bin/bash
PARAMS="$1"

path=$(echo "$PARAMS" | jq -r '.path // "."')
show_all=$(echo "$PARAMS" | jq -r '.all // false')
long_format=$(echo "$PARAMS" | jq -r '.long // false')

if [[ "$path" == *".."* ]] && [[ "$path" != "$HOME"* ]]; then
    echo "Error: Invalid path." >&2
    exit 1
fi

if [ ! -d "$path" ]; then
    echo "Error: Directory not found: $path" >&2
    exit 1
fi

ls_opts="F"
[ "$show_all" = "true" ] && ls_opts="${ls_opts}a"
[ "$long_format" = "true" ] && ls_opts="${ls_opts}l"

ls -${ls_opts} "$path"
