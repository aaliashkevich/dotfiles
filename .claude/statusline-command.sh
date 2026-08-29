#!/bin/bash

input=$(cat)

DIM=$(printf '\033[2m')
RESET=$(printf '\033[0m')
SEP="${DIM} | ${RESET}"

model_name=$(printf '%s' "$input" | jq -r '.model.display_name // .model.id // ""')
effort=$(printf '%s' "$input" | jq -r '.effort.level // ""')

model_seg=""
[ -n "$model_name" ] && model_seg="Model: ${model_name}"
effort_seg=""
[ -n "$effort" ] && effort_seg="Effort: ${effort}"

ctx_used=$(printf '%s' "$input" | jq -r '((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)) | floor')
context_seg="Context: $(awk -v n="$ctx_used" 'BEGIN { printf "%.1fk", n / 1000 }')"

caveman_seg=""
flag="${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active"
if [ -f "$flag" ] && [ ! -L "$flag" ]; then
    mode=$(head -c 64 "$flag" 2>/dev/null | tr -d '\n\r' | tr '[:upper:]' '[:lower:]')
    mode=$(printf '%s' "$mode" | tr -cd 'a-z0-9-')
    case "$mode" in
    off | lite | full | ultra | wenyan-lite | wenyan | wenyan-full | wenyan-ultra | commit | review | compress)
        caveman_seg="Caveman: ${mode}"
        ;;
    esac
fi

out=""
add_segment() {
    local seg="$1"
    [ -z "$seg" ] && return
    if [ -z "$out" ]; then
        out="$seg"
    else
        out="${out}${SEP}${seg}"
    fi
}
add_segment "$model_seg"
add_segment "$effort_seg"
add_segment "$context_seg"
add_segment "$caveman_seg"

printf '%s\n' "$out"
