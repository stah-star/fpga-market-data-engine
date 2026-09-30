#!/usr/bin/env python3
"""
generate_market_data.py

Generates randomized market transactions for the RTL testbench AND computes the
expected output with a Python "golden model" of the hardware.

Writes:
  data/input.csv            human-readable transactions
  data/input_vectors.txt    one line per clock for the testbench: valid price quantity side
  data/expected_output.csv  what the RTL should produce for every valid transaction

Prices are integers in cents (18025 = $180.25), since the hardware has no floats.

Usage:
  python scripts/generate_market_data.py --count 10000 --seed 1
"""
import argparse
import csv
import random
from pathlib import Path

WINDOW = 8          # must match LOG2_WINDOW in RTL (2**3)
LOG2_WINDOW = 3
HOLD, BUY, SELL = 0, 1, 2
SIGNAL_NAMES = {HOLD: "HOLD", BUY: "BUY", SELL: "SELL"}


def golden_model(transactions, threshold):
    """Bit-accurate Python model of market_data_engine.sv."""
    window = [0] * WINDOW          # [0] newest ... [7] oldest, reset to zeros like the RTL
    total = 0
    count = 0
    expected = []
    for tx in transactions:
        if not tx["valid"]:
            continue
        price = tx["price"]
        total = total + price - window[-1]
        window = [price] + window[:-1]
        count = min(count + 1, WINDOW)
        avg = total >> LOG2_WINDOW
        full = count == WINDOW

        if not full:
            signal = HOLD
        elif price > avg + threshold:
            signal = BUY
        elif price + threshold < avg:
            signal = SELL
        else:
            signal = HOLD

        expected.append({"price": price, "avg": avg, "signal": signal,
                         "quantity": tx["quantity"], "side": tx["side"]})
    return expected


def generate(count, seed, valid_prob=0.9, start_price=18000):
    rng = random.Random(seed)
    price = start_price
    txs = []
    for t in range(count):
        # random walk with occasional bigger jumps so BUY/SELL actually happen
        step = rng.randint(-15, 15)
        if rng.random() < 0.05:
            step += rng.choice([-1, 1]) * rng.randint(40, 120)
        price = max(1, price + step)
        txs.append({
            "timestamp": t,
            "valid": 1 if rng.random() < valid_prob else 0,
            "price": price,
            "quantity": rng.randint(1, 1000),
            "side": rng.randint(0, 1),        # 1 = BUY order, 0 = SELL order
        })
    return txs


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--count", type=int, default=1000, help="number of clock cycles / transactions")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--threshold", type=int, default=20, help="must match THRESHOLD in the RTL")
    ap.add_argument("--out-dir", default="data")
    args = ap.parse_args()

    out = Path(args.out_dir)
    out.mkdir(parents=True, exist_ok=True)

    txs = generate(args.count, args.seed)
    expected = golden_model(txs, args.threshold)

    with open(out / "input.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["timestamp", "valid", "price", "quantity", "side"])
        w.writeheader()
        w.writerows(txs)

    with open(out / "input_vectors.txt", "w") as f:
        for tx in txs:
            f.write(f"{tx['valid']} {tx['price']} {tx['quantity']} {tx['side']}\n")

    with open(out / "expected_output.csv", "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=["price", "avg", "signal", "quantity", "side"])
        w.writeheader()
        w.writerows(expected)

    counts = {name: 0 for name in SIGNAL_NAMES.values()}
    for e in expected:
        counts[SIGNAL_NAMES[e["signal"]]] += 1
    print(f"Generated {len(txs)} cycles, {len(expected)} valid transactions (seed={args.seed})")
    print(f"Expected signals: BUY={counts['BUY']}  SELL={counts['SELL']}  HOLD={counts['HOLD']}")
    print(f"Wrote {out/'input.csv'}, {out/'input_vectors.txt'}, {out/'expected_output.csv'}")


if __name__ == "__main__":
    main()
