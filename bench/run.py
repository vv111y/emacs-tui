#!/usr/bin/env python3
"""Measure real PTY keyboard commands; retain raw data and nearest-rank quantiles.

Copyright (C) 2026 Willy Rempel
Assisted-by: Codex:gpt-6.1-sol-wm
SPDX-License-Identifier: GPL-3.0-or-later
"""
import argparse
import contextlib
import errno
import faulthandler
import fcntl
import hashlib
import json
import math
import os
import pathlib
import platform
import pty
import re
import select
import signal
import shutil
import struct
import subprocess
import sys
import tempfile
import termios
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
MARKER = re.compile(rb"\x1b\]777;TUIBENCH;(ready|sample|done);(\d+);(\d+)\x07")
WINDOW_KINDS = ("navigate-list", "navigate-table", "filter-list", "filter-table", "provider-list")
POPUP_KINDS = ("navigate-popup", "move-popup", "filter-completion")
KINDS = WINDOW_KINDS + POPUP_KINDS
PAINT = b"POPUP-BENCH-PAINT"
LAUNCHER = """import fcntl, os, sys, termios
fcntl.ioctl(0, termios.TIOCSCTTY, 0)
os.execvp(sys.argv[1], sys.argv[1:])
"""


class BenchmarkTimeout(BaseException):
    """Do not let metadata helpers swallow the whole-run deadline as OSError."""


@contextlib.contextmanager
def wall_timeout(seconds):
    """Cover startup, measurements, metadata and cleanup, with a stack dump."""
    def expired(_signum, _frame):
        faulthandler.dump_traceback()
        raise BenchmarkTimeout(f"benchmark exceeded {seconds:g}s wall-clock deadline")
    previous = signal.signal(signal.SIGALRM, expired)
    # A C watchdog still dumps/exits if Python cannot dispatch SIGALRM.
    # Allow normal process-group cleanup five seconds before this hard fallback.
    faulthandler.dump_traceback_later(seconds + 10, exit=True)
    signal.setitimer(signal.ITIMER_REAL, seconds)
    try:
        yield
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        faulthandler.cancel_dump_traceback_later()
        signal.signal(signal.SIGALRM, previous)


def quantiles(values):
    """Nearest rank: p99 needs >=100 samples to be more than the maximum."""
    ordered = sorted(values)
    return {name: ordered[max(0, math.ceil(p * len(ordered)) - 1)]
            for name, p in (("p50", .5), ("p95", .95), ("p99", .99))}


def source_hashes():
    files = sorted(ROOT.glob("emacs-tui*.el")) + [ROOT / "bench/run.py", ROOT / "bench/interactive.el"]
    return {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in files}


def source_identity():
    hashes = source_hashes()
    try:
        subprocess.run(["git", "ls-files", "--error-unmatch", *hashes], cwd=ROOT,
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT,
                                           text=True, timeout=10).strip()
        dirty = subprocess.run(["git", "diff", "--quiet", "HEAD", "--", *hashes],
                               cwd=ROOT, timeout=10).returncode != 0
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        revision, dirty = None, None
    return {"git_revision": revision, "source_dirty": dirty, "sha256": hashes}


def cpu_model():
    """Capture a model where the host exposes one; never infer missing hardware."""
    cpuinfo = pathlib.Path("/proc/cpuinfo")
    if cpuinfo.exists():
        for line in cpuinfo.read_text().splitlines():
            if line.startswith("model name"):
                return line.split(":", 1)[1].strip()
    if platform.system() == "Darwin":
        try:
            return subprocess.check_output(["sysctl", "-n", "machdep.cpu.brand_string"],
                                           text=True, timeout=10).strip()
        except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
            return None
    return platform.processor() or None


def metrics(records):
    return {key: quantiles([r[key] for r in records]) for key in records[0]
            if key.endswith("_ms") or key in ("cons_cells", "string_chars", "gc_count")}


def wait_for_exit(process, master, timeout, transcript):
    """Drain terminal output through exit using bounded nonblocking waitpid polls.

    Do not leave a PTY writer blocked while waiting, or depend on platform
    timed-wait notification mechanisms after the final protocol marker.
    """
    deadline = time.monotonic() + timeout
    eof = master is None
    while process.poll() is None:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise subprocess.TimeoutExpired(process.args, timeout)
        if eof:
            select.select([], [], [], min(.01, remaining))
        elif select.select([master], [], [], min(.1, remaining))[0]:
            try:
                data = os.read(master, 65536)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                data = b""
            if data:
                transcript.extend(data)
                del transcript[:-8000]
            else:
                eof = True
    return process.returncode


