#!/bin/bash
# Claude Code statusLine
# Segments (left to right): model/effort | context | caveman
# Reads Claude Code's statusLine JSON payload on stdin.

input=$(cat)

DIM=$(printf '\033[2m')
RESET=$(printf '\033[0m')
SEP="${DIM} | ${RESET}"

# --- 1. model: display name + reasoning effort in brackets ---
model_seg=$(printf '%s' "$input" | jq -r '
  (.model.display_name // .model.id // "") as $name
  | (.effort.level // "") as $eff
  | if $name == "" then ""
    elif $eff == "" then $name
    else "\($name) (\($eff))" end')

# --- 2. context: exact token counts, e.g. "context 125k/1000k" ---
context_seg=""
ctx_used=$(printf '%s' "$input" | jq -r '((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)) | floor')
ctx_max=$(printf '%s' "$input" | jq -r '.context_window.context_window_size // empty')
if [ -n "$ctx_max" ] && [ "$ctx_max" != "0" ]; then
  used_k=$(( (ctx_used + 500) / 1000 ))
  max_k=$(( (ctx_max + 500) / 1000 ))
  context_seg="context ${used_k}k/${max_k}k"
fi

# --- 3. caveman: badge from the caveman plugin's statusline script ---
# The plugin cache is keyed by commit hash, which differs per machine and changes
# on every plugin update, so glob it rather than pinning one.
caveman_seg=""
for f in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/caveman/caveman/*/src/hooks/caveman-statusline.sh; do
  [ -f "$f" ] && [ ! -L "$f" ] || continue
  caveman_seg=$(bash "$f" 2>/dev/null)
  break
done

# --- assemble ---
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
add_segment "$context_seg"
add_segment "$caveman_seg"

printf '%s\n' "$out"
