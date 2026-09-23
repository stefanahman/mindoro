#!/usr/bin/env bats
# The break screen's terminal manners, measured on a pseudo-terminal:
# the alternate screen, drawing once and moving only the stars, the
# small-terminal shapes, and keys that must not leak into the phrase.

setup() {
    command -v python3 >/dev/null || skip "python3 drives the pseudo-terminal"
    ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    PROBE="$ROOT/tests/helpers/screen-probe.py"
    # One known prompt and one known phrase, so the probe can look
    # for them by name.
    mkdir -p "$BATS_TEST_TMPDIR/prompts"
    printf 'PROBE MESSAGE\n   PROBE-ART\n  (   )\n   ---\n' > "$BATS_TEST_TMPDIR/prompts/probe.txt"
    printf 'probe phrase\n' > "$BATS_TEST_TMPDIR/phrases"
    printf 'prompts = %s\nphrases = %s\n' "$BATS_TEST_TMPDIR/prompts" "$BATS_TEST_TMPDIR/phrases" > "$BATS_TEST_TMPDIR/config"
    export MINDORO_CONFIG="$BATS_TEST_TMPDIR/config"
    export MINDORO_STATE="$BATS_TEST_TMPDIR/no-session"
    export PROBE_ART_TOKEN=PROBE-ART
}

# probe ROWS COLS SECONDS [KEYS...] — fills the associative array P.
probe() {
    declare -g -A P=()
    local line
    while IFS='=' read -r k v; do P[$k]=$v; done < <(python3 "$PROBE" "$@")
    [ -n "${P[exit]:-}" ]
}

@test "full size: alternate screen, content drawn once, only the stars move" {
    probe 40 120 2
    [ "${P[alt_on]}" = yes ]
    [ "${P[clears]}" = 1 ]           # the first frame; never again
    [ "${P[frames]}" -ge 4 ]         # at 2.5 frames a second
    [ "${P[prompt]}" = yes ]
    [ "${P[list]}" = yes ]
    [ "${P[art]}" = yes ]
    [ "${P[below_rows]}" = 0 ]
    [ "${P[past_cols]}" = 0 ]
}

@test "the phrase ends it, in any case, and the terminal is handed back" {
    probe 40 120 4 phrase enter
    [ "${P[exit]}" = 0 ]
    [ "${P[alt_off]}" = yes ]
    probe 40 120 4 'PROBE PHRASE' enter
    [ "${P[exit]}" = 0 ]
}

@test "an arrow key is swallowed, not typed into the phrase" {
    probe 40 120 2 up
    [ "${P[input]}" = "" ]
    probe 40 120 4 up phrase enter
    [ "${P[exit]}" = 0 ]
}

@test "a wrong phrase clears the input and keeps the screen" {
    probe 40 120 3 'not it' enter
    [ "${P[exit]}" = running ]
    [ "${P[input]}" = "" ]
}

@test "a short terminal drops the checklist, then the art, and never draws off-screen" {
    probe 14 80 2
    [ "${P[list]}" = no ]
    [ "${P[art]}" = yes ]
    [ "${P[prompt]}" = yes ]
    [ "${P[below_rows]}" = 0 ]
    probe 9 80 2
    [ "${P[list]}" = no ]
    [ "${P[art]}" = no ]
    [ "${P[prompt]}" = yes ]
    [ "${P[below_rows]}" = 0 ]
}

@test "a narrow terminal never moves the cursor past its edge" {
    probe 20 40 2
    [ "${P[past_cols]}" = 0 ]
    [ "${P[prompt]}" = yes ]
}

@test "without a terminal it refuses at once instead of spinning" {
    run timeout 5 bash "$ROOT/libexec/mindoro-break" < /dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"not a terminal"* ]]
}

@test "when its terminal goes away it exits, even with HUP ignored" {
    # HUP ignored is the case a trap cannot save: only the read loop
    # noticing EOF can end the process. The old screen looped here at
    # 28% CPU for two days.
    run timeout 20 python3 - "$ROOT/libexec/mindoro-break" <<'PY'
import os, pty, sys, time, select, fcntl, termios, struct, signal
script = sys.argv[1]
pid, fd = pty.fork()
if pid == 0:
    signal.signal(signal.SIGHUP, signal.SIG_IGN)
    os.environ["TERM"] = "xterm-256color"
    os.execvp("bash", ["bash", script])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
os.set_blocking(fd, False)
t0 = time.time()
while time.time() - t0 < 1.5:
    r, _, _ = select.select([fd], [], [], 0.1)
    if r:
        try: os.read(fd, 65536)
        except (BlockingIOError, OSError): pass
os.close(fd)
deadline = time.time() + 5
while time.time() < deadline:
    done, _ = os.waitpid(pid, os.WNOHANG)
    if done:
        print("exited"); sys.exit(0)
    time.sleep(0.1)
os.kill(pid, signal.SIGKILL); os.waitpid(pid, 0)
print("still running after 5s"); sys.exit(1)
PY
    [ "$status" -eq 0 ]
    [[ "$output" == *exited* ]]
}

@test "a resize between frames redraws everything once" {
    # The probe cannot resize mid-run; the layout key covers it in
    # code review terms: compute_layout runs every frame and a
    # changed key forces full_frame. Guard the invariant statically.
    grep -q 'layout_key" != "\$drawn_key' "$ROOT/libexec/mindoro-break"
}
