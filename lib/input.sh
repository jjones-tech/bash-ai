#!/bin/bash
# input.sh - Modular input handling for bash
# Supports single-line and multi-line input

# Multi-line mode: "delimiter" (default) or "blankline"
INPUT_MODE="${INPUT_MODE:-delimiter}"
INPUT_START_DELIM="${INPUT_START_DELIM:-<<<}"
INPUT_END_DELIM="${INPUT_END_DELIM:->>>}"

# Read input - handles both single and multi-line
# Returns via stdout, status 1 if empty/cancelled
read_user_input() {
    local first_line
    local full_input
    local line

    # Read the first line
    IFS= read -r first_line || return 1
    
    # Check for empty
    [ -z "$first_line" ] && return 1

    # Check for multi-line start delimiter
    if [[ "$first_line" == "$INPUT_START_DELIM" ]]; then
        full_input=""
        while IFS= read -r line; do
            # Check for end delimiter
            [[ "$line" == "$INPUT_END_DELIM" ]] && break
            if [ -z "$full_input" ]; then
                full_input="$line"
            else
                full_input="${full_input}"$'\n'"${line}"
            fi
        done
        printf '%s' "$full_input"
        return 0
    fi

    # Check if line ends with backslash (line continuation)
    if [[ "$first_line" == *'\' ]]; then
        # Remove trailing backslash
        full_input="${first_line%\\}"
        while IFS= read -r line; do
            if [[ "$line" == *'\' ]]; then
                full_input="${full_input}"$'\n'"${line%\\}"
            else
                full_input="${full_input}"$'\n'"${line}"
                break
            fi
        done
        printf '%s' "$full_input"
        return 0
    fi

    # Single line input
    printf '%s' "$first_line"
    return 0
}

# Show input help
show_input_help() {
    local cyan='\033[0;36m'
    local nc='\033[0m'
    echo -e "${cyan}Input modes:${nc}"
    echo "  Single line: Just type and press Enter"
    echo "  Multi-line:  Type '$INPUT_START_DELIM' then Enter, paste content, type '$INPUT_END_DELIM' then Enter"
    echo "  Continuation: End line with \\ to continue on next line"
}

# Check if input is a command (single line, no spaces at start)
is_command() {
    local input="$1"
    local cmd="$2"
    [[ "$input" == "$cmd" ]] && [[ "$input" != *$'\n'* ]]
}
