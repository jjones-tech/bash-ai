#!/bin/bash

read_file() {
    local filepath="$1"
    if [[ "$filepath" == ".." ]] || [[ "$filepath" == "/" ]] && [[ "$filepath" != "$HOME/"* ]] && [[ "$filepath" != "$HOME" ]]; then
        echo "Error: Invalid file path specified." >&2
        return 1
    fi
    if [ -f "$filepath" ]; then
        cat "$filepath"
    else
        echo "Error: File not found at '$filepath'." >&2
        return 1
    fi
}

write_file() {
    local filepath="$1"
    local content="$2"
    if [[ "$filepath" == ".." ]] || [[ "$filepath" == "/" ]] && [[ "$filepath" != "$HOME/"* ]] && [[ "$filepath" != "$HOME" ]]; then
        echo "Error: Invalid file path specified." >&2
        return 1
    fi
    local dir
    dir=$(dirname "$filepath")
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir" || {
            echo "Error: Could not create directory '$dir'." >&2
            return 1
        }
    fi
    echo "$content" > "$filepath"
    echo "Successfully wrote to '$filepath'."
}

ping_pong() {
    local message="$1"
    echo "pong: $message"
}

if [ $# -lt 2 ]; then
    echo "Usage: $0 <tool_name> <json_parameters>" >&2
    exit 1
fi

TOOL_NAME="$1"
JSON_PARAMS="$2"

case "$TOOL_NAME" in
    "read_file")
        filepath=$(echo "$JSON_PARAMS" | jq -r '.filepath')
        if [ -z "$filepath" ] || [ "$filepath" == "null" ]; then
            echo "Error: 'filepath' parameter is missing for read_file." >&2
            exit 1
        fi
        read_file "$filepath"
        ;;
    "write_file")
        filepath=$(echo "$JSON_PARAMS" | jq -r '.filepath')
        content=$(echo "$JSON_PARAMS" | jq -r '.content')
        if [ -z "$filepath" ] || [ "$filepath" == "null" ]; then
            echo "Error: 'filepath' parameter is missing for write_file." >&2
            exit 1
        fi
        if [ -z "$content" ] && [ "$content" != "null" ]; then
            echo "Error: 'content' parameter is missing or empty for write_file." >&2
            exit 1
        fi
        write_file "$filepath" "$content"
        ;;
    "ping_pong")
        message=$(echo "$JSON_PARAMS" | jq -r '.message')
        if [ -z "$message" ] || [ "$message" == "null" ]; then
            echo "Error: 'message' parameter is missing for ping_pong." >&2
            exit 1
        fi
        ping_pong "$message"
        ;;
    *)
        echo "Error: Unknown tool '$TOOL_NAME'." >&2
        exit 1
        ;;
esac

exit 0
