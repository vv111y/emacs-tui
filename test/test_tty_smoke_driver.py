"""Test smoke-driver reports and terminal paint using a real PTY child.

Copyright (C) 2026 Willy Rempel
Assisted-by: Codex:gpt-6.1-sol-wm
SPDX-License-Identifier: GPL-3.0-or-later
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


class SmokeDriverTests(unittest.TestCase):
    def run_child(self, mode):
        with tempfile.TemporaryDirectory() as directory:
            child = Path(directory) / "child"
            child.write_text(f"#!{sys.executable}\n" + r'''
import os, pathlib, time
ready = pathlib.Path(os.environ["EMACS_TUI_SMOKE_READY"])
for phase, width in [("1", 90), ("2", 140)]:
    ready.write_text(phase)
    deadline = time.monotonic() + 5
    while os.get_terminal_size().columns != width:
        if time.monotonic() >= deadline:
            raise RuntimeError("resize not delivered")
        time.sleep(.01)
mode = os.environ["SMOKE_TEST_MODE"]
pathlib.Path(os.environ["EMACS_TUI_SMOKE_REPORT"]).write_text(
    "FAIL deliberate failure\n" if mode == "failure" else "PASS protocol\n")
if mode == "missing-paint":
    pathlib.Path(os.environ["EMACS_TUI_SMOKE_PAINT"]).write_text("unpainted-marker")
print("child output", flush=True)
''')
            child.chmod(0o700)
            return subprocess.run(
                [sys.executable, "test/run-tty-smoke.py"],
                env=dict(os.environ, EMACS=str(child), SMOKE_TEST_MODE=mode),
                text=True, capture_output=True, timeout=15)

    def test_success_requires_resize_and_pass_report(self):
        result = self.run_child("success")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("PASS protocol", result.stdout)

    def test_failure_report_rejected_even_with_zero_exit(self):
        result = self.run_child("failure")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("FAIL deliberate failure", result.stdout)

    def test_missing_terminal_paint_rejected(self):
        result = self.run_child("missing-paint")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not painted", result.stdout)


if __name__ == "__main__":
    unittest.main()
