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
import json, os, pathlib, select, time, tty
tty.setraw(0)
ready = pathlib.Path(os.environ["EMACS_TUI_SMOKE_READY"])
for phase, width in [("1", 90), ("2", 140)]:
    ready.write_text(phase)
    deadline = time.monotonic() + 5
    while os.get_terminal_size().columns != width:
        if time.monotonic() >= deadline:
            raise RuntimeError("resize not delivered")
        time.sleep(.01)
mode = os.environ["SMOKE_TEST_MODE"]
if mode in ("input", "changed-input", "invalid-input"):
    request = pathlib.Path(os.environ["EMACS_TUI_SMOKE_INPUT"])
    def publish(value):
        temporary = request.with_suffix(".tmp")
        temporary.write_text(json.dumps(value))
        temporary.replace(request)
    payload = "日本語 é\n"
    publish({"id": "one", "text": payload if mode != "invalid-input" else ""})
    if mode == "invalid-input":
        time.sleep(5)  # The driver must reject this request and terminate us.
    received = b""
    deadline = time.monotonic() + 5
    while len(received) < len(payload.encode()):
        if time.monotonic() >= deadline:
            raise RuntimeError("input not delivered")
        if select.select([0], [], [], .1)[0]:
            received += os.read(0, 4096)
    assert received == payload.encode(), received
    if mode == "changed-input":
        publish({"id": "one", "text": "changed"})
        time.sleep(5)  # Reusing a delivered id with new bytes must fail.
    # Retain the request across several driver polls; it must not replay.
    assert not select.select([0], [], [], .3)[0], "input replayed"
    publish({"id": "two", "text": "next"})
    assert select.select([0], [], [], 5)[0], "second input missing"
    assert os.read(0, 4096) == b"next"
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

    def test_terminal_input_is_utf8_and_sent_once_per_id(self):
        result = self.run_child("input")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_changed_delivered_request_is_rejected(self):
        result = self.run_child("changed-input")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("changed after delivery", result.stderr)

    def test_invalid_input_is_rejected(self):
        result = self.run_child("invalid-input")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Invalid terminal input request", result.stderr)

    def test_missing_terminal_paint_rejected(self):
        result = self.run_child("missing-paint")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("not painted", result.stdout)


if __name__ == "__main__":
    unittest.main()
