#!/usr/bin/env python3
"""Attach a tmux client on a pseudo-terminal and keep it attached.

The takeover test needs a real client for switch-client to act on;
this is that client. It drains the terminal so tmux never blocks on
output, and it exits when tmux does.

    hold-client.py <socket-name> <session>
"""
import fcntl
import os
import pty
import select
import struct
import sys
import termios

sock, session = sys.argv[1], sys.argv[2]
pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execvp("tmux", ["tmux", "-L", sock, "attach", "-t", session])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
while True:
    try:
        r, _, _ = select.select([fd], [], [], 0.5)
        if r:
            os.read(fd, 65536)
    except OSError:
        break
    finished, _ = os.waitpid(pid, os.WNOHANG)
    if finished:
        break
