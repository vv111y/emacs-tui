# Copyright (C) 2026 Willy Rempel
# Assisted-by: Codex:gpt-6.1-sol-wm
# SPDX-License-Identifier: GPL-3.0-or-later

import argparse, json, shutil
import errno, fcntl, os, pathlib, pty, select, signal, struct, subprocess, sys, tempfile, termios, time

def attach_terminal():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)

parser = argparse.ArgumentParser(description="Run an interactive Emacs smoke fixture")
parser.add_argument("--tmux", action="store_true", help="use an isolated tmux server")
parser.add_argument("script", nargs="?", default="test/tty-smoke.el")
args = parser.parse_args()
if args.tmux and not shutil.which("tmux"):
    parser.error("--tmux requires tmux on PATH")

with tempfile.TemporaryDirectory() as directory:
    report = pathlib.Path(directory) / "result.txt"
    ready = pathlib.Path(directory) / "ready.txt"
    paint = pathlib.Path(directory) / "paint.txt"
    input_request = pathlib.Path(directory) / "input.json"
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    env = dict(os.environ, TERM="xterm-256color", EMACS_TUI_SMOKE_REPORT=str(report), EMACS_TUI_SMOKE_READY=str(ready), EMACS_TUI_SMOKE_PAINT=str(paint), EMACS_TUI_SMOKE_INPUT=str(input_request))
    command = [os.environ.get("EMACS", "emacs"), "-Q", "-nw", "-L", ".", "-l", args.script]
    socket = str(pathlib.Path(directory) / "tmux.sock")
    if args.tmux:
        # Never attach to, configure, or terminate a user's existing server.
        env.pop("TMUX", None)
        config = pathlib.Path(directory) / "tmux.conf"
        config.write_text("set -g status off\nset -g default-terminal tmux-256color\n")
        command = ["tmux", "-S", socket, "-f", str(config),
                   "new-session", "-s", "smoke", "--", *command]
    process = subprocess.Popen(command, stdin=slave, stdout=slave, stderr=slave, env=env, preexec_fn=attach_terminal)
    os.close(slave)
    transcript = bytearray()
    deadline = time.monotonic() + 30
    resized = set()
    sent_inputs = {}
    try:
        while process.poll() is None and time.monotonic() < deadline:
            if input_request.exists():
                # Fixtures publish complete snapshots by atomic rename.  Keep
                # requests idempotent while Emacs consumes real terminal bytes.
                request = json.loads(input_request.read_text())
                request_id, payload = request.get("id"), request.get("text")
                if (not isinstance(request_id, str) or not request_id
                        or not isinstance(payload, str) or not payload
                        or len(payload.encode("utf-8")) > 4096):
                    raise ValueError("Invalid terminal input request")
                if request_id in sent_inputs:
                    if sent_inputs[request_id] != payload:
                        raise ValueError("Terminal input request changed after delivery")
                else:
                    remaining = payload.encode("utf-8")
                    while remaining:
                        written = os.write(master, remaining)
                        if written <= 0:
                            raise RuntimeError("Terminal input write made no progress")
                        remaining = remaining[written:]
                    sent_inputs[request_id] = payload
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
            report_text = report.read_text()
            print(report_text, end="")
            # tmux client status does not propagate the pane command status.
            if not report_text.startswith("PASS "):
                result = 1
            if args.tmux:
                print("Transport: isolated tmux server; outer PTY paint/resize checks required")
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
        if args.tmux:
            subprocess.run(["tmux", "-S", socket, "kill-server"],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=5, check=False)
