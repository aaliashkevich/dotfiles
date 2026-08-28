#!/usr/bin/env sh
# Show the cliamp TUI in a tmux popup.
#
# cliamp lives in its own detached "music" session so it keeps running (and
# keeps holding the IPC socket the status widget polls) when the popup closes.
# The session is created on demand, so this works even if tmux_base never ran
# or the session was killed.

set -e

session=music

# Already looking at the player: this invocation came from inside the popup, so
# make the key a toggle — the popup closes and cliamp keeps playing. The client
# is targeted by tty rather than left to tmux's "current client" default, so
# there is no way for this to detach the outer session by mistake.
if [ "$(tmux display-message -p '#S')" = "$session" ]; then
    tmux detach-client -t "$(tmux display-message -p '#{client_tty}')"
    exit 0
fi

if ! tmux has-session -t "=$session" 2>/dev/null; then
    # tmux does not pass the caller's environment to the command it spawns, so
    # the password is sourced inside the spawned shell rather than inherited.
    tmux new-session -d -s "$session" -c "$HOME" \
        "$HOME/.config/tmux/scripts/cliamp-launch.sh"
    # global detach-on-destroy is off (for sesh); override it here so quitting
    # cliamp closes the popup instead of dropping its client into another session.
    # No "=" prefix: set-option's -t is a *pane* target and rejects it.
    tmux set-option -t "$session" detach-on-destroy on
fi

tmux display-popup -w 60% -h 60% -E "tmux attach-session -t '=$session'"
