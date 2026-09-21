#!/usr/bin/env bash
# mindoro.tmux — the TPM entry point.
#
#   set -g @plugin 'stefanahman/mindoro'
#   set -g status-right '#{mindoro} %H:%M'
#   set -g @mindoro-key 'P'        # prefix+P toggles; default P, "" for none
#
# `#{mindoro}` becomes a call to `mindoro status --tmux`, which reads
# the state file and prints `[F 24:59]` in the phase's colour, or
# nothing when no session runs. tmux caches it per status-interval,
# so a 1 or 2 second interval gives a live countdown. The break
# takeover is the daemon's tmux adapter, not this file: this only
# wires the display and the key.
set -uo pipefail

here=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)
bin="$here/../bin/mindoro"

interpolate() {
    local option=$1 value
    value=$(tmux show-option -gqv "$option")
    [[ "$value" == *'#{mindoro}'* ]] || return 0
    tmux set-option -gq "$option" "${value//\#\{mindoro\}/#($bin status --tmux)}"
}
interpolate status-right
interpolate status-left

# Unset means P; set to "" means no binding. `-v` cannot tell those
# apart, so read the option with its name first.
if [[ -z "$(tmux show-option -gq @mindoro-key)" ]]; then
    key=P
else
    key=$(tmux show-option -gqv @mindoro-key)
fi
if [[ -n "$key" ]]; then
    tmux bind-key "$key" run-shell "\"$bin\" toggle"
fi
