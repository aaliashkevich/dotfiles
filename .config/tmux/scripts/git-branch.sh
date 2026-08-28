#!/usr/bin/env sh
# tmux status-left segment: current git branch for the active pane's directory.
# Prints nothing outside a repo, so the segment simply disappears.
# Usage: git-branch.sh <dir>

dir="${1:-$PWD}"

branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null) || exit 0
[ -n "$branch" ] || exit 0

printf ' %s' "$branch"
