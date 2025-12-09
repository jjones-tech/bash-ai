#!/bin/bash

# Pure bash markdown formatter for terminal output
# Handles: headers, bold, italic, inline code, bullets, code blocks

# ANSI codes
BOLD=$'\033[1m'
DIM=$'\033[2m'
ITALIC=$'\033[3m'
RESET=$'\033[0m'
CYAN=$'\033[36m'
YELLOW=$'\033[33m'
GREEN=$'\033[32m'

in_code_block=false

while IFS= read -r line || [[ -n "$line" ]]; do
    
    # Code block toggle
    if [[ "$line" =~ ^\`\`\` ]]; then
        if [ "$in_code_block" = true ]; then
            in_code_block=false
            echo "${RESET}"
        else
            in_code_block=true
            echo "${DIM}"
        fi
        continue
    fi
    
    # Inside code block - print as-is with dim
    if [ "$in_code_block" = true ]; then
        echo "${DIM}  $line${RESET}"
        continue
    fi
    
    # Headers
    if [[ "$line" =~ ^###[[:space:]]+(.*) ]]; then
        echo "${BOLD}${YELLOW}${BASH_REMATCH[1]}${RESET}"
        continue
    fi
    if [[ "$line" =~ ^##[[:space:]]+(.*) ]]; then
        echo "${BOLD}${YELLOW}${BASH_REMATCH[1]}${RESET}"
        continue
    fi
    if [[ "$line" =~ ^#[[:space:]]+(.*) ]]; then
        echo "${BOLD}${YELLOW}${BASH_REMATCH[1]}${RESET}"
        continue
    fi
    
    # Bullet points
    line="${line/#\*   /  • }"
    line="${line/#-   /  • }"
    line="${line/#\* /  • }"
    line="${line/#- /  • }"
    
    # Process inline formatting character by character
    result=""
    i=0
    len=${#line}
    
    while [ $i -lt $len ]; do
        char="${line:$i:1}"
        next="${line:$((i+1)):1}"
        
        # Bold **text**
        if [ "$char" = '*' ] && [ "$next" = '*' ]; then
            # Find closing **
            rest="${line:$((i+2))}"
            if [[ "$rest" =~ ^([^\*]+)\*\* ]]; then
                result+="${BOLD}${BASH_REMATCH[1]}${RESET}"
                ((i += 4 + ${#BASH_REMATCH[1]}))
                continue
            fi
        fi
        
        # Inline code `text`
        if [ "$char" = '`' ]; then
            rest="${line:$((i+1))}"
            if [[ "$rest" =~ ^([^\`]+)\` ]]; then
                result+="${CYAN}${BASH_REMATCH[1]}${RESET}"
                ((i += 2 + ${#BASH_REMATCH[1]}))
                continue
            fi
        fi
        
        # Italic *text* (single asterisk, not double)
        if [ "$char" = '*' ] && [ "$next" != '*' ]; then
            rest="${line:$((i+1))}"
            if [[ "$rest" =~ ^([^\*]+)\* ]]; then
                result+="${ITALIC}${BASH_REMATCH[1]}${RESET}"
                ((i += 2 + ${#BASH_REMATCH[1]}))
                continue
            fi
        fi
        
        result+="$char"
        ((i++))
    done
    
    echo -e "$result"
done
