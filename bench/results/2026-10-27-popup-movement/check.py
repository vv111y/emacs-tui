#!/usr/bin/env python3
"""Verify retained native popup samples, digests and nearest-rank summaries.

Copyright (C) 2026 Willy Rempel
Assisted-by: Codex:gpt-6.1-sol-wm
SPDX-License-Identifier: GPL-3.0-or-later
"""
import gzip
import hashlib
import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent


def require(condition, message):
    if not condition:
        raise ValueError(message)


def summaries(records, saved):
    for metric, quantiles in saved.items():
        values = sorted(row[metric] for row in records)
        for name, percentile in (("p50", .5), ("p95", .95), ("p99", .99)):
            expected = values[math.ceil(percentile * len(values)) - 1]
            require(quantiles[name] == expected, f"quantile mismatch: {metric}/{name}")


def main():
    manifest = json.loads((ROOT / "manifest.json").read_text())
    total = 0
    reports = {}
    for name, identity in manifest["files"].items():
        compressed = (ROOT / name).read_bytes()
        raw = gzip.decompress(compressed)
        require(hashlib.sha256(compressed).hexdigest() == identity["sha256"], name)
        require(hashlib.sha256(raw).hexdigest() == identity["uncompressed_sha256"], name)
        report = json.loads(raw)
        require(report["source"]["git_revision"] == manifest["commits"][identity["role"]], name)
        require(report["source"]["source_dirty"] is False, name)
        require(report["backend"] == "native-tty-popup", name)
        require(report["samples"] == 200 and report["warmup"] == 10, name)
        require(len(report["cases"]) == 4, name)
        require(len(report["records"]) == identity["records"] == 840, name)
        require(len(report["loaded_libraries"]) == 6, name)
        require(len(report["source"]["sha256"]) == 8, name)
        require(report["load_mode"] == identity["load_mode"], name)
        require([(c["kind"], c["size"]) for c in report["cases"]]
                == [(kind, size) for size in (100, 10000)
                    for kind in ("navigate-popup", "move-popup")], name)
        reports[identity["platform"], identity["load_mode"], identity["role"]] = report
        bytecode = report["load_mode"] == "bytecode"
        require(len(report["bytecode_sha256"]) == (6 if bytecode else 0), name)
        require(all(path.endswith(".elc" if bytecode else ".el")
                    for path in report["loaded_libraries"].values()), name)
        require(report["filter_fixture"]["prefix"] == "row ", name)
        require(report["provider_fixture"]["display_limit"] == 200, name)
        for index, case in enumerate(report["cases"]):
            rows = [r for r in report["records"] if r["case"] == index]
            require([r["sequence"] for r in rows] == list(range(210)), name)
            for row in rows:
                require(row["warmup"] == (row["sequence"] < 10), name)
                require(all(isinstance(value, (int, float)) and math.isfinite(value)
                            and value >= 0 for key, value in row.items()
                            if key.endswith("_ms")), name)
                require(abs(row["command_without_table_ms"] + row["table_callback_ms"]
                            - row["command_redisplay_ms"]) < 1e-8, name)
                require((row["table_callback_calls"] > 0)
                        == (case["kind"] == "filter-completion"), name)
            measured = [r for r in rows if not r["warmup"]]
            require(len(measured) == 200, name)
            saved = report["summaries"][index]
            require(saved["kind"] == case["kind"] and saved["size"] == case["size"], name)
            summaries(measured, saved["metrics"])
            require({s["command"] for s in saved["by_command"]}
                    == {r["command"] for r in measured}, name)
            for command in saved["by_command"]:
                subset = [r for r in measured if r["command"] == command["command"]]
                require(len(subset) == command["samples"] >= 100, name)
                summaries(subset, command["metrics"])
        total += len(report["records"])
        print(f"PASS {name}: 840 samples; hashes and all quantiles verified")
    for platform in ("linux", "macos"):
        for mode in ("source", "bytecode"):
            before = reports[platform, mode, "baseline"]
            after = reports[platform, mode, "candidate"]
            require(before["host"] == after["host"], "paired host mismatch")
            for path in ("bench/run.py", "bench/interactive.el"):
                require(before["source"]["sha256"][path]
                        == after["source"]["sha256"][path], "fixture mismatch")
    require(total == 6720, "total record count")
    print(f"PASS total: {total} records; paired hosts and fixture bytes verified")


if __name__ == "__main__":
    main()
