#!/bin/bash
PARAMS="$1"

path=$(echo "$PARAMS" | jq -r '.path // "."')
max_depth=$(echo "$PARAMS" | jq -r '.max_depth // 3')
show_hidden=$(echo "$PARAMS" | jq -r '.show_hidden // false')
dirs_only=$(echo "$PARAMS" | jq -r '.dirs_only // false')

if [[ "$path" == *".."* ]] && [[ "$path" != "$HOME"* ]]; then
    echo "Error: Invalid path." >&2
    exit 1
fi

if [ ! -d "$path" ]; then
    echo "Error: Directory not found: $path" >&2
    exit 1
fi

# Check if tree command exists
if command -v tree &>/dev/null; then
    opts="-L $max_depth"
    [ "$show_hidden" = "true" ] && opts="$opts -a"
    [ "$dirs_only" = "true" ] && opts="$opts -d"
    tree $opts "$path"
else
    # Fallback using find
    print_tree() {
        local dir="$1"
        local prefix="$2"
        local depth="$3"
        local max="$4"
        
        [ "$depth" -gt "$max" ] && return
        
        local items=()
        if [ "$show_hidden" = "true" ]; then
            while IFS= read -r -d '' item; do
                items+=("$item")
            done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0 | sort -z)
        else
            while IFS= read -r -d '' item; do
                [[ "$(basename "$item")" == .* ]] && continue
                items+=("$item")
            done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0 | sort -z)
        fi
        
        local count=${#items[@]}
        local i=0
        for item in "${items[@]}"; do
            ((i++))
            local name=$(basename "$item")
            local connector="├── "
            local new_prefix="${prefix}│   "
            [ "$i" -eq "$count" ] && connector="└── " && new_prefix="${prefix}    "
            
            if [ -d "$item" ]; then
                echo "${prefix}${connector}${name}/"
                print_tree "$item" "$new_prefix" $((depth + 1)) "$max"
            elif [ "$dirs_only" != "true" ]; then
                echo "${prefix}${connector}${name}"
            fi
        done
    }
    
    echo "$path"
    print_tree "$path" "" 1 "$max_depth"
fi
