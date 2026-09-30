# FPGA Market Data Processing Engine

A pipelined SystemVerilog processor for streaming market data. The RTL takes in one transaction per clock. It computes an 8-sample moving average of the price and outputs a **BUY / SELL / HOLD** signal. A Python flow generates randomized test data, simulates the RTL, and checks every output against a golden model.

**SystemVerilog · Python · Icarus Verilog · Git**

## Architecture

```
                 valid, price, quantity, side
                              │
                  ┌───────────▼───────────┐
     Stage 1      │   market_data_input   │  register one transaction per clock
                  └───────────┬───────────┘
                  ┌───────────▼───────────┐
     Stage 2      │    moving_average     │  8-sample window, running sum, avg = sum >> 3
                  └───────────┬───────────┘
                  ┌───────────▼───────────┐
     Stage 3      │   signal_generator    │  price vs avg ± threshold → BUY / SELL / HOLD
                  └───────────┬───────────┘
                              ▼
                 valid, price, avg, signal, quantity, side
```

| Metric | Value |
|---|---|
| Latency | 3 clock cycles (30 ns at 100 MHz) |
| Throughput | 1 transaction / cycle |
| Window | 8 samples (a power of two, so division is a bit shift) |

### Design decisions

- **No divider.** The window size is 8, so the average is `sum >> 3`. A hardware divider would cost much more area and add delay to the critical path.
- **Running sum.** Each new sample does `sum + newest − oldest`, which is one add and one subtract. The alternative is summing all 8 prices every cycle.
- **Overflow-safe comparisons.** The signal stage widens its operands by one bit. It checks `price + TH < avg` instead of `price < avg − TH`, so unsigned subtraction can never underflow.
- **Valid/ready-style streaming.** Every stage passes a `valid` bit along, and the data registers only update on valid cycles. Gaps in the input stream are handled correctly.
- **Warm-up handling.** The signal stays HOLD until the window has 8 real samples (`out_full`).

## Repository layout

```
rtl/
  price_register.sv         Day 1 warm-up: a register with valid
  market_data_input.sv      Stage 1
  moving_average.sv         Stage 2
  signal_generator.sv       Stage 3
  market_data_engine.sv     Top level, connects the 3 stages
testbench/
  tb_price_register.sv      \
  tb_market_data_input.sv    |  self-checking unit tests (PASS/FAIL)
  tb_moving_average.sv       |
  tb_signal_generator.sv    /
  tb_market_data_engine.sv  file-driven full-pipeline test
scripts/
  generate_market_data.py   random transactions + Python golden model
  verify_results.py         compares RTL output to the golden model
  run_all.py                runs everything with one command
data/                       generated inputs and expected outputs
results/                    RTL output + verification report
```

## How to run

**Requirements:** [Icarus Verilog](https://steveicarus.github.io/iverilog/) (v11+) and Python 3.

```bash
python scripts/run_all.py                  # unit tests + 1,000 random transactions
python scripts/run_all.py --count 100000   # stress test
```

Running a single unit test by hand:

```bash
iverilog -g2012 -o sim rtl/moving_average.sv testbench/tb_moving_average.sv
vvp sim
```

**EDA Playground:** each unit test also runs online. Paste the `rtl/` file into *Design* and the matching `tb_*.sv` into *Testbench*. Pick Icarus Verilog and click Run. The full-pipeline test reads files, so run that one locally.

## Results

`python scripts/run_all.py --count 100000`:

```
==============================
MARKET DATA RTL VERIFICATION
==============================

Transactions Tested : 89,878
Correct Outputs     : 89,878
Errors              : 0

Signals             : BUY=15564  SELL=15269  HOLD=59045
Latency             : 3-3 cycles (30 ns at 100 MHz)
Max Throughput      : 1 transaction/cycle (100 M transactions/s at 100 MHz)

PASS
```

(100,000 clock cycles with about 10% idle cycles, so 89,878 of them carried a valid transaction.)

## Next steps

- Synthesize in Vivado, then record LUT/FF usage and the maximum clock frequency
- Add a configurable window size and threshold via input ports
- Replace the SystemVerilog file-driven testbench with cocotb
