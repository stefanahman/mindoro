#!/usr/bin/env bats
# The tmux takeover, end to end, on a private tmux server with a real
# attached client: a focus ends, every client lands on the break
# screen, the phrase is typed, every client is back where it was.

setup() {
    command -v tmux >/dev/null || skip "tmux is not installed"
    command -v python3 >/dev/null || skip "python3 is needed to hold a client"
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    SOCK="mindoro-test-$$"
    T=(tmux -L "$SOCK")
    # Named directly, not through XDG_*: a login shell's rc files may
    # export those and would override what the pane is given.
    export MINDORO_STATE="$BATS_TEST_TMPDIR/state/mindoro/state"
    export MINDORO_CONFIG="$BATS_TEST_TMPDIR/config"
    printf 'focus = 2\nshort_break = 4\nlong_break = 4\ncycles = 4\n' > "$MINDORO_CONFIG"
    STATE=$MINDORO_STATE

    # A session whose shell carries the test environment, so a daemon
    # started from inside it inherits TMUX and finds this server.
    "${T[@]}" new-session -d -s work -x 120 -y 40 \
        -e "PATH=$ROOT/bin:$PATH" \
        -e "MINDORO_STATE=$MINDORO_STATE" -e "MINDORO_CONFIG=$MINDORO_CONFIG" \
        -e MINDORO_MINUTE=1 -e MINDORO_NOTIFY=stderr
    "${T[@]}" set-option -g status-interval 1
    python3 "$ROOT/tests/helpers/hold-client.py" "$SOCK" work >/dev/null 2>&1 3>&- &
    CLIENT=$!
    wait_for 5 bash -c "${T[*]} list-clients 2>/dev/null | grep -q ."
}

teardown() {
    "${T[@]}" send-keys -t work "'$ROOT/bin/mindoro' stop" Enter 2>/dev/null || true
    sleep 0.5
    kill "$CLIENT" 2>/dev/null || true
    "${T[@]}" kill-server 2>/dev/null || true
    pkill -TERM -f "MINDORO_STATE=$MINDORO_STATE" 2>/dev/null || true
}

state_field() { sed -n "s/^$1=//p" "$STATE" 2>/dev/null; }
phase_is() { [[ "$(state_field phase)" == "$1" ]]; }
client_on() { [[ "$("${T[@]}" list-clients -F '#{session_name}' 2>/dev/null | head -1)" == "$1" ]]; }
no_break_session() { ! "${T[@]}" has-session -t mindoro-break 2>/dev/null; }

wait_for() {
    local deadline=$(( $(date +%s) + $1 )); shift
    until "$@"; do
        (( $(date +%s) > deadline )) && return 1
        sleep 0.25
    done
}

@test "a break takes over the attached client, and the phrase gives it back" {
    "${T[@]}" send-keys -t work "'$ROOT/bin/mindoro' start" Enter
    wait_for 5 phase_is focus
    client_on work

    wait_for 6 phase_is short_break
    wait_for 5 bash -c "${T[*]} has-session -t mindoro-break 2>/dev/null"
    wait_for 5 client_on mindoro-break

    # The screen names the phrase; type it into the shared pane.
    local screen phrase
    wait_for 5 bash -c "${T[*]} capture-pane -p -t mindoro-break | grep -q 'Type to close'"
    screen=$("${T[@]}" capture-pane -p -t mindoro-break)
    phrase=$(printf '%s\n' "$screen" | sed -n 's/.*Type to close:  "\(.*\)".*/\1/p' | head -1)
    [ -n "$phrase" ]
    "${T[@]}" send-keys -t mindoro-break "$phrase" Enter

    wait_for 5 no_break_session
    wait_for 5 client_on work
    # The clock never stopped: the break is still counting down.
    phase_is short_break
}

@test "stop during a break takes the screen down and returns the client" {
    "${T[@]}" send-keys -t work "'$ROOT/bin/mindoro' start" Enter
    wait_for 6 phase_is short_break
    wait_for 5 client_on mindoro-break
    "$ROOT/bin/mindoro" stop
    wait_for 5 no_break_session
    wait_for 5 client_on work
    [ ! -f "$STATE" ]
}

@test "a daemon killed outright takes its adapter with it" {
    "${T[@]}" send-keys -t work "'$ROOT/bin/mindoro' start" Enter
    wait_for 5 phase_is focus
    local daemon adapter
    daemon=$(state_field pid)
    wait_for 5 bash -c "pgrep -f '$ROOT/adapters/tmux run' >/dev/null"
    adapter=$(pgrep -f "$ROOT/adapters/tmux run" | head -1)
    kill -9 "$daemon"
    wait_for 5 bash -c "! kill -0 $adapter 2>/dev/null"
}

@test "the status line shows the countdown through #{mindoro}" {
    "${T[@]}" set-option -g status-right '#{mindoro}'
    "${T[@]}" run-shell "$ROOT/mindoro.tmux"      # the TPM entry, which runs `mindoro tmux-init`
    local right
    right=$("${T[@]}" show-option -gv status-right)
    [[ "$right" == *'status --tmux'* ]]
    "${T[@]}" send-keys -t work "'$ROOT/bin/mindoro' start" Enter
    wait_for 5 phase_is focus
    # tmux renders #() only in the live status line, never through
    # display-message, so run the command it would run, as it runs it.
    local cmd
    cmd=$(printf '%s\n' "$right" | sed -n 's/.*#(\(.*\)).*/\1/p')
    [ -n "$cmd" ]
    run sh -c "$cmd"
    [[ "$output" == '#[fg=#e2b072][F 00:0'* ]]
}
