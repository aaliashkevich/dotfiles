#!/usr/bin/env zsh
# tmux status-right widget for cliamp: play/pause icon and a marquee-scrolled
# "title — artist".
#
# Prints nothing when cliamp is not running or nothing is loaded, so the bar
# just goes empty instead of showing an error.
#
# zsh, not sh/bash: macOS ships bash 3.2, whose ${var:off:len} counts *bytes* and
# would cut multibyte track titles mid-character. zsh substrings count characters.

emulate -L zsh
zmodload zsh/datetime

(( $+commands[cliamp] && $+commands[jq] )) || exit 0

json=$(cliamp status --json 2>/dev/null) || exit 0
[[ -n $json ]] || exit 0

# one field per line: state, title, artist
fields=("${(@f)$(print -r -- $json | jq -r '
  if .ok != true then empty else
    [ .state,
      (.track.title  // ""),
      (.track.artist // "")
    ] | .[] | tostring
  end' 2>/dev/null)}")

(( ${#fields} == 3 )) || exit 0

state=$fields[1]
title=$fields[2]
artist=$fields[3]

[[ -n $title ]] || exit 0

case $state in
    playing) icon= ;;
    paused)  icon= ;;
    *)       exit 0 ;;
esac

label=$title
[[ -n $artist ]] && label="$title — $artist"

# Marquee: a fixed-width window over the label advancing two characters per
# second (status-interval is 1s, so it steps two on each redraw). The offset is
# derived from the clock rather than a state file, so the script stays
# stateless; while paused the offset is frozen.
integer width=28
if (( ${#label} > width )); then
    padded="$label   •   "
    integer off=0
    [[ $state == playing ]] && (( off = (EPOCHSECONDS * 2) % ${#padded} ))
    doubled="$padded$padded"
    label=${doubled[off+1,off+width]}
fi

out="$icon  $label"

# tmux reads '#' in #() output as the start of a format substitution
print -r -- "${out//\#/##}"
