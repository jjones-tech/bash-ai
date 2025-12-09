#!/bin/bash
# Input: JSON parameters via $1
# Output: Result to stdout

PARAMS="$1"
message=$(echo "$PARAMS" | jq -r '.message')

if [ -z "$message" ] || [ "$message" == "null" ]; then
    echo "Error: 'message' parameter is required." >&2
    exit 1
fi

echo "pong: $message"
