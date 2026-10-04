# Contributing

**From a checkout**:

```sh
git clone https://github.com/stefanahman/mindoro
cd mindoro && make install BIN=~/.local/bin
```

```sh
make lint    # shellcheck, entry points with their libraries
make test    # bats: the state machine with one-second minutes,
             # and the tmux takeover on a private server
```
