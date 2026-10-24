"""Require delayed-reflow success and bounded missing-reflow failure.

Copyright (C) 2026 Willy Rempel
Assisted-by: Codex:gpt-6.1-sol-wm
SPDX-License-Identifier: GPL-3.0-or-later
"""
import os
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

for fixture, success, failure in [
    ("tty-input-smoke.el", "input=multiline", 'FAIL input: (error "Input resize did not settle")'),
    ("tty-tree-smoke.el", "tree=expand/collapse", 'FAIL tree: (error "Tree resize did not settle")'),
]:
    for fault in ("delay", "disabled"):
        env = dict(os.environ, EMACS_TUI_REFLOW_FIXTURE="test/" + fixture,
                   EMACS_TUI_REFLOW_FAULT=fault)
        result = subprocess.run(
            [sys.executable, "test/run-tty-smoke.py", "test/tty-reflow-probe.el"],
            cwd=ROOT, env=env, text=True, capture_output=True)
        lines = result.stdout.splitlines()
        passed = (result.returncode == 0 and len(lines) == 1
                  and lines[0].startswith("PASS Emacs ") and success in lines[0])
        rejected = result.returncode == 1 and lines == [failure]
        if not (passed if fault == "delay" else rejected):
            raise SystemExit(f"Unexpected reflow probe {fixture}/{fault}: "
                             f"exit={result.returncode}; stdout={result.stdout!r}; "
                             f"stderr={result.stderr!r}")
        print(f"PASS reflow fault: {fixture}; {fault}="
              + ("both resizes passed" if fault == "delay" else "bounded failure detected"),
              flush=True)
