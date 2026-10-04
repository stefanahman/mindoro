# How it works

`start` spawns a daemon for the session. It ticks once a second,
advances the phase on the wall clock, and writes a state file every
tick. Everything else reads that file: the status line, the sidebar
pill, the break takeover. `stop` ends the daemon and the file goes
with it.

**Sleep.** A closed laptop stops the ticks, and the gap on wake says
so. The phase ran on the wall clock regardless. A break that ended
while the lid was down is over — type the phrase and focus begins. A
focus that ended while the lid was down didn't happen, so the session
stops rather than serve a break for work nobody did. A short gap
inside a phase is just a short absence.

**Adapters.** The daemon knows nothing about tmux, cmux or herdr.
Each has an adapter in `adapters/`, a small program with two verbs —
`detect`, and `run` — that the daemon starts as a child when the
multiplexer is present. Every adapter that detects runs; a machine
with all three gets all three.

- **tmux** — the takeover is one shared session running the break
  screen, every attached client switched into it and switched back
  when the screen exits. Typing the phrase in any window is typing
  into the same screen. The countdown is `#{mindoro}` in the status
  line.
- **cmux** — the countdown is a sidebar pill on the selected
  workspace, following your selection through cmux's event stream.
  The takeover is a workspace of its own that closes when the phrase
  is typed, and the one you were on comes back. A daemon started
  inside a cmux surface finds the socket by itself; started elsewhere,
  it reads `cmux_socket` from the config, then tries the paths the
  stable and nightly builds use.
- **herdr** — the takeover is a workspace of its own, focused for the
  break and closed by the phrase, with your previous workspace focused
  again. Phase changes are herdr notifications. No countdown in the
  sidebar yet: herdr 0.9.0's `report-metadata` verb rejects every
  argument form its help suggests.

## The state file

`~/.local/state/mindoro/state` is the public interface. It exists
while a session runs. Read it from anything — a caffeinate toggle, a
do-not-disturb switch, an ambient light — and never write it.

```
phase=focus|short_break|long_break
ends=<unix time the phase expires>
cycles=<focuses completed this session>
tick=<unix time of the daemon's last tick>
pid=<the daemon>
focus_minutes=<this session's focus length>
short_break_minutes=<its short break>
long_break_minutes=<its long break>
long_break_every=<focuses per long break>
```

The four durations are the session's, fixed at `start`, so a reader
can show "40/10" without knowing the config.

A `tick` older than a few seconds is a daemon that has stopped
ticking — asleep or gone — and readers treat the file as no session.
Writes are a rename, so a reader never sees half a file.
