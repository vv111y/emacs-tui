import errno, fcntl, os, pathlib, pty, select, struct, subprocess, sys, tempfile, termios, time

def attach_terminal():
    os.setsid()
    fcntl.ioctl(0, termios.TIOCSCTTY, 0)

with tempfile.TemporaryDirectory() as directory:
    report = pathlib.Path(directory) / "result.txt"
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    env = dict(os.environ, TERM="xterm-256color", EMACS_TUI_SMOKE_REPORT=str(report))
    process = subprocess.Popen([os.environ.get("EMACS", "emacs"), "-Q", "-nw", "-L", ".", "-l", "test/tty-smoke.el"], stdin=slave, stdout=slave, stderr=slave, env=env, preexec_fn=attach_terminal)
    os.close(slave)
    transcript = bytearray()
    deadline = time.monotonic() + 30
    try:
        while process.poll() is None and time.monotonic() < deadline:
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
        else:
            print("Terminal smoke test did not produce a report.")
            print(transcript[-8000:].decode(errors="replace"))
        sys.exit(result if report.exists() else 1)
    finally:
        os.close(master)
        if process.poll() is None:
            process.kill()
            process.wait()
