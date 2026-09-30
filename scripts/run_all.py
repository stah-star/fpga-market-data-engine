#!/usr/bin/env python3
"""
run_all.py -- one command to run the whole flow (needs Icarus Verilog + Python 3).

  1. Run every unit testbench (price_register, market_data_input, moving_average, signal_generator)
  2. Generate random market data + expected results in Python
  3. Simulate the full pipeline (tb_market_data_engine)
  4. Verify RTL output against the Python golden model

Usage (from the repo root):
  python scripts/run_all.py                 # 1,000 transactions
  python scripts/run_all.py --count 100000
"""
import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"

UNIT_TESTS = {
    "price_register":    ["rtl/price_register.sv"],
    "market_data_input": ["rtl/market_data_input.sv"],
    "moving_average":    ["rtl/moving_average.sv"],
    "signal_generator":  ["rtl/signal_generator.sv"],
}
ENGINE_RTL = ["rtl/market_data_input.sv", "rtl/moving_average.sv",
              "rtl/signal_generator.sv", "rtl/market_data_engine.sv"]


def run(cmd, capture=False):
    print("$", " ".join(str(c) for c in cmd))
    r = subprocess.run(cmd, cwd=ROOT, text=True, capture_output=capture)
    if capture:
        print(r.stdout, end="")
        print(r.stderr, end="", file=sys.stderr)
    if r.returncode != 0:
        sys.exit(f"Command failed: {' '.join(str(c) for c in cmd)}")
    return r.stdout if capture else ""


def compile_and_sim(name, sources, params=()):
    exe = BUILD / name
    run(["iverilog", "-g2012", *params, "-o", str(exe), *sources, f"testbench/tb_{name}.sv"])
    return run(["vvp", "-n", str(exe)], capture=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=1000)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--threshold", type=int, default=20)
    ap.add_argument("--skip-unit", action="store_true", help="skip the unit testbenches")
    args = ap.parse_args()

    BUILD.mkdir(exist_ok=True)
    (ROOT / "results").mkdir(exist_ok=True)

    if not args.skip_unit:
        print("\n### 1. Unit testbenches")
        for name, srcs in UNIT_TESTS.items():
            out = compile_and_sim(name, srcs)
            if "ALL TESTS PASSED" not in out:
                sys.exit(f"Unit test {name} FAILED")

    print("\n### 2. Generate market data")
    run([sys.executable, "scripts/generate_market_data.py", "--count", str(args.count),
         "--seed", str(args.seed), "--threshold", str(args.threshold)])

    print("\n### 3. Simulate full pipeline")
    compile_and_sim("market_data_engine", ENGINE_RTL,
                    params=[f"-Ptb_market_data_engine.THRESHOLD={args.threshold}"])

    print("\n### 4. Verify against Python golden model")
    r = subprocess.run([sys.executable, "scripts/verify_results.py"], cwd=ROOT)
    sys.exit(r.returncode)


if __name__ == "__main__":
    main()
