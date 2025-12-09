#!/bin/bash
TOOLS_DIR="${GEMINI_TOOLS_DIR:-$HOME/scripts/gemini/tools}"

for tool_dir in "$TOOLS_DIR"/*/; do
    [ ! -d "$tool_dir" ] && continue
    manifest="$tool_dir/manifest.json"
    if [ -f "$manifest" ]; then
        name=$(jq -r '.name' "$manifest")
        desc=$(jq -r '.description' "$manifest")
        echo "- $name: $desc"
    fi
done
