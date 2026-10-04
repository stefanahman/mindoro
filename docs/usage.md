# Usage

## Commands

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

## Install options

**tmux through [TPM](https://github.com/tmux-plugins/tpm)** instead,
with no Homebrew:

```tmux
set -g @plugin 'stefanahman/mindoro'
set -g status-right '#{mindoro} %H:%M'
```

Either way `prefix + P` starts and stops a session; set
`@mindoro-key` to change the key, or to `""` for none. A
`status-interval` of 1 or 2 makes the countdown live.

Needs bash 4 or newer. macOS ships 3.2; the formula depends on
Homebrew's, and a checkout finds one on your PATH.

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
cmux_socket = /tmp/cmux-nightly.sock   # for a daemon started outside a cmux surface
```

`phrases` is one phrase per line. `prompts` is a directory, one file
per prompt: the first line is the message, the rest is the art. The
defaults in `share/mindoro/` are the place to start.
