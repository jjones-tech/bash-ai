#!/bin/bash
# Tool management for Gemini chat

TOOLS_DIR="${GEMINI_TOOLS_DIR:-$HOME/scripts/gemini/tools}"

discover_tools() {
    local declarations="[]"
    [ ! -d "$TOOLS_DIR" ] && echo "[]" && return
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

list_tools() {
    local blue='\033[0;34m'
    local cyan='\033[0;36m'
    local nc='\033[0m'
    echo -e "${blue}Available tools:${nc}"
    for tool_dir in "$TOOLS_DIR"/*/; do
        [ ! -d "$tool_dir" ] && continue
        local manifest="$tool_dir/manifest.json"
        if [ -f "$manifest" ]; then
            local name=$(jq -r '.name' "$manifest")
            local desc=$(jq -r '.description' "$manifest")
            printf "  ${cyan}%-15s${nc} %s\n" "$name" "$desc"
        fi
    done
}

build_tools_json() {
    local use_search="${1:-false}"
    local use_tools="${2:-true}"
    local tools="[]"
    if [ "$use_search" = "true" ]; then
        tools=$(echo "$tools" | jq '. + [{"google_search": {}}]')
    fi
    if [ "$use_tools" = "true" ]; then
        local declarations=$(discover_tools)
        if [ -n "$declarations" ] && [ "$declarations" != "[]" ]; then
            tools=$(echo "$tools" | jq --argjson decls "$declarations" '. + [{"functionDeclarations": $decls}]')
        fi
    fi
    echo "$tools"
}

execute_tool() {
    local tool_name="$1"
    local json_params="$2"
    local tool_script="$TOOLS_DIR/$tool_name/run.sh"
    [ ! -x "$tool_script" ] && echo "Error: Tool '$tool_name' not found." >&2 && return 1
    bash "$tool_script" "$json_params"
}