def prepare_libraries(directory, mode, executable, env):
    """Snapshot sources; optionally compile them with the selected runtime."""
    if mode == "source" and list(ROOT.glob("emacs-tui*.elc")):
        raise RuntimeError("remove library .elc files first (make clean); source mode requested")
    root = directory / "library"
    root.mkdir()
    for path in ROOT.glob("emacs-tui*.el"):
        shutil.copyfile(path, root / path.name)
    sources = sorted(root.glob("emacs-tui*.el"))
    if mode == "source":
        return root, {}
    # Helpers sort before emacs-tui.el; no bytecode or native cache is copied.
    command = [executable, "-Q", "--batch", "-L", str(root),
               "--eval", "(setq byte-compile-error-on-warn t)",
               "--eval", "(when (boundp 'native-comp-deferred-compilation) (setq native-comp-deferred-compilation nil))",
               "--eval", "(when (boundp 'native-comp-jit-compilation) (setq native-comp-jit-compilation nil))",
               "-f", "batch-byte-compile", *map(str, sources)]
    print("benchmark: compiling isolated libraries", flush=True)
    compiler = subprocess.Popen(command, cwd=directory, env=env, start_new_session=True)
    try:
        status = wait_for_exit(compiler, None, 120, bytearray())
        if status != 0:
            raise subprocess.CalledProcessError(status, command)
    finally:
        try:
            os.killpg(compiler.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        wait_for_exit(compiler, None, 5, bytearray())
    compiled = {path.name: hashlib.sha256(path.read_bytes()).hexdigest()
                for path in root.glob("emacs-tui*.elc")}
    if set(compiled) != {path.name + "c" for path in sources}:
        raise RuntimeError("isolated compilation did not produce every library")
    return root, compiled


def run(args):
    cases = [{"kind": kind, "size": size} for size in args.sizes for kind in args.kinds]
    print("benchmark: collecting source identity", flush=True)
    identity = source_identity()
    with tempfile.TemporaryDirectory(prefix="emacs-tui-bench-") as directory:
        directory = pathlib.Path(directory)
        report = directory / "report.json"
        env = dict(os.environ, TERM="xterm-256color", EMACS_TUI_BENCH_REPORT=str(report),
                   EMACS_TUI_BENCH_CASES=json.dumps(cases), EMACS_TUI_BENCH_LOAD_MODE=args.load_mode,
                   EMACS_TUI_BENCH_FILTER_PREFIX=args.filter_prefix,
                   EMACS_TUI_BENCH_PRESENTATION=args.presentation)
        env.pop("EMACSLOADPATH", None)
        executable = os.environ.get("EMACS", "emacs")
        library_root, compiled = prepare_libraries(directory, args.load_mode, executable, env)
        if any(hashlib.sha256(path.read_bytes()).hexdigest() != identity["sha256"][path.name]
               for path in library_root.glob("emacs-tui*.el")):
            raise RuntimeError("library sources changed while preparing the snapshot")
        env["EMACS_TUI_BENCH_LIBRARY_ROOT"] = str(library_root)
        command = [executable, "-Q", "-nw", "-L", str(library_root),
                   "-l", str(ROOT / "bench/interactive.el")]
        master, slave = pty.openpty()
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
        print("benchmark: starting PTY subprocess", flush=True)
        # Run terminal attachment in a fresh interpreter, never in preexec_fn.
        # This also lets Popen return a PID before any Python launcher work.
        try:
            process = subprocess.Popen([sys.executable, "-c", LAUNCHER, *command],
                                       cwd=directory, env=env, stdin=slave,
                                       stdout=slave, stderr=slave, start_new_session=True)
        except BaseException:
            os.close(master)
            raise
        finally:
            os.close(slave)
        pending = bytearray()
        roundtrips = []
        painted = False
        group_retired = False

        def retire_group():
            nonlocal group_retired
            if not group_retired:
                # Descendants may hold the terminal after the leader exits.
                try:
                    os.killpg(process.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
                group_retired = True

        def receive(kind, case, sequence):
            nonlocal painted
            deadline = time.monotonic() + 30
            while time.monotonic() < deadline:
                match = MARKER.search(pending)
                if match:
                    actual = (match[1].decode(), int(match[2]), int(match[3]))
                    painted = painted or PAINT in pending[:match.start()]
                    del pending[:match.end()]
                    if actual != (kind, case, sequence):
                        raise RuntimeError(f"unexpected acknowledgement {actual}")
                    return time.perf_counter_ns()
                if select.select([master], [], [], .1)[0]:
                    try:
                        data = os.read(master, 65536)
                    except OSError as error:
                        if error.errno != errno.EIO:
                            raise
                        break
                    if not data:
                        break
                    pending.extend(data)
            detail = pending[-4000:].decode(errors="replace")
            if report.exists():
                data = json.loads(report.read_text())
                detail += str({"error": data.get("error"), "records": len(data.get("records", []))})
            raise RuntimeError(f"missing {kind}/{case}/{sequence}: {detail}")

        try:
            print(f"benchmark: subprocess started pid={process.pid}", flush=True)
            for index, case in enumerate(cases):
                painted = False
                receive("ready", index, 0)
                if args.presentation == "popup" and not painted:
                    raise RuntimeError("native popup candidate absent from terminal output")
                print(f'benchmark: ready {index + 1}/{len(cases)} {case["kind"]} {case["size"]} rows',
                      flush=True)
                for sequence in range(args.warmup + args.samples):
                    key = sample_key(case["kind"], sequence)
                    start = time.perf_counter_ns()
                    if os.write(master, key) != len(key):
                        raise RuntimeError("partial PTY key write")
                    end = receive("sample", index, sequence)
                    roundtrips.append({"case": index, "sequence": sequence,
                                       "key": key.hex(), "pty_output_ms": (end - start) / 1e6,
                                       "warmup": sequence < args.warmup})
                os.write(master, b"\x03\x02")  # C-c C-b: advance outside measured samples.
            receive("done", len(cases), 0)
            print("benchmark: draining terminal through process exit", flush=True)
            status = wait_for_exit(process, master, 30, pending)
            # Retire before metadata work, then never signal this group ID again.
            retire_group()
            if status != 0:
                raise RuntimeError(report.read_text() if report.exists() else "Emacs failed")
            if source_hashes() != identity["sha256"]:
                raise RuntimeError("library or benchmark sources changed during measurement")
            print("benchmark: collecting report metadata", flush=True)
            result = json.loads(report.read_text())
            records = result.pop("records")
            if len(records) != len(roundtrips):
                raise RuntimeError("Emacs and driver sample counts differ")
            for record, external in zip(records, roundtrips):
                if (record["case"], record["sequence"]) != (external["case"], external["sequence"]):
                    raise RuntimeError("sample identity mismatch")
                record.update(external)
            summaries = []
            for index, case in enumerate(cases):
                measured = [r for r in records if r["case"] == index and not r["warmup"]]
                by_command = []
                for name in sorted({r["command"] for r in measured}):
                    subset = [r for r in measured if r["command"] == name]
                    by_command.append({"command": name, "samples": len(subset), "metrics": metrics(subset)})
                summaries.append(dict(case, metrics=metrics(measured), by_command=by_command))
            result.update(schema=1, label=args.label, presentation=args.presentation, source=identity, cases=cases,
                          load_mode=args.load_mode, bytecode_sha256=compiled,
                          wall_timeout_s=args.timeout, pty_launcher="fresh-python-session",
                          command=command, samples=args.samples, warmup=args.warmup,
                          recorded_at_utc=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                          host={"system": platform.platform(), "machine": platform.machine(),
                                "processor": cpu_model(), "logical_cpus": os.cpu_count(),
                                "python": platform.python_version()},
                          pty={"columns": 120, "rows": 40},
                          provider_fixture=({"debounce_ms": 10, "timer_delay_ms": 20}
                                            if args.presentation == "windows" else
                                            {"type": "synchronous-completion-table",
                                             "artificial_delay_ms": 0, "display_limit": 200}),
                          filter_fixture={"prefix": args.filter_prefix},
                          quantile_method="nearest-rank", summaries=summaries, records=records)
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n")
            for summary in summaries:
                p = summary["metrics"]["pty_output_ms"]
                print(f'{summary["kind"]:16} {summary["size"]:6} rows: '
                      f'PTY ms p50={p["p50"]:.3f} p95={p["p95"]:.3f} p99={p["p99"]:.3f}')
        finally:
            try:
                retire_group()
                wait_for_exit(process, master, 5, pending)
            finally:
                os.close(master)


def sample_key(kind, sequence):
    """Drive ordinary bindings; popup navigation retains source-buffer focus."""
    if kind == "navigate-popup":
        return b"\x1bn"  # M-n in the host buffer.
    if kind == "move-popup":
        return b"\x03\x10"  # C-c C-p.
    if kind.startswith("navigate-"):
        return b"n"
    return b"x" if sequence % 2 == 0 else b"\x7f"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sizes", type=int, nargs="+", default=[100, 1000, 10000])
    parser.add_argument("--samples", type=int, default=100)
    parser.add_argument("--warmup", type=int, default=10)
    parser.add_argument("--kinds", nargs="+", choices=KINDS)
    parser.add_argument("--presentation", choices=("windows", "popup"), default="windows",
                        help="popup requires actual native TTY child frames; no fallback")
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--label", default="")
    parser.add_argument("--load-mode", choices=("source", "bytecode"), default="source")
    parser.add_argument("--filter-prefix", default="",
                        help="initial filter text matching every row; end with whitespace")
    parser.add_argument("--timeout", type=float, default=1800,
                        help="whole-run seconds, including startup and metadata (default: 1800)")
    args = parser.parse_args()
    allowed = POPUP_KINDS if args.presentation == "popup" else WINDOW_KINDS
    if args.kinds is None:
        args.kinds = list(allowed)
    if any(kind not in allowed for kind in args.kinds):
        parser.error("kinds must match the requested presentation")
    if args.presentation == "popup" and args.filter_prefix:
        parser.error("popup completion uses its own fixed native completion prefix")
    if min(args.sizes) < 10 or args.samples < 1 or args.warmup < 0:
        parser.error("sizes must be >=10, samples >=1 and warmup >=0")
    if not math.isfinite(args.timeout) or args.timeout <= 0:
        parser.error("timeout must be finite and positive")
    if args.filter_prefix and (not args.filter_prefix[-1].isspace()
                               or any(c in args.filter_prefix for c in "\r\n")):
        parser.error("filter-prefix must be a single line ending with whitespace")
    with wall_timeout(args.timeout):
        run(args)


if __name__ == "__main__":
    main()
