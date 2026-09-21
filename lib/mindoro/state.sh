# state.sh — the state file: the one thing every part of mindoro shares.
#
# ${XDG_STATE_HOME:-~/.local/state}/mindoro/state, present while a
# session runs, absent otherwise. `key=value` lines:
#
#   phase=focus|short_break|long_break
#   ends=<unix time the phase expires>
#   cycles=<focuses completed; a long break follows every N of them>
#   tick=<unix time of the daemon's last tick>
#   pid=<the daemon's pid>
#
# This is the public, read-only interface. Adapters, status bars and
# anything else that wants to know read it and never write it. Writes
# are a rename, so a reader always sees a whole old state or a whole
# new one. A file whose tick is older than a few seconds belongs to a
# daemon that is no longer ticking — asleep, or gone — and readers
# treat it as no session (see state_fresh).

MINDORO_STATE=${MINDORO_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/mindoro/state}

# Seconds since the last tick after which readers stop trusting the
# file. Larger than the tick so one late tick does not flicker.
STATE_STALE_AFTER=5

state_exists() { [[ -f "$MINDORO_STATE" ]]; }

# state_load reads the file into phase, ends, cycles, tick, pid.
# Returns 1 when there is no session.
state_load() {
    phase='' ends=0 cycles=0 tick=0 pid=0
    [[ -f "$MINDORO_STATE" ]] || return 1
    local key value
    while IFS='=' read -r key value; do
        case $key in
        phase)  phase=$value ;;
        ends)   ends=$value ;;
        cycles) cycles=$value ;;
        tick)   tick=$value ;;
        pid)    pid=$value ;;
        esac
    done < "$MINDORO_STATE"
    [[ -n "$phase" ]] || return 1
}

state_get() {
    [[ -f "$MINDORO_STATE" ]] || return 1
    local key value
    while IFS='=' read -r key value; do
        [[ "$key" == "$1" ]] && { printf '%s\n' "$value"; return 0; }
    done < "$MINDORO_STATE"
    return 1
}

# state_write puts phase, ends, cycles, tick, pid on disk, atomically.
state_write() {
    local dir tmp
    dir=$(dirname "$MINDORO_STATE")
    mkdir -p "$dir"
    tmp=$(mktemp "$dir/.state.XXXXXX") || return 1
    printf 'phase=%s\nends=%s\ncycles=%s\ntick=%s\npid=%s\n' \
        "$phase" "$ends" "$cycles" "$tick" "$pid" > "$tmp"
    mv -f "$tmp" "$MINDORO_STATE"
}

state_clear() { rm -f "$MINDORO_STATE"; }

# state_begin starts a session in the given phase, cycles at zero,
# the pid left empty for the daemon to fill in once it runs. Empty,
# not 0: a 0 handed to kill is the whole process group.
state_begin() {
    phase=$1
    tick=$(now_epoch)
    ends=$(( tick + $(config_duration "$phase") ))
    cycles=0
    pid=''
    state_write
}

# state_daemon_alive: is the pid in the file a live process?
state_daemon_alive() {
    local p
    p=$(state_get pid) || return 1
    [[ "$p" =~ ^[0-9]+$ ]] && (( p > 0 )) && kill -0 "$p" 2>/dev/null
}

# state_fresh: has the daemon ticked recently enough to trust the file?
state_fresh() {
    (( $(now_epoch) - tick <= STATE_STALE_AFTER ))
}

state_describe() {
    state_load || { echo "no session"; return; }
    local left=$(( ends - $(now_epoch) ))
    (( left < 0 )) && left=0
    printf '%s, %d:%02d left' "${phase/_/ }" $(( left / 60 )) $(( left % 60 ))
}

# now_epoch: seconds since the epoch, without a fork where bash can.
now_epoch() {
    if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2) )); then
        printf '%(%s)T\n' -1
    else
        date +%s
    fi
}
