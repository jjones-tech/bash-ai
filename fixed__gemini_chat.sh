#!/bin/bash

get_gemini_key() {
    security find-generic-password -a "$USER" -s "gemini-api-key" -w 2>/dev/null
}

GEMINI_API_KEY=$(get_gemini_key)
MODEL="${GEMINI_MODEL:-gemini-2.0-flash}"
CONTEXT_FILE="${GEMINI_CONTEXT_FILE:-$HOME/.gemini_context}"
TOOLS_DIR="${GEMINI_TOOLS_DIR:-$HOME/scripts/gemini/tools}"
USE_SEARCH="${GEMINI_USE_SEARCH:-false}"
USE_TOOLS="${GEMINI_USE_TOOLS:-true}"
MAX_TOOL_ITERATIONS=5

if [ -z "$GEMINI_API_KEY" ]; then
    echo "Error: Gemini API key not found. Please set it in your macOS Keychain." >&2
    exit 1
fi

json_escape() {
    local str="$1"
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

init_context() {
    [ ! -f "$CONTEXT_FILE" ] && echo '[]' > "$CONTEXT_FILE"
    if ! jq empty "$CONTEXT_FILE" 2>/dev/null; then
        echo '[]' > "$CONTEXT_FILE"
    fi
}

has_context() {
    [ -f "$CONTEXT_FILE" ] && [ -s "$CONTEXT_FILE" ] && [ "$(jq length "$CONTEXT_FILE")" -gt 0 ]
}

add_to_context() {
    local role="$1"
    local content="$2"
    local tmp_file=$(mktemp)
    jq --arg role "$role" --arg text "$content" \
        '. + [{\"role\": "$role", \"parts\": [{\"text\": "$content"}]}]' \
        "$CONTEXT_FILE" > "$tmp_file" && mv "$tmp_file" "$CONTEXT_FILE"
}

add_function_call_to_context() {
    local name="$1"
    local args="$2"
    local tmp_file=$(mktemp)
    jq --arg name "$name" --argjson args "$args" \
        '. + [{\"role\": \"model\", \"parts\": [{\"functionCall\": {\"name\": "$name", \"args\": $args}}]}]' \
        "$CONTEXT_FILE" > "$tmp_file" && mv "$tmp_file" "$CONTEXT_FILE"
}

add_function_response_to_context() {
    local name="$1"
    local response="$2"
    local tmp_file=$(mktemp)
    local escaped_response=$(json_escape "$response")
    jq --arg name "$name" --arg resp "$escaped_response" \
        '. + [{\"role\": \"user\", \"parts\": [{\"functionResponse\": {\"name\": "$name", \"response\": {\"result\": $resp}}}]}]' \
        "$CONTEXT_FILE" > "$tmp_file" && mv "$tmp_file" "$CONTEXT_FILE"
}

get_contents_json() {
    cat "$CONTEXT_FILE"
}

# Discover and load all tools from TOOLS_DIR
discover_tools() {
    local declarations="[]"
    
    if [ ! -d "$TOOLS_DIR" ]; then
        echo "[]"
        return
    fi
    
    for tool_dir in "$TOOLS_DIR"/*/; do
        [ ! -d "$tool_dir" ] && continue
        local manifest="$tool_dir/manifest.json"
        if [ -f "$manifest" ]; then
            local tool_decl=$(cat "$manifest")
            declarations=$(echo "$declarations" | jq --argjson tool "$tool_decl" '. + [$tool]')
        fi
    done
    
    echo "$declarations"
}

# List available tools
list_tools() {
    echo "Available tools in $TOOLS_DIR:"
    echo ""
    for tool_dir in "$TOOLS_DIR"/*/; do
        [ ! -d "$tool_dir" ] && continue
        local manifest="$tool_dir/manifest.json"
        if [ -f "$manifest" ]; then
            local name=$(jq -r '.name' "$manifest")
            local desc=$(jq -r '.description' "$manifest")
            printf "  %-15s %s\n" "$name" "$desc"
        fi
    done
}

build_tools_json() {
    local tools="[]"

    # Add Google Search if enabled
    if [ "$USE_SEARCH" = "true" ]; then
        tools=$(echo "$tools" | jq '. + [{\"google_search\": {}}]')
    fi

    # Add function declarations from tools directory
    if [ "$USE_TOOLS" = "true" ]; then
        local declarations=$(discover_tools)
        if [ -n "$declarations" ] && [ "$declarations" != "[]" ]; then
            tools=$(echo "$tools" | jq --argjson decls "$declarations" '. + [{\"functionDeclarations\": $decls}]')
        fi
    fi

    echo "$tools"
}

extract_text_response() {
    local response="$1"
    echo "$response" | jq -r '.candidates[0].content.parts[] | select(.text) | .text' 2>/dev/null | head -1
}

extract_function_call() {
    local response="$1"
    echo "$response" | jq -c '.candidates[0].content.parts[] | select(.functionCall) | .functionCall' 2>/dev/null | head -1
}

# Execute a tool by name
execute_tool() {
    local tool_name="$1"
    local json_params="$2"
    local tool_script="$TOOLS_DIR/$tool_name/run.sh"
    
    if [ ! -x "$tool_script" ]; then
        echo "Error: Tool '$tool_name' not found or not executable." >&2
        return 1
    fi
    
    bash "$tool_script" "$json_params"
}

gemini_send() {
    local user_input="$1"
    init_context
    add_to_context "user" "$user_input"
    
    local iteration=0
    
    while [ $iteration -lt $MAX_TOOL_ITERATIONS ]; do
        local contents=$(get_contents_json)
        local tools=$(build_tools_json)
        
        local payload
        if [ "$tools" = "[]" ]; then
            payload=$(jq -n --argjson contents "$contents" '{\"contents\": $contents}')
        else
            payload=$(jq -n --argjson contents "$contents" --argjson tools "$tools" \
                '{\"contents\": $contents, \"tools\": $tools}')
        fi
        
        local response
        response=$(curl -s "https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent?key=${GEMINI_API_KEY}" \
            -H 'Content-Type: application/json' \
            -d "$payload")
        
        # Check for errors
        local error=$(echo "$response" | jq -r '.error.message // empty')
        if [ -n "$error" ]; then
            echo "API Error: $error" >&2
            return 1
        fi
        
        # Check for function call
        local function_call=$(extract_function_call "$response")
        
        if [ -n "$function_call" ] && [ "$function_call" != "null" ]; then
            local tool_name=$(echo "$function_call" | jq -r '.name')
            local tool_args=$(echo "$function_call" | jq -c '.args')
            
            echo "[Calling tool: $tool_name]" >&2
            
            # Add function call to context
            add_function_call_to_context "$tool_name" "$tool_args"
            
            # Execute the tool
            local tool_result
            tool_result=$(execute_tool "$tool_name" "$tool_args")
            
            echo "[Tool result: $tool_result]" >&2
            
            # Add function response to context
            add_function_response_to_context "$tool_name" "$tool_result"
            
            ((iteration++))
            continue
        fi
        
        # No function call, extract text response
        local text_response=$(extract_text_response "$response")
        
        if [ -n "$text_response" ]; then
            add_to_context "model" "$text_response"
            # Ensure the text response is printed to stdout, even if it contains special characters
            printf '%s\n' "$text_response"
        else
            echo "Error: Could not parse response." >&2
            echo "$response" | jq . >&2
        fi
        
        return 0
    done
    
    echo "Error: Max tool iterations reached." >&2
    return 1
}

gemini_clear() {
    echo '[]' > "$CONTEXT_FILE"
    echo "Context cleared."
}

gemini_history() {
    [ ! -f "$CONTEXT_FILE" ] && return
    jq -r '.[] | 
        if .role == \"user\" then
            if .parts[0].text then \"You: \" + .parts[0].text
            elif .parts[0].functionResponse then \"Tool Response: \" + (.parts[0].functionResponse.name) + \" -> \" + (.parts[0].functionResponse.response.result // \"ok\")
            else empty end
        elif .role == \"model\" then
            if .parts[0].text then \"Gemini: \" + .parts[0].text
            elif .parts[0].functionCall then \"Tool Call: \" + .parts[0].functionCall.name + \"(\" + (.parts[0].functionCall.args | tostring) + \")\"
            else empty end
        else empty end
    ' "$CONTEXT_FILE" 2>/dev/null
}

gemini_chat() {
    if has_context; then
        echo "Previous conversation found."
        echo -n "Start new session? (y/n) [n]: "
        read answer
        case "$answer" in
            y|Y|yes|Yes|YES) gemini_clear ;;
        esac
    else
        init_context
    fi
    
    echo ""
    echo "Gemini Chat (Model: $MODEL)"
    echo "  Google Search: $([ "$USE_SEARCH" = "true" ] && echo "ON" || echo "OFF")"
    echo "  Tool Calling:  $([ "$USE_TOOLS" = "true" ] && echo "ON" || echo "OFF")"
    echo ""
    list_tools
    echo ""
    echo "Commands: exit, clear, history, tools"
    echo "Paste mode: Type 'paste', then paste text, then type 'END' on its own line"
    echo "-----------------------------------------------------------"
    
    while true; do
        echo -n "You: "
        read -r user_input
        case "$user_input" in
            exit|quit)
                echo "Goodbye!"
                break
                ;;
            clear|reset)
                gemini_clear
                continue
                ;;
            history)
                gemini_history
                continue
                ;;
            tools)
                list_tools
                continue
                ;;
            paste)
                echo "Paste your text, then type 'END' on its own line:"
                user_input=""
                while IFS= read -r line; do
                    [ "$line" = "END" ] && break
                    user_input="${user_input}${line}"$'\n'
                done
                echo -n "Gemini: "
                gemini_send "$user_input"
                echo ""
                continue
                ;;
            "")
                continue
                ;;
            *)
                echo -n "Gemini: "
                gemini_send "$user_input"
                echo ""
                ;;
        esac
    done
}

# Allow sourcing or direct execution
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    gemini_chat
fi