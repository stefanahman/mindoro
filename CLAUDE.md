# mindoro — Claude Code context

A pomodoro timer whose breaks take over every terminal window and let
go only when the phrase is typed. Bash 4, no other runtime. Read
`README.md` for what it is; this file is what done means here.

## Shape

- `bin/mindoro` — the launcher: `start|stop|toggle|status|break|daemon`.
  Resolves its own symlink to find `lib/`, so `make install BIN=…`
  is one link.
- `lib/mindoro/` — sourced by the launcher: `config.sh` (the config,
  parsed never sourced), `state.sh` (the state file, atomic writes),
  `notify.sh`, `daemon.sh` (the tick loop and the adapter supervisor).
- `libexec/mindoro-break` — the break screen. Knows nothing about
  multiplexers; runs as the only process in whatever terminal it is
  given.
- `adapters/<multiplexer>` — `detect` and `run`. Started by the daemon
  as children when their multiplexer is present. Each reads the state
  file and does the showing and the takeover for its multiplexer.
- `share/mindoro/` — default phrases and prompts, overridable through
  the config.
- `mindoro tmux-init` — wires tmux: `#{mindoro}` in the status line
  and the toggle key. `mindoro.tmux` at the root is the TPM entry and
  only calls it; a brew install runs it from tmux.conf. TPM runs
  `*.tmux` files at a plugin's root and nowhere else.

## Invariants

- The daemon is the only writer of the state file. Everything else
  reads. A tick older than `STATE_STALE_AFTER` is no session.
- The daemon never imports an adapter. Multiplexer knowledge lives in
  `adapters/` only.
- The break screen never calls a multiplexer. What happens when it
  exits is the adapter's business.
- The break screen has terminal manners, and `tests/screen.bats`
  measures them on a pseudo-terminal: it runs on the alternate screen
  and hands the terminal back; it draws the content once and moves
  only the stars, inside synchronized-update brackets; below 19–21
  rows it drops the checklist, then the art, and never draws
  off-screen; an escape sequence from a key is swallowed whole. The
  probe waits for the first frame before typing — keys on a fixed
  clock can all be queued before the first read on a slow machine.
- Phases run on the wall clock. Sleep is a gap between ticks, and the
  rule is in `daemon_transition`: a break that ended during the gap is
  over; a focus that ended during the gap voids the session.
- Anything spawned detached closes every inherited descriptor
  (`daemon_spawn`). A held descriptor is a `start` that never returns
  under a test runner.
- A pid left for the daemon to fill in is empty, never `0`.

## Done means

- `make lint` and `make test` green. The tmux test runs against a
  private server and needs `tmux` and `python3`; it skips without them.
- Tests use `MINDORO_MINUTE=1` (a one-second minute), `MINDORO_NOTIFY=stderr`
  and `MINDORO_STATE`/`MINDORO_CONFIG` named directly — a login shell's
  rc may export `XDG_*` and override what a pane is given.
- Commits: conventional, `type: description`, smallest coherent units.
  No AI attribution lines.
- `README.md` in step with behaviour; `VERSION` bumped at a release.
