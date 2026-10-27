"""Real subprocess/PTY regressions for benchmark exit handling.

Copyright (C) 2026 Willy Rempel
Assisted-by: Codex:gpt-6.1-sol-wm
SPDX-License-Identifier: GPL-3.0-or-later
"""
import importlib.util
import tempfile
import errno
import os
import pathlib
import pty
import select
import signal
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parent.parent
SPEC = importlib.util.spec_from_file_location("benchmark_driver", ROOT / "bench/run.py")
DRIVER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(DRIVER)



class NativePopupArguments(unittest.TestCase):
    def test_rejects_mixed_workloads_before_starting_emacs(self):
        with tempfile.TemporaryDirectory() as directory:
            output = pathlib.Path(directory) / "report.json"
            for arguments in (("--completion-sort", "none"),
                              ("--presentation", "popup", "--kinds", "move-popup",
                               "--completion-sort", "none"),
                              ("--presentation", "popup", "--kinds", "navigate-list"),
                              ("--kinds", "filter-completion"),
                              ("--presentation", "popup", "--filter-prefix", "row ")):
                result = subprocess.run([sys.executable, str(ROOT / "bench/run.py"),
                                         "--output", str(output), *arguments],
                                        capture_output=True, text=True, timeout=10)
                self.assertEqual(result.returncode, 2, result.stderr)
                self.assertFalse(output.exists())


class ExitHandling(unittest.TestCase):
    def run_child(self, code, check):
        master, slave = pty.openpty()
        process = None
        try:
            process = subprocess.Popen([sys.executable, "-c", code], stdin=slave,
                                       stdout=slave, stderr=slave, start_new_session=True)
            os.close(slave)
            slave = None
            with DRIVER.wall_timeout(10):
                check(process, master)
        finally:
            try:
                if process is not None:
                    try:
                        os.killpg(process.pid, signal.SIGKILL)
                    except ProcessLookupError:
                        pass
                    DRIVER.wait_for_exit(process, master, 2, bytearray())
            finally:
                if slave is not None:
                    os.close(slave)
                os.close(master)

    def test_drains_output_larger_than_terminal_queue(self):
        def check(process, master):
            tail = bytearray()
            self.assertEqual(DRIVER.wait_for_exit(process, master, 5, tail), 0)
            self.assertEqual(tail, b"z" * 8000)
        self.run_child("import os\ndata=b'z'*(2*1024*1024)\n"
                       "while data:\n n=os.write(1,data)\n data=data[n:]\n", check)

    def test_terminal_eof_does_not_mean_process_has_exited(self):
        def check(process, master):
            self.assertTrue(select.select([master], [], [], 5)[0])
            try:
                self.assertEqual(os.read(master, 1), b"")
            except OSError as error:
                self.assertEqual(error.errno, errno.EIO)
            self.assertIsNone(process.poll())
            with self.assertRaises(subprocess.TimeoutExpired):
                DRIVER.wait_for_exit(process, master, .2, bytearray())
            self.assertIsNone(process.poll())
        self.run_child("import os,signal\nos.close(0)\nos.close(1)\nos.close(2)\n"
                       "signal.pause()\n", check)

    def test_batch_exit_status_without_a_terminal_reader(self):
        def check(process, _master):
            self.assertEqual(DRIVER.wait_for_exit(process, None, 5, bytearray()), 7)
        self.run_child("import sys\nsys.exit(7)\n", check)


if __name__ == "__main__":
    unittest.main()
