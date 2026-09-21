#!/usr/bin/env bats
# What an adapter answers to `detect`. The daemon starts an adapter
# only on exit 0, so a wrong yes is a child process talking to nothing
# and a wrong no is a multiplexer never shown the break.

setup() {
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export MINDORO_HOME="$ROOT"
    export MINDORO_CONFIG="$BATS_TEST_TMPDIR/no-config"
    export MINDORO_STATE="$BATS_TEST_TMPDIR/no-session"
}

@test "every adapter says no with nothing on PATH" {
    local a
    for a in tmux cmux herdr; do
        run env -i PATH=/usr/bin:/bin HOME="$HOME" MINDORO_HOME="$ROOT" MINDORO_CONFIG="$MINDORO_CONFIG" bash "$ROOT/adapters/$a" detect
        [ "$status" -ne 0 ]
    done
}

@test "cmux says no when the named socket does not answer" {
    command -v cmux >/dev/null || skip "cmux is not installed"
    run env CMUX_SOCKET_PATH="$BATS_TEST_TMPDIR/no.sock" bash "$ROOT/adapters/cmux" detect
    [ "$status" -ne 0 ]
}

@test "tmux says yes inside a session and no with none reachable" {
    command -v tmux >/dev/null || skip "tmux is not installed"
    local sock="mindoro-detect-$$"
    tmux -L "$sock" new-session -d -s probe
    local path
    path=$(tmux -L "$sock" display-message -p '#{socket_path}')
    run env TMUX="$path,0,0" bash "$ROOT/adapters/tmux" detect
    [ "$status" -eq 0 ]
    tmux -L "$sock" kill-server
    run env -u TMUX TMUX_TMPDIR="$BATS_TEST_TMPDIR" bash "$ROOT/adapters/tmux" detect
    [ "$status" -ne 0 ]
}

@test "an adapter rejects an unknown verb with 64" {
    local a
    for a in tmux cmux herdr; do
        run bash "$ROOT/adapters/$a" dance
        [ "$status" -eq 64 ]
    done
}
