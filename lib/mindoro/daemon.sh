# daemon.sh — the clock.
#
# One process per session, alive from `start` to `stop`. Every second
# it reads the state, moves the phase on if its time is up, writes the
# state back with a fresh tick, and checks on its adapters. It knows
# nothing about tmux or cmux; the adapters do, and they read the same
# file everyone else does.
#
# Sleep. A laptop that closes mid-phase stops ticking, and the gap
# between the last tick and now says so on wake. The phase ran on the
# wall clock regardless: a break that ended while the lid was down is
# over, and focus begins. A focus that ended while the lid was down
# did not happen — nobody was working — so the session stops rather
# than serve a break for it. A gap shorter than the phase's remaining
# time is just a short absence and changes nothing.

MINDORO_LOG=${MINDORO_LOG:-$(dirname "$MINDORO_STATE")/daemon.log}

# daemon_spawn starts the daemon detached, its output in the log.
#
# Every inherited descriptor is closed or redirected. A daemon that
# keeps the caller's stdin, or a descriptor a test runner is reading
# from (bats uses 3), holds that reader open for as long as the
# session runs — which looks like `start` never returning.
daemon_spawn() {
    mkdir -p "$(dirname "$MINDORO_LOG")"
    nohup "$MINDORO_HOME/bin/mindoro" daemon \
        < /dev/null >> "$MINDORO_LOG" 2>&1 3>&- 4>&- 5>&- 6>&- 7>&- 8>&- 9>&- &
    disown 2>/dev/null || true
}

daemon_log() { printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*"; }

daemon_run() {
    state_load || { echo "mindoro: daemon: no session to run (use start)" >&2; return 1; }
    # The session's minutes come from the file `start` wrote, not from
    # the config as it is now.
    state_durations_apply
    pid=$$
    tick=$(now_epoch)
    state_write
    trap daemon_cleanup EXIT
    trap 'exit 0' TERM INT HUP
    daemon_log "session started: $phase until $ends"
    adapters_start

    local now gap
    while true; do
        sleep 1
        state_load || { daemon_log "state gone: stopped"; return 0; }
        (( pid == $$ )) || { daemon_log "another daemon owns the state: leaving"; trap - EXIT; return 0; }
        now=$(now_epoch)
        gap=$(( now - tick ))
        if (( now >= ends )); then
            daemon_transition "$now" "$gap" || return 0
        fi
        tick=$now
        state_write
        adapters_reap
    done
}

# daemon_transition moves to the next phase at `now`, or ends the
# session; `gap` is the seconds since the last tick. Returns 1 when
# the session is over.
daemon_transition() {
    local now=$1 gap=$2 minutes
    case $phase in
    focus)
        if (( gap > cfg_wake_gap )); then
            minutes=$(( gap / 60 ))
            daemon_log "woke after ${minutes}m during a focus: session stopped"
            notify "Mindoro stopped" "Away ${minutes} min during a focus. Start again when you are back."
            return 1
        fi
        cycles=$(( cycles + 1 ))
        if (( cycles % cfg_cycles == 0 )); then
            phase=long_break
            notify "Long break" "$cycles focuses done. Take $cfg_long_break minutes."
        else
            phase=short_break
            notify "Short break" "Focus done. Take $cfg_short_break minutes."
        fi
        ;;
    short_break | long_break)
        phase=focus
        notify "Focus" "Break over. $cfg_focus minutes."
        ;;
    esac
    ends=$(( now + $(config_duration "$phase") ))
    daemon_log "phase: $phase until $ends (cycles=$cycles)"
    return 0
}

daemon_cleanup() {
    adapters_stop
    state_clear
    daemon_log "session ended"
}

# --- adapters -------------------------------------------------------
#
# An adapter is an executable in adapters/ answering two verbs:
# `detect`, exit 0 when its multiplexer is here, and `run`, a
# long-lived process that reads the state file and does the showing.
# The daemon starts every adapter that detects, and restarts one that
# dies — up to a limit, so a broken adapter cannot spin.

declare -a adapter_paths=() adapter_pids=() adapter_deaths=()
ADAPTER_MAX_DEATHS=3

adapters_start() {
    local a
    for a in "${MINDORO_ADAPTERS:-$MINDORO_HOME/adapters}"/*; do
        [[ -x "$a" ]] || continue
        "$a" detect >/dev/null 2>&1 || continue
        adapter_paths+=("$a")
        adapter_pids+=(0)
        adapter_deaths+=(0)
        adapter_launch $(( ${#adapter_paths[@]} - 1 ))
    done
}

adapter_launch() {
    local i=$1
    MINDORO_STATE=$MINDORO_STATE MINDORO_HOME=$MINDORO_HOME "${adapter_paths[$i]}" run &
    adapter_pids[i]=$!
    daemon_log "adapter $(basename "${adapter_paths[$i]}") started (pid ${adapter_pids[$i]})"
}

adapters_reap() {
    local i
    for i in "${!adapter_paths[@]}"; do
        (( adapter_pids[i] > 0 )) || continue
        kill -0 "${adapter_pids[$i]}" 2>/dev/null && continue
        wait "${adapter_pids[$i]}" 2>/dev/null
        adapter_deaths[i]=$(( adapter_deaths[i] + 1 ))
        if (( adapter_deaths[i] > ADAPTER_MAX_DEATHS )); then
            daemon_log "adapter $(basename "${adapter_paths[$i]}") died ${adapter_deaths[$i]} times: giving up"
            adapter_pids[i]=0
            continue
        fi
        daemon_log "adapter $(basename "${adapter_paths[$i]}") died: restarting"
        adapter_launch "$i"
    done
}

adapters_stop() {
    local p
    for p in "${adapter_pids[@]}"; do
        (( p > 0 )) && kill -TERM "$p" 2>/dev/null
    done
    wait 2>/dev/null
}
