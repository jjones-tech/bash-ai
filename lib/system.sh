#!/bin/bash
# System instruction builder for Gemini chat

build_system_instruction() {
    local tools_dir="${1:-$TOOLS_DIR}"
    local tools_list=$(get_tool_list_for_prompt "$tools_dir")
    local p=""
    p="${p}You are a helpful assistant with filesystem tools running in Bash."
    p="${p}"$'\n\n'
    p="${p}TOOLS:"$'\n'
    p="${p}${tools_list}"$'\n'
    p="${p}RULES:"$'\n'
    p="${p}1. When user asks about your tools/capabilities, answer directly without calling tools."$'\n'
    p="${p}2. BE PROACTIVE: If you need info to complete a task, use tools to get it - dont ask the user."$'\n'
    p="${p}3. If path is unclear, use ls or tree first to find it, then proceed."$'\n'
    p="${p}4. After tool results, summarize for the user."$'\n'
    p="${p}5. Do NOT output shell commands as your response."$'\n'
    p="${p}6. Chain multiple tools for complex tasks without asking."$'\n'
    p="${p}7. To read files in a folder: ls the folder first, then read each file (not directory)."$'\n'
    p="${p}8. In ls output, entries ending with / are directories, others are files."$'\n'
    printf '%s' "$p"
}

get_tool_list_for_prompt() {
    local tools_dir="$1"
    local tool_list=""
    [ ! -d "$tools_dir" ] && return
    for tool_dir in "$tools_dir"/*/; do
        [ ! -d "$tool_dir" ] && continue
        local manifest="$tool_dir/manifest.json"
        if [ -f "$manifest" ]; then
            local name=$(jq -r '.name' "$manifest")
            local desc=$(jq -r '.description' "$manifest")
            tool_list="${tool_list}- ${name}: ${desc}"$'\n'
        fi
    done
    printf '%s' "$tool_list"
}
