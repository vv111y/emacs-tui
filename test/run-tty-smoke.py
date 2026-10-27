# Copyright (C) 2026 Willy Rempel
# Assisted-by: Codex:gpt-6.1-sol-wm
# SPDX-License-Identifier: GPL-3.0-or-later

import errno, fcntl, os, pathlib, pty, select, signal, struct, subprocess, sys, tempfile, termios, time

def attach_terminal():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)

with tempfile.TemporaryDirectory() as directory:
    report = pathlib.Path(directory) / "result.txt"
    ready = pathlib.Path(directory) / "ready.txt"
    paint = pathlib.Path(directory) / "paint.txt"
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    env = dict(os.environ, TERM="xterm-256color", EMACS_TUI_SMOKE_REPORT=str(report), EMACS_TUI_SMOKE_READY=str(ready), EMACS_TUI_SMOKE_PAINT=str(paint))
    script = sys.argv[1] if len(sys.argv) > 1 else "test/tty-smoke.el"
    process = subprocess.Popen([os.environ.get("EMACS", "emacs"), "-Q", "-nw", "-L", ".", "-l", script], stdin=slave, stdout=slave, stderr=slave, env=env, preexec_fn=attach_terminal)
    os.close(slave)
    transcript = bytearray()
    deadline = time.monotonic() + 30
    resized = set()
    try:
        while process.poll() is None and time.monotonic() < deadline:
            if ready.exists():
                phase = ready.read_text()
                if phase in ("1", "2") and phase not in resized:
                    rows, columns = (30, 90) if phase == "1" else (45, 140)
                    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))
                    os.killpg(process.pid, signal.SIGWINCH)
                    resized.add(phase)
            if select.select([master], [], [], 0.1)[0]:
                try:
                    transcript.extend(os.read(master, 65536))
                except OSError as error:
                    if error.errno != errno.EIO: raise
                    break
        try:
            result = process.wait(timeout=1)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
            result = 1
        if report.exists():
            print(report.read_text(), end="")
            # Fixtures may require actual terminal paint, beyond Lisp frame state.
            if paint.exists() and (not paint.read_bytes() or paint.read_bytes() not in transcript):
                print("Expected popup text was not painted on the real terminal.")
                result = 1
            if resized != {"1", "2"}:
                result = 1
        else:
            print("Terminal smoke test did not produce a report.")
            print(transcript[-8000:].decode(errors="replace"))
        sys.exit(result if report.exists() else 1)
    finally:
        os.close(master)
        if process.poll() is None:
            process.kill()
            process.wait()
