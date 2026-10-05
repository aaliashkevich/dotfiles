#!/bin/sh
# Directory source for sesh's picker, wired in via [frecency] list_command in
# sesh.toml. sesh execs this directly with exec.Command — no shell — so this
# must be an executable file, not a pipeline in the config. It reads one path
# per line; a leading numeric score is optional and omitted here, so the
# emitted order is the order shown.
#
# Must always exit 0: shell.ListCmd returns the command's error, so a non-zero
# exit makes `sesh list` and the picker fail outright rather than degrade.

printf '%s\n' "$HOME"
find "$HOME/projects" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort -f

# Worktrees, so one whose tmux session was killed is still reachable
# from the picker. Live sessions dedupe against these under sesh's -d.
{
    find "$HOME/projects" -mindepth 3 -maxdepth 3 -type d -path '*/.worktrees/*'
    find "$HOME/dotfiles" -mindepth 2 -maxdepth 2 -type d -path '*/.worktrees/*'
} 2>/dev/null | LC_ALL=C sort -f

exit 0
