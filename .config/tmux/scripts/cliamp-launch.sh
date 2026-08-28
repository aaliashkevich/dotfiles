#!/usr/bin/env sh
# Single definition of how cliamp is started, used by both tmux_base and
# cliamp-popup.sh.
#
# The Navidrome credentials are sourced here rather than inherited: tmux does
# not pass the calling client's environment to the command it spawns, so an
# export in the shell (or in .zsh_extra) never reaches this process.
# config.toml is tracked and refers to ${NAVIDROME_URL}, ${NAVIDROME_USER} and
# ${NAVIDROME_PASSWORD}; secrets.env holds the values and is gitignored. The
# url carries its own https:// so nothing about the host is left in the repo.

secrets="$HOME/.config/cliamp/secrets.env"
if [ -f "$secrets" ]; then
    . "$secrets"
    export NAVIDROME_URL NAVIDROME_USER NAVIDROME_PASSWORD
fi

exec cliamp --provider navidrome --start-theme nord --vol -10
