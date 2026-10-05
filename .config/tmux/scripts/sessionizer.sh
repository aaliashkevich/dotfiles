#!/usr/bin/env bash
# The § picker. Replaces `sesh picker` with fzf over `sesh list`, because the
# sesh TUI takes no custom keybinds and cannot emit the text you typed (--query
# only prefills it). Session creation still goes through sesh for ordinary
# entries, so sesh.toml's startup_command and windows apply exactly as before.
#
#   enter      connect, as before
#   alt-enter  create or re-enter a named worktree in the highlighted repo
#
# Option+Enter reaches fzf as alt-enter without any ghostty setting: an
# Option-sequence that produces no printable character is treated as Alt
# regardless of macos-option-as-alt. ctrl-o is an alias, and the config's
# `shift+enter=text:\x1b\r` happens to send the same bytes.

set -euo pipefail

# A tmux popup inherits none of the interactive shell's environment, so the
# nordic theme has to be pointed at here too, not only from .zshrc. An existing
# value wins, which keeps a per-machine override in ~/.zsh_extra working.
export FZF_DEFAULT_OPTS_FILE="${FZF_DEFAULT_OPTS_FILE:-$HOME/.config/fzf/opts}"

here=$(cd "$(dirname "$0")" && pwd -P)
worktree_script="$here/worktree.sh"

die() {
	tmux display-message "sessionizer: $1" 2>/dev/null || printf 'sessionizer: %s\n' "$1" >&2
	exit 0
}

connect() {
	if [ -n "${TMUX:-}" ]; then
		exec sesh connect -s "$1"
	else
		exec sesh connect "$1"
	fi
}

# icon \t name \t path, so the display column stays as it was while the path
# travels with the row.  terminal,  cog,  folder.
rows() {
	sesh list -tcz -d --json | jq -r '
		.[] | [
			(if   .Src == "tmux"       then ""
			 elif .Src == "config"     then ""
			 elif .Src == "tmuxinator" then ""
			 else                           "" end),
			.Name, .Path
		] | @tsv'
}

out=$(rows | fzf \
	--delimiter=$'\t' --with-nth=1,2 --nth=2 \
	--expect=alt-enter,ctrl-o --print-query \
	--preview 'sesh preview {2}' --preview-window 'right,55' \
	--layout=reverse --prompt 'sesh> ' \
	--header 'enter: connect   alt-enter: new worktree' || true)

key=$(sed -n 2p <<<"$out")
row=$(sed -n 3p <<<"$out")
[ -n "$row" ] || exit 0

name=$(cut -f2 <<<"$row")
path=$(cut -f3 <<<"$row")

if [ -z "$key" ]; then
	# A worktree row is rebuilt by worktree.sh rather than sesh, so a session
	# killed by hand comes back with the layout it was created with.
	case "$path" in
	*/.worktrees/*) exec "$worktree_script" "${path%%/.worktrees/*}" "${path##*/}" ;;
	esac
	connect "$name"
fi

[ -d "$path" ] || die "not a directory: $path"

# --git-common-dir resolves to the main checkout even from inside a worktree, so
# alt-enter on a worktree row opens a sibling worktree in the same repo.
common=$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null) ||
	die "not a git repo: $path"
repo=${common%/.git}
repo=${repo%/}
[ -d "$repo" ] || die "no worktree root for $path"

existing=$(git -C "$repo" worktree list --porcelain |
	awk '/^worktree /{print $2}' |
	sed -n 's#.*/\.worktrees/##p' || true)

picked=$({ [ -n "$existing" ] && printf '%s\n' "$existing"; } | fzf \
	--print-query --layout=reverse \
	--prompt "worktree name in ${repo##*/}> " \
	--header 'type a name, or pick an existing worktree' || true)

worktree_name=$(sed -n 2p <<<"$picked")
[ -n "$worktree_name" ] || worktree_name=$(sed -n 1p <<<"$picked")
[ -n "$worktree_name" ] || exit 0

exec "$worktree_script" "$repo" "$worktree_name"
