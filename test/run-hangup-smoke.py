"""Exercise abrupt loss of a real terminal emacsclient.

Copyright (C) 2026 Willy Rempel
Assisted-by: Codex:gpt-6.1-sol-wm
SPDX-License-Identifier: GPL-3.0-or-later
"""
import errno
import fcntl
import os
import pathlib
import pty
import select
import signal
import struct
import subprocess
import tempfile
import termios
import time


def attach_terminal():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)


def resize(master, rows, columns):
    fcntl.ioctl(master, termios.TIOCSWINSZ,
                struct.pack("HHHH", rows, columns, 0, 0))


def main():
    processes, masters, transcripts = [], [], []
    with tempfile.TemporaryDirectory(prefix="tui-hangup-") as directory:
        root = pathlib.Path(directory)
        env = dict(os.environ, TERM="xterm-256color",
                   EMACS_TUI_HANGUP_DIR=directory)
        deadline = time.monotonic() + 45

        def spawn(arguments, rows, columns):
            master, slave = pty.openpty()
            masters.append(master)
            transcripts.append(bytearray())
            resize(master, rows, columns)
            try:
                process = subprocess.Popen(
                    arguments, stdin=slave, stdout=slave, stderr=slave,
                    env=env, preexec_fn=attach_terminal)
            finally:
                os.close(slave)
            processes.append(process)

        def drain():
            for master in select.select(masters, [], [], 0.05)[0]:
                try:
                    chunk = os.read(master, 65536)
                except OSError as error:
                    if error.errno != errno.EIO:
                        raise
                    chunk = b""
                index = masters.index(master)
                transcripts[index].extend(chunk)
                del transcripts[index][:-16000]

        def await_phase(expected, allow_client_exit=False):
            while time.monotonic() < deadline:
                drain()
                if (root / "result").exists():
                    raise RuntimeError((root / "result").read_text())
                if ((root / "ready").exists()
                        and (root / "ready").read_text() == expected):
                    return
                if processes[0].poll() is not None:
                    raise RuntimeError("Emacs exited before " + expected)
                if (len(processes) > 1 and processes[1].poll() is not None
                        and not allow_client_exit):
                    raise RuntimeError("emacsclient exited before " + expected)
            raise TimeoutError("Terminal hangup did not reach " + expected)

        try:
            spawn([os.environ.get("EMACS", "emacs"), "-Q", "-nw", "-L", ".",
                   "-l", "test/tty-hangup-smoke.el"], 40, 120)
            await_phase("first-ready")
            spawn([os.environ.get("EMACSCLIENT", "emacsclient"),
                   "--alternate-editor=false",
                   "--socket-name=" + str(root / "socket" / "tui"),
                   "--tty", "--eval", "(emacs-tui-test--hangup-join)"],
                  35, 100)
            await_phase("both-ready")
            os.write(masters[1], b"\x1b[Ibravo\x03\x05")
            await_phase("hangup-ready")
            # Native-popup runs must paint the candidate on the client before
            # killing it; Lisp frame bookkeeping alone is not display proof.
            if (root / "popup-paint").exists():
                paint = (root / "popup-paint").read_bytes()
                paint_deadline = min(deadline, time.monotonic() + 2)
                while paint and paint not in transcripts[1] and time.monotonic() < paint_deadline:
                    drain()
                if not paint or paint not in transcripts[1]:
                    raise RuntimeError("Floating popup was not painted before client loss")
            os.killpg(processes[1].pid, signal.SIGKILL)
            processes[1].wait(timeout=2)
            (root / "client-killed").write_text("SIGKILL\n")
            await_phase("client-hung-up", allow_client_exit=True)
            os.write(masters[0], b"\x1b[Ialpha!\x03\x05")
            while processes[0].poll() is None and time.monotonic() < deadline:
                drain()
            status = processes[0].wait(timeout=1)
            report = ((root / "result").read_text()
                      if (root / "result").exists() else "Missing hangup report")
            print(report, end="" if report.endswith("\n") else "\n")
            if status != 0 or not report.startswith("PASS "):
                raise RuntimeError(f"Emacs exit code: {status}")
            if processes[1].returncode != -signal.SIGKILL:
                raise RuntimeError(
                    f"emacsclient was not killed abruptly: {processes[1].returncode}")
            return 0
        except (OSError, RuntimeError, TimeoutError,
                subprocess.TimeoutExpired) as error:
            print(f"FAIL terminal hangup: {error}")
            if (root / "events").exists():
                print("Native event trace:\n" + (root / "events").read_text())
            for index, transcript in enumerate(transcripts):
                print(f"Terminal {index + 1}:\n"
                      + transcript.decode(errors="replace"))
            return 1
        finally:
            for process in reversed(processes):
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                process.wait(timeout=2)
            for master in masters:
                os.close(master)


if __name__ == "__main__":
    raise SystemExit(main())
