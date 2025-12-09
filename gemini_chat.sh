#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/input.sh"
source "$SCRIPT_DIR/lib/system.sh"
source "$SCRIPT_DIR/lib/context.sh"
source "$SCRIPT_DIR/lib/tools.sh"

DEBUG="${GEMINI_DEBUG:-false}"
AGENT_RUNNING=false

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BG_RED='\033[41m'
NC='\033[0m'

debug() {
    [ "$DEBUG" = "true" ] && echo -e "${MAGENTA}[DEBUG] $1${NC}" >&2
}

show_status() {
    local msg="$1"
    local cols=$(tput cols)
    local padded=$(printf "%-${cols}s" " $msg ")
    echo -ne "\r${BG_RED}${WHITE}${padded}${NC}" >&2
}

clear_status() {
    local cols=$(tput cols)
    local blank=$(printf "%-${cols}s" "")
    echo -ne "\r${blank}\r" >&2
}

handle_interrupt() {
    if [ "$AGENT_RUNNING" = true ]; then
        clear_status
        echo -e "\n${RED}[Stopped by user]${NC}" >&2
        AGENT_RUNNING=false
        return 0
    else
        echo -e "\n${GREEN}Goodbye!${NC}"
        exit 0
    fi
}

trap handle_interrupt SIGINT

get_gemini_key() {
    security find-generic-password -a "$USER" -s "gemini-api-key" -w 2>/dev/null
}

GEMINI_API_KEY=$(get_gemini_key)
MODEL="${GEMINI_MODEL:-gemini-2.0-flash}"
MAX_TOOL_ITERATIONS=10

if [ -z "$GEMINI_API_KEY" ]; then
    echo -e "${RED}Error: Gemini API key not found.${NC}" >&2
    exit 1
fi

extract_text_response() {
    local response="$1"
    echo "$response" | jq -r '[.candidates[0].content.parts[] | select(.text) | .text] | join("")' 2>/dev/null
}

extract_function_call() {
    local response="$1"
    echo "$response" | jq -c '.candidates[0].content.parts[] | select(.functionCall) | .functionCall' 2>/dev/null | head -1
}

gemini_search() {
    local query="$1"
    local payload
    payload=$(jq -n --arg q "$query" '{
        "contents": [{"role": "user", "parts": [{"text": $q}]}],
        "tools": [{"google_search": {}}]
    }')
    
    local response
    response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
        -H 'Content-Type: application/json' -d "$payload")
    
    local error=$(echo "$response" | jq -r '.error.message // empty')
    if [ -n "$error" ]; then
        echo "Search error: $error" >&2
        return 1
    fi
    
    extract_text_response "$response"
}

gemini_send() {
    local user_input="$1"
    init_context
    add_to_context "user" "$user_input"
    local iteration=0
    AGENT_RUNNING=true
    
    while [ $iteration -lt $MAX_TOOL_ITERATIONS ] && [ "$AGENT_RUNNING" = true ]; do
        debug "Iteration $iteration"
        local system_instruction=$(build_system_instruction "$TOOLS_DIR")
        local contents=$(get_contents_json)
        local tools=$(build_tools_json "false" "true")
        local payload
        
        if [ "$tools" = "[]" ]; then
            payload=$(jq -n --arg sys "$system_instruction" --argjson contents "$contents" '{"system_instruction": {"parts": [{"text": $sys}]}, "contents": $contents}')
        else
            payload=$(jq -n --arg sys "$system_instruction" --argjson contents "$contents" --argjson tools "$tools" '{"system_instruction": {"parts": [{"text": $sys}]}, "contents": $contents, "tools": $tools}')
        fi
        
        show_status "Ctrl+C to stop agent"
        debug "Sending API request..."
        local response
        response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
            -H 'Content-Type: application/json' -d "$payload")
        clear_status
        
        [ "$AGENT_RUNNING" = false ] && return 1
        
        local error=$(echo "$response" | jq -r '.error.message // empty')
        if [ -n "$error" ]; then
            echo -e "${RED}API Error: $error${NC}" >&2
            AGENT_RUNNING=false
            return 1
        fi
        
        local function_call=$(extract_function_call "$response")
        debug "Function call: $function_call"
        
        if [ -n "$function_call" ] && [ "$function_call" != "null" ]; then
            local tool_name=$(echo "$function_call" | jq -r '.name')
            local tool_args=$(echo "$function_call" | jq -c '.args')
            echo -e "${YELLOW}[Calling: $tool_name]${NC}" >&2
            add_function_call_to_context "$tool_name" "$tool_args"
            
            debug "Executing tool: $tool_name with args: $tool_args"
            show_status "Running: $tool_name | Ctrl+C to stop"
            local tool_result
            tool_result=$(execute_tool "$tool_name" "$tool_args")
            clear_status
            debug "Tool result length: ${#tool_result}"
            
            [ "$AGENT_RUNNING" = false ] && return 1
            
            echo -e "${YELLOW}[Done]${NC}" >&2
            add_function_response_to_context "$tool_name" "$tool_result"
            debug "Added function response to context"
            
            ((iteration++))
            continue
        fi
        
        local text_response=$(extract_text_response "$response")
        debug "Text response length: ${#text_response}"
        
        if [ -n "$text_response" ]; then
            add_to_context "model" "$text_response"
            printf '%s\n' "$text_response"
        else
            echo -e "${RED}Error: Could not parse response.${NC}" >&2
            echo "$response" | jq . >&2
        fi
        AGENT_RUNNING=false
        return 0
    done
    
    if [ "$AGENT_RUNNING" = true ]; then
        echo -e "${RED}Error: Max tool iterations reached.${NC}" >&2
    fi
    AGENT_RUNNING=false
    return 1
}

gemini_chat() {
    if has_context; then
        echo -e "${YELLOW}Previous conversation found.${NC}"
        echo -ne "Start new session? (y/n) [n]: "
        read answer
        [[ "$answer" =~ ^[yY] ]] && clear_context && echo -e "${GREEN}Context cleared.${NC}"
    else
        init_context
    fi

    echo ""
    echo -e "${BLUE}Gemini Chat${NC} (Model: $MODEL)"
    list_tools
    echo ""
    echo -e "${MAGENTA}Commands: exit, clear, history, tools, help${NC}"
    echo -e "${MAGENTA}Multi-line: Type ${CYAN}${INPUT_START_DELIM}${MAGENTA} Enter, paste, then ${CYAN}${INPUT_END_DELIM}${MAGENTA} Enter${NC}"
    echo "-----------------------------------------------------------"

    while true; do
        echo -ne "${CYAN}You: ${NC}"
        local input
        input=$(read_user_input) || continue
        [ -z "$input" ] && continue

        if is_command "$input" "exit" || is_command "$input" "quit"; then
            echo -e "${GREEN}Goodbye!${NC}"
            break
        elif is_command "$input" "clear" || is_command "$input" "reset"; then
            clear_context
            echo -e "${GREEN}Context cleared.${NC}"
            continue
        elif is_command "$input" "history"; then
            show_history
            continue
        elif is_command "$input" "tools"; then
            list_tools
            continue
        elif is_command "$input" "help"; then
            show_input_help
            continue
        fi

        if [[ "$input" == *$'\n'* ]]; then
            local line_count=$(echo "$input" | wc -l | tr -d ' ')
            echo -e "${YELLOW}[Received ${line_count} lines]${NC}"
        fi

        echo -ne "${GREEN}Gemini: ${NC}"
        gemini_send "$input"
        echo ""
    done
}

case "${1:-}" in
    --search)
        shift
        gemini_search "$*"
        ;;
    *)
        gemini_chat
        ;;
esac
