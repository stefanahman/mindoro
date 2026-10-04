# mindoro

A terminal pomodoro whose breaks take over every window.

[![ci](https://github.com/stefanahman/mindoro/actions/workflows/ci.yml/badge.svg)](https://github.com/stefanahman/mindoro/actions/workflows/ci.yml)
[![release](https://img.shields.io/github/v/release/stefanahman/mindoro)](https://github.com/stefanahman/mindoro/releases)
[![license](https://img.shields.io/github/license/stefanahman/mindoro)](LICENSE)

When a focus ends, every window you have open turns into the break
screen: one prompt, a star field, a phrase. The only way back is to type
the phrase. A dismiss button teaches you to dismiss; thirty seconds of
attention you can't skip is the point.

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

```sh
brew install stefanahman/tap/mindoro
```

For tmux, two lines in `tmux.conf`:

```tmux
set -g status-right '#{mindoro} %H:%M'
run-shell 'mindoro tmux-init'
```

Or through [TPM](https://github.com/tmux-plugins/tpm):
`set -g @plugin 'stefanahman/mindoro'`. `prefix + P` starts and stops a
session. Needs bash 4 or newer.

## Quick start

```
mindoro start [MINUTES]  begin a focus
mindoro stop             end the session
mindoro toggle           one key for both
mindoro status           the phase and time left
mindoro break            the break screen, in this terminal
```

A session is 25 minutes of focus, then a 5-minute break, and a
20-minute break after every fourth focus.

## Docs

- [Usage](docs/usage.md): session minutes, install options, the config file
- [How it works](docs/how-it-works.md): the daemon, sleep, the tmux, cmux
  and herdr adapters, the state file

See also: [owl](https://github.com/stefanahman/owl) ·
[spaces](https://github.com/stefanahman/spaces) ·
[mux](https://github.com/stefanahman/mux) ·
[claude-status](https://github.com/stefanahman/claude-status) ·
[mcp-defer](https://github.com/stefanahman/mcp-defer) ·
[eden](https://github.com/stefanahman/eden)

## License

MIT
