#!/usr/bin/env python3
"""
verify_results.py

Compares the RTL simulation output (results/rtl_output.csv) against the Python
golden model (data/expected_output.csv), prints a report, and saves it to
results/performance_report.txt. Exit code 0 = PASS, 1 = FAIL.
"""
import argparse
import csv
import sys
from pathlib import Path

SIGNAL_NAMES = {0: "HOLD", 1: "BUY", 2: "SELL"}
FIELDS = ["price", "avg", "signal", "quantity", "side"]


def load(path):
    with open(path, newline="") as f:
        return [{k: int(v) for k, v in row.items()} for row in csv.DictReader(f)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--expected", default="data/expected_output.csv")
    ap.add_argument("--actual", default="results/rtl_output.csv")
    ap.add_argument("--report", default="results/performance_report.txt")
    ap.add_argument("--clock-mhz", type=float, default=100.0, help="simulated clock, for throughput math")
    args = ap.parse_args()

    expected = load(args.expected)
    actual = load(args.actual)

    errors = []
    for i, (e, a) in enumerate(zip(expected, actual)):
        bad = [f for f in FIELDS if e[f] != a[f]]
        if bad:
            errors.append((i, e, a, bad))
    if len(expected) != len(actual):
        errors.append((-1, None, None, [f"count mismatch: expected {len(expected)}, RTL {len(actual)}"]))

    latencies = [a["latency"] for a in actual] or [0]
    correct = min(len(expected), len(actual)) - sum(1 for e in errors if e[0] >= 0)
    signals = {name: 0 for name in SIGNAL_NAMES.values()}
    for a in actual:
        signals[SIGNAL_NAMES.get(a["signal"], "?")] = signals.get(SIGNAL_NAMES.get(a["signal"], "?"), 0) + 1

    lines = [
        "==============================",
        "MARKET DATA RTL VERIFICATION",
        "==============================",
        "",
        f"Transactions Tested : {len(expected):,}",
        f"Correct Outputs     : {correct:,}",
        f"Errors              : {len(errors)}",
        "",
        f"Signals             : BUY={signals['BUY']}  SELL={signals['SELL']}  HOLD={signals['HOLD']}",
        f"Latency             : {min(latencies)}-{max(latencies)} cycles "
        f"({max(latencies) * 1000 / args.clock_mhz:.0f} ns at {args.clock_mhz:.0f} MHz)",
        f"Max Throughput      : 1 transaction/cycle "
        f"({args.clock_mhz:.0f} M transactions/s at {args.clock_mhz:.0f} MHz)",
        "",
        "PASS" if not errors else "FAIL",
    ]
    for i, e, a, bad in errors[:10]:
        if i < 0:
            lines.append(f"  {bad[0]}")
        else:
            lines.append(f"  tx {i}: mismatched {bad}  expected={e}  rtl={a}")
    if len(errors) > 10:
        lines.append(f"  ... and {len(errors) - 10} more")

    report = "\n".join(lines)
    print(report)
    Path(args.report).parent.mkdir(parents=True, exist_ok=True)
    Path(args.report).write_text(report + "\n")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
