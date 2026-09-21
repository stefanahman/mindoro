#!/usr/bin/env bats
# The state machine, run for real with one-second minutes.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    MINDORO="$ROOT/bin/mindoro"
    export XDG_STATE_HOME="$BATS_TEST_TMPDIR/state"
    export XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/config"
    export MINDORO_MINUTE=1          # a minute is one second here
    export MINDORO_NOTIFY=stderr     # keep the desktop out of it
    export MINDORO_ADAPTERS="$BATS_TEST_TMPDIR/no-adapters"
    mkdir -p "$XDG_CONFIG_HOME/mindoro" "$MINDORO_ADAPTERS"
    cat > "$XDG_CONFIG_HOME/mindoro/config" <<'EOF'
focus = 2
short_break = 2
long_break = 3
cycles = 2
wake_gap = 5
EOF
    STATE="$XDG_STATE_HOME/mindoro/state"
}

teardown() {
    if [[ -f "$STATE" ]]; then
        local pid
        pid=$(state_field pid)
        # Never kill 0: that is the whole process group, bats included.
        if [[ "$pid" =~ ^[0-9]+$ ]] && (( pid > 1 )); then
            kill -TERM "$pid" 2>/dev/null
        fi
    fi
    sleep 0.2
}

state_field() { sed -n "s/^$1=//p" "$STATE" 2>/dev/null; }

# wait_for <seconds> <command...>: poll until the command succeeds.
wait_for() {
    local deadline=$(( $(date +%s) + $1 )); shift
    until "$@"; do
        (( $(date +%s) > deadline )) && return 1
        sleep 0.2
    done
}

phase_is() { [[ "$(state_field phase)" == "$1" ]]; }
state_gone() { [[ ! -f "$STATE" ]]; }

# doctor key=value...: rewrite the live state file, keeping the pid,
# to stage a situation the clock would otherwise take minutes to reach.
doctor() {
    local phase ends cycles tick pid kv
    phase=$(state_field phase); ends=$(state_field ends); cycles=$(state_field cycles)
    tick=$(state_field tick); pid=$(state_field pid)
    for kv in "$@"; do
        case $kv in
        phase=*)  phase=${kv#*=} ;;
        ends=*)   ends=${kv#*=} ;;
        cycles=*) cycles=${kv#*=} ;;
        tick=*)   tick=${kv#*=} ;;
        esac
    done
    printf 'phase=%s\nends=%s\ncycles=%s\ntick=%s\npid=%s\n' "$phase" "$ends" "$cycles" "$tick" "$pid" > "$STATE.new"
    mv -f "$STATE.new" "$STATE"
}

@test "status with no session prints nothing and exits 0" {
    run "$MINDORO" status
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "start begins a focus with a live daemon" {
    run "$MINDORO" start
    [ "$status" -eq 0 ]
    [[ "$output" == "mindoro: focus 2 min" ]]
    wait_for 3 phase_is focus
    pid=$(state_field pid)
    kill -0 "$pid"
    run "$MINDORO" status
    [[ "$output" =~ ^focus\ 00:0[0-2]$ ]]
}

@test "start twice keeps the one daemon" {
    "$MINDORO" start
    wait_for 3 phase_is focus
    pid=$(state_field pid)
    run "$MINDORO" start
    [[ "$output" == *"already running"* ]]
    [ "$(state_field pid)" = "$pid" ]
}

@test "focus becomes a short break, then focus, then a long break" {
    "$MINDORO" start
    wait_for 5 phase_is short_break
    [ "$(state_field cycles)" = 1 ]
    wait_for 5 phase_is focus
    wait_for 5 phase_is long_break
    [ "$(state_field cycles)" = 2 ]
}

@test "a break that ended during sleep is over on wake: focus begins" {
    "$MINDORO" start
    wait_for 3 phase_is focus
    now=$(date +%s)
    doctor phase=short_break "tick=$(( now - 100 ))" "ends=$(( now - 1 ))"
    wait_for 3 phase_is focus
    kill -0 "$(state_field pid)"
}

@test "a focus that ended during sleep stops the session" {
    "$MINDORO" start
    wait_for 3 phase_is focus
    pid=$(state_field pid)
    now=$(date +%s)
    doctor phase=focus "tick=$(( now - 100 ))" "ends=$(( now - 1 ))"
    wait_for 3 state_gone
    ! kill -0 "$pid" 2>/dev/null
}

@test "a short gap is not sleep: the phase moves on as usual" {
    "$MINDORO" start
    wait_for 3 phase_is focus
    now=$(date +%s)
    doctor phase=focus "tick=$(( now - 3 ))" "ends=$(( now - 1 ))"
    wait_for 3 phase_is short_break
}

@test "stop ends the session and the daemon" {
    "$MINDORO" start
    wait_for 3 phase_is focus
    pid=$(state_field pid)
    run "$MINDORO" stop
    [[ "$output" == "mindoro: stopped" ]]
    [ ! -f "$STATE" ]
    wait_for 3 bash -c "! kill -0 $pid 2>/dev/null"
}

@test "toggle starts, toggle stops" {
    "$MINDORO" toggle
    wait_for 3 phase_is focus
    "$MINDORO" toggle
    [ ! -f "$STATE" ]
}

@test "a stale state file from a dead daemon reads as no session" {
    mkdir -p "$(dirname "$STATE")"
    printf 'phase=focus\nends=%s\ncycles=0\ntick=%s\npid=999999\n' "$(( $(date +%s) + 100 ))" "$(( $(date +%s) - 60 ))" > "$STATE"
    run "$MINDORO" status
    [ -z "$output" ]
    run "$MINDORO" start
    [ "$status" -eq 0 ]
    wait_for 3 phase_is focus
    [ "$(state_field pid)" != 999999 ]
}

@test "status --tmux renders tmux markup" {
    "$MINDORO" start
    wait_for 3 phase_is focus
    run "$MINDORO" status --tmux
    [[ "$output" == '#[fg=#e2b072][F 00:0'* ]]
}

@test "config rejects an unknown key and a bad number" {
    echo "tea = 3" >> "$XDG_CONFIG_HOME/mindoro/config"
    run "$MINDORO" start
    [ "$status" -eq 65 ]
    [[ "$output" == *"unknown key tea"* ]]
    printf 'focus = 0\n' > "$XDG_CONFIG_HOME/mindoro/config"
    run "$MINDORO" start
    [ "$status" -eq 65 ]
    [[ "$output" == *"focus must be a positive integer"* ]]
}

@test "--version prints the version" {
    run "$MINDORO" --version
    [[ "$output" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}
