"""Exercise two independent PTYs attached to one private Emacs server.

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
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", rows, columns, 0, 0))


def main():
    processes, masters, transcripts = [], [], []
    with tempfile.TemporaryDirectory(prefix="tui-clients-") as directory:
        root = pathlib.Path(directory)
        env = dict(os.environ, TERM="xterm-256color", EMACS_TUI_CLIENT_DIR=directory)
        deadline = time.monotonic() + 45

        def spawn(arguments, rows, columns):
            master, slave = pty.openpty()
            masters.append(master)
            transcripts.append(bytearray())
            resize(master, rows, columns)
            try:
                process = subprocess.Popen(arguments, stdin=slave, stdout=slave, stderr=slave,
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

        def await_phase(expected):
            while time.monotonic() < deadline:
                drain()
                if (root / "result").exists():
                    raise RuntimeError((root / "result").read_text())
                if (root / "ready").exists() and (root / "ready").read_text() == expected:
                    return
                if processes[0].poll() is not None:
                    raise RuntimeError("Emacs exited before " + expected)
                if len(processes) > 1 and processes[1].poll() is not None and expected != "second-deleted":
                    raise RuntimeError("emacsclient exited before " + expected)
            raise TimeoutError("Terminal clients did not reach " + expected)

        try:
            spawn([os.environ.get("EMACS", "emacs"), "-Q", "-nw", "-L", ".",
                   "-l", "test/tty-clients-smoke.el"], 40, 120)
            await_phase("first-ready")
            spawn([os.environ.get("EMACSCLIENT", "emacsclient"), "--alternate-editor=false",
                   "--socket-name=" + str(root / "socket" / "tui"), "--tty", "--eval",
                   "(emacs-tui-test--clients-join)"], 35, 100)
            await_phase("both-ready")
            os.write(masters[0], b"alpha\x03\x05")
            await_phase("first-edited")
            os.write(masters[1], b"bravo\x03\x05")
            await_phase("second-edited")
            resize(masters[0], 30, 90)
            os.killpg(processes[0].pid, signal.SIGWINCH)
            await_phase("first-resized")
            resize(masters[1], 45, 140)
            os.killpg(processes[1].pid, signal.SIGWINCH)
            await_phase("second-resized")
            os.write(masters[1], b"\x03\x04")
            await_phase("second-deleted")
            os.write(masters[0], b"!\x03\x05")
            while processes[0].poll() is None and time.monotonic() < deadline:
                drain()
            status = processes[0].wait(timeout=1)
            client_status = processes[1].wait(timeout=1)
            report = (root / "result").read_text() if (root / "result").exists() else "Missing client report"
            print(report, end="" if report.endswith("\n") else "\n")
            if status != 0 or client_status != 0 or not report.startswith("PASS "):
                raise RuntimeError(f"Emacs/client exit codes: {status}/{client_status}")
            return 0
        except (OSError, RuntimeError, subprocess.TimeoutExpired) as error:
            print(f"FAIL terminal clients: {error}")
            for index, transcript in enumerate(transcripts):
                print(f"Terminal {index + 1}:\n" + transcript.decode(errors="replace"))
            return 1
        finally:
            # Each process has its own session, including a controlling PTY.
            # Never leave the private server or a waiting client behind.
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
