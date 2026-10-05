#!/usr/bin/env bash
# Create (or re-enter) a named git worktree and its tmux session. The name is
# free-form -- an issue id (PEP-12345) or a feature name (spike-auth) alike.
#
#   worktree.sh <repo> <name>
#
# Every step is idempotent, so this is both the create path and the re-attach
# path: a session killed by hand is rebuilt with the same layout, and a worktree
# that already exists is only re-hydrated and switched to.
#
# The session is built here with tmux rather than through a sesh.toml wildcard
# because sesh derives a session name from the git remote or the directory
# basename -- for a worktree that collides with the main repo's own session, and
# `dir_length` is global so it cannot be fixed for worktrees alone.

set -euo pipefail

usage() {
	printf 'usage: %s <repo> <name>\n' "${0##*/}" >&2
	exit 2
}

[ $# -eq 2 ] || usage
[ -d "$1" ] || usage

repo=$(cd "$1" && pwd -P)

# Keep what git and tmux both tolerate. The branch keeps "/" (feature/PEP-1),
# the directory name flattens it so the worktree stays one level deep.
branch=$(printf '%s' "$2" | tr -c 'A-Za-z0-9._/-' '-')
branch=${branch#/}
branch=${branch%/}
[ -n "$branch" ] || usage
dir=${branch//\//-}

worktree="$repo/.worktrees/$dir"
session="${repo##*/}/$dir"

# Shared across all worktrees of a repo, and never part of a commit.
common=$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)
exclude="$common/info/exclude"

# Ignored paths that must not be shared. Build and cache output is the real
# hazard: two agents compiling in different worktrees through one linked dist/
# produce wrong output rather than an error. ".worktrees" is excluded for
# recursion -- linking it hands a worktree a link to its own parent.
skips=(
	.worktrees
	dist build out .output
	.next .nuxt .svelte-kit .angular .vite .turbo
	.cache .parcel-cache coverage storybook-static
	target .gradle
	__pycache__ .pytest_cache .venv venv
	'*.tsbuildinfo' .eslintcache '*.log' .DS_Store
)

# Per-repo additions live in .git, so a work repo needs no tracked file and this
# repo needs no work-specific names: one glob per line, "#" comments ignored.
if [ -r "$common/worktree-skip" ]; then
	while IFS= read -r pat; do
		case "$pat" in '' | '#'*) continue ;; esac
		skips+=("$pat")
	done <"$common/worktree-skip"
fi

# Link every existing gitignored path from the main checkout into the worktree,
# so .env / .claude / local config are there without a per-project script.
# --directory collapses a fully ignored directory to one entry (node_modules/
# instead of 40k files); a partially tracked one (.claude here) stays per-file.
hydrate() {
	local rel base dest pat skip

	while IFS= read -r -d '' rel; do
		rel=${rel%/}
		[ -n "$rel" ] || continue
		base=${rel##*/}

		skip=0
		for pat in "${skips[@]}"; do
			# shellcheck disable=SC2053  # globs on purpose
			if [[ $base == $pat || $rel == $pat ]]; then
				skip=1
				break
			fi
		done
		[ "$skip" -eq 0 ] || continue

		dest="$worktree/$rel"
		if [ -e "$dest" ] || [ -L "$dest" ]; then
			continue
		fi
		mkdir -p "$(dirname "$dest")"

		# node_modules is the one shared directory an agent writes to on its
		# own (an install), so clone it instead. -c is APFS clonefile:
		# copy-on-write, so this costs no disk until the trees diverge.
		if [ "$base" = node_modules ] && [ -d "$repo/$rel" ]; then
			cp -c -R "$repo/$rel" "$dest" 2>/dev/null || cp -R "$repo/$rel" "$dest"
		else
			ln -s "$repo/$rel" "$dest"

			# A "dir/" pattern in .gitignore does not match a symlink, so a
			# linked directory would show up as untracked in the worktree.
			# info/exclude is shared, but every path here is already ignored in
			# the main checkout, so the extra line changes nothing there.
			# Only the exact slash-free line counts as already present: a
			# "/dir/" pattern is the one that fails to match the symlink, so
			# finding it is a reason to write this line, not to skip it.
			if [ -d "$repo/$rel" ] && ! grep -qxF "/$rel" "$exclude" 2>/dev/null; then
				printf '/%s\n' "$rel" >>"$exclude"
			fi
		fi
	done < <(git -C "$repo" ls-files --others --ignored --exclude-standard \
		--directory --no-empty-directory -z)
}

base_ref() {
	local ref
	for ref in origin/HEAD origin/main origin/master main master HEAD; do
		if git -C "$repo" rev-parse --verify -q "$ref^{commit}" >/dev/null; then
			printf '%s' "$ref"
			return
		fi
	done
}

create_worktree() {
	# So a new worktree does not branch off a week-old origin/main. One network
	# call, never fatal.
	if git -C "$repo" remote get-url origin >/dev/null 2>&1; then
		git -C "$repo" fetch --quiet --no-tags origin || true
	fi

	if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
		git -C "$repo" worktree add "$worktree" "$branch"
	elif git -C "$repo" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
		git -C "$repo" worktree add --track -b "$branch" "$worktree" "origin/$branch"
	else
		git -C "$repo" worktree add -b "$branch" "$worktree" "$(base_ref)"
	fi
}

# Windows get their program through send-keys rather than as the pane command,
# so quitting lazygit or claude leaves the window alive -- what sesh's
# startup_script does for the configured sessions.
build_session() {
	local win

	tmux new-session -d -s "$session" -c "$worktree" -n editor
	win=$(tmux list-windows -t "=$session" -F '#{window_id}' | head -1)
	tmux send-keys -t "$win" 'nvim .' C-m

	win=$(tmux new-window -t "=$session" -c "$worktree" -n lazygit -P -F '#{window_id}')
	tmux send-keys -t "$win" 'lazygit' C-m

	win=$(tmux new-window -t "=$session" -c "$worktree" -n claude -P -F '#{window_id}')
	tmux send-keys -t "$win" 'claude --continue || claude' C-m

	# -t "$TMUX_PANE" on purpose: the session is still detached, so a bare setw
	# would retarget whichever session the caller is attached to.
	win=$(tmux new-window -t "=$session" -c "$worktree" -n shell -P -F '#{window_id}')
	# shellcheck disable=SC2016  # $TMUX_PANE is for the receiving shell, not this one
	tmux send-keys -t "$win" 'tmux setw -t "$TMUX_PANE" automatic-rename on; clear' C-m

	tmux select-window -t "=$session:^"
}

mkdir -p "$(dirname "$exclude")"
grep -qxF '/.worktrees/' "$exclude" 2>/dev/null ||
	printf '/.worktrees/\n' >>"$exclude"

[ -d "$worktree" ] || create_worktree
hydrate

tmux has-session -t "=$session" 2>/dev/null || build_session

if [ -n "${TMUX:-}" ]; then
	tmux switch-client -t "=$session"
else
	tmux attach-session -t "=$session"
fi
