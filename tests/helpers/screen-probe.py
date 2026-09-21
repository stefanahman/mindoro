#!/usr/bin/env python3
"""Run the break screen on a pseudo-terminal and report what it did.

    screen-probe.py ROWS COLS SECONDS [KEYS...]

KEYS are sent after 0.8s, in order; a key is literal text, or one of
the names `up`, `enter`, `phrase` (the phrase read off the screen).
Prints `key=value` lines:

    bytes        output size
    clears       full-screen clears (ESC[2J)
    frames       frames drawn (synchronized-update begins)
    alt_on       the alternate screen was entered
    alt_off      ...and left again by exit
    below_rows   cursor moves to a row past ROWS
    past_cols    cursor moves to a column past COLS
    prompt       the "Type to close" line was drawn
    art          the art was drawn ($PROBE_ART_TOKEN appeared)
    list         the checklist was drawn
    input        what the input row showed at the end
    exit         the exit status, or `running` if it never exited
"""
import fcntl
import os
import pty
import re
import select
import signal
import struct
import sys
import termios
import time

rows, cols, seconds = int(sys.argv[1]), int(sys.argv[2]), float(sys.argv[3])
keys = sys.argv[4:]
script = os.path.join(os.path.dirname(__file__), "..", "..", "libexec", "mindoro-break")

pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.execvp("bash", ["bash", script])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", rows, cols, 0, 0))
os.set_blocking(fd, False)

CSI = re.compile(rb"\x1b\[[0-9;?]*[A-Za-z]")


def visible(b):
    return CSI.sub(b"", b).decode("utf-8", "replace")


buf = b""
t0 = time.time()
sent = False
status = None
while time.time() - t0 < seconds:
    r, _, _ = select.select([fd], [], [], 0.05)
    if r:
        try:
            chunk = os.read(fd, 65536)
            if chunk:
                buf += chunk
        except BlockingIOError:
            pass
        except OSError:
            pass
    # Keys go in only once the first frame is on screen, as a person's
    # would: sent on a fixed clock, they can all be queued before the
    # screen's first read on a slow machine, and arrive as one burst.
    if keys and not sent and b"Type to close" in buf and time.time() - t0 > 0.3:
        for k in keys:
            if k == "up":
                os.write(fd, b"\x1b[A")
            elif k == "enter":
                os.write(fd, b"\r")
            elif k == "phrase":
                m = re.search(r'Type to close:\s+"([^"]+)"', visible(buf))
                os.write(fd, (m.group(1) if m else "").encode())
            else:
                os.write(fd, k.encode())
            time.sleep(0.15)
        sent = True
    done, st = os.waitpid(pid, os.WNOHANG)
    if done:
        status = os.WEXITSTATUS(st) if os.WIFEXITED(st) else -1
        # drain what is left
        time.sleep(0.1)
        try:
            buf += os.read(fd, 65536)
        except OSError:
            pass
        break
if status is None:
    os.kill(pid, signal.SIGKILL)

moves = [(int(r), int(c)) for r, c in re.findall(rb"\x1b\[(\d+);(\d+)H", buf)]
text = visible(buf)
last_input = ""
for frame in reversed(buf.split(b"\x1b[?2026h")):
    if b"> " in frame:
        tail = frame.split(b"> ")[-1]
        last_input = visible(tail.split(b"\x1b[?2026l")[0]).strip()
        break

print(f"bytes={len(buf)}")
print(f"clears={buf.count(b'\x1b[2J')}")
print(f"frames={buf.count(b'\x1b[?2026h')}")
print(f"alt_on={'yes' if b'\x1b[?1049h' in buf else 'no'}")
print(f"alt_off={'yes' if buf.rstrip().endswith(b'\x1b[?1049l') or b'\x1b[?1049l' in buf[-64:] else 'no'}")
print(f"below_rows={sum(1 for r, c in moves if r > rows)}")
print(f"past_cols={sum(1 for r, c in moves if c > cols)}")
print(f"prompt={'yes' if 'Type to close' in text else 'no'}")
print(f"list={'yes' if 'Or check yourself' in text else 'no'}")
token = os.environ.get("PROBE_ART_TOKEN", "")
print(f"art={'yes' if token and token in text else 'no'}")
print(f"input={last_input}")
print(f"exit={'running' if status is None else status}")
