#!/usr/bin/env python3
import re
import statistics
from pathlib import Path

lines = [l for l in Path(__file__).with_name("results.jsonl").read_text().splitlines() if l and not l.startswith("#")]
pat = re.compile(r"trial=(\d+) mode=(\w+) ns=(\d+)")
rows = [pat.match(l).groups() for l in lines if pat.match(l)]
by_mode = {"baseline": [], "optimized": []}
for trial, mode, ns in rows:
    by_mode[mode].append(int(ns))
print("baseline_ns", by_mode["baseline"], "median", statistics.median(by_mode["baseline"]))
print("optimized_ns", by_mode["optimized"], "median", statistics.median(by_mode["optimized"]))
