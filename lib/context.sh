#!/bin/bash
# Context management for Gemini chat

CONTEXT_FILE="${GEMINI_CONTEXT_FILE:-$HOME/.gemini_context}"

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

clear_context() {
    echo '[]' > "$CONTEXT_FILE"
}

add_to_context() {
    local role="$1"
    local content="$2"
    local tmp_file=$(mktemp)
    jq --arg role "$role" --arg text "$content" \
        '. + [{"role": $role, "parts": [{"text": $text}]}]' \
        "$CONTEXT_FILE" > "$tmp_file" && mv "$tmp_file" "$CONTEXT_FILE"
}

add_function_call_to_context() {
    local name="$1"
    local args="$2"
    local tmp_file=$(mktemp)
    jq --arg name "$name" --argjson args "$args" \
        '. + [{"role": "model", "parts": [{"functionCall": {"name": $name, "args": $args}}]}]' \
        "$CONTEXT_FILE" > "$tmp_file" && mv "$tmp_file" "$CONTEXT_FILE"
}

add_function_response_to_context() {
    local name="$1"
    local response="$2"
    local tmp_file=$(mktemp)
    local escaped_response=$(json_escape "$response")
    jq --arg name "$name" --arg resp "$escaped_response" \
        '. + [{"role": "user", "parts": [{"functionResponse": {"name": $name, "response": {"result": $resp}}}]}]' \
        "$CONTEXT_FILE" > "$tmp_file" && mv "$tmp_file" "$CONTEXT_FILE"
}

get_contents_json() {
    cat "$CONTEXT_FILE"
}

show_history() {
    [ ! -f "$CONTEXT_FILE" ] && return
    jq -r '.[] | if .role == "user" then if .parts[0].text then "You: " + .parts[0].text elif .parts[0].functionResponse then "Tool: " + .parts[0].functionResponse.name else empty end elif .role == "model" then if .parts[0].text then "Gemini: " + .parts[0].text elif .parts[0].functionCall then "Call: " + .parts[0].functionCall.name else empty end else empty end' "$CONTEXT_FILE" 2>/dev/null
}
