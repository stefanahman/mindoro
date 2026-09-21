# mindoro

A break you can't click away.

mindoro is a pomodoro timer for the terminal. When a focus ends, every
window you have open turns into the break screen — one prompt, a
star field, a phrase — and the only way back is to type the phrase.
A dismiss button teaches you to dismiss. Thirty seconds of attention
you can't skip is the point.

The timer is the delivery mechanism. The break is the product.

```
                          [b 04:52]

                             .
                            . .
                           . o .
                            '.'

                 Drink a glass of water. Slowly.

                       Or check yourself:

     body       ·  water   ·  snack       ·  bathroom  ·  move
     relax      ·  breath  ·  shoulders   ·  jaw       ·  eyes  ·  sky
     social     ·  send someone a message
     cognitive  ·  offload one sentence   ·  look at something real

                    Type to close:  "just breathe"

                    > _
```

## Install

**Homebrew**, for any multiplexer:

```sh
brew install stefanahman/tap/mindoro
```

Then, for tmux, two lines in `tmux.conf`:

```tmux
set -g status-right '#{mindoro} %H:%M'
run-shell 'mindoro tmux-init'
```

**tmux through [TPM](https://github.com/tmux-plugins/tpm)** instead,
with no Homebrew:

```tmux
set -g @plugin 'stefanahman/mindoro'
set -g status-right '#{mindoro} %H:%M'
```

Either way `prefix + P` starts and stops a session; set
`@mindoro-key` to change the key, or to `""` for none. A
`status-interval` of 1 or 2 makes the countdown live.

**From a checkout**:

```sh
git clone https://github.com/stefanahman/mindoro
cd mindoro && make install BIN=~/.local/bin
```

Needs bash 4 or newer. macOS ships 3.2; the formula depends on
Homebrew's, and a checkout finds one on your PATH.

## Use

```
mindoro start [MINUTES]  begin a focus
mindoro stop             end the session
mindoro toggle [MINUTES] one key for both; the minutes apply when it starts
mindoro status [--tmux]  the phase and time left, or nothing
mindoro break            the break screen, in this terminal
```

A session is 25 minutes of focus, then a 5-minute break, and a
20-minute break after every fourth focus. Each phase change sends a
notification through your multiplexer's notifier, or the desktop's.

Minutes on the command line are for that session only and leave the
config alone:

```sh
mindoro start 40                              # a 40-minute focus
mindoro start --focus 40                      # the same, spelled out
mindoro start 50 --short-break 10             # and 10-minute breaks
mindoro start --long-break 30 --cycles 3      # a long one after every third
```

Numbers are read in decimal (`010` is ten), and each has a ceiling —
1440 minutes, 100 cycles — past which it is refused rather than
wrapped.

A session's minutes are fixed when it starts. To change them, stop
and start again; `start 40` against a running session says so and
changes nothing.

## How it works

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

**Adapters.** The daemon knows nothing about tmux or cmux. Each
multiplexer has an adapter in `adapters/`, a small program with two
verbs — `detect`, and `run` — that the daemon starts as a child when
the multiplexer is present. The tmux adapter does the takeover:
one shared session running the break screen, every attached client
switched into it, and switched back when the screen exits. Typing the
phrase in any window is typing into the same screen.

## Configure

`~/.config/mindoro/config`, `key = value`, all optional:

```
focus = 25          # minutes
short_break = 5
long_break = 20
cycles = 4          # focuses per long break
wake_gap = 5        # seconds without a tick that count as sleep
phrases = ~/.config/mindoro/phrases
prompts = ~/.config/mindoro/prompts
```

`phrases` is one phrase per line. `prompts` is a directory, one file
per prompt: the first line is the message, the rest is the art. The
defaults in `share/mindoro/` are the place to start.

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

## Development

```sh
make lint    # shellcheck, entry points with their libraries
make test    # bats: the state machine with one-second minutes,
             # and the tmux takeover on a private server
```
