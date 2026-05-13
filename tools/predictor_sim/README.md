# Predictor Simulator

This directory contains an offline branch predictor simulator for HelloCPU.

## Purpose

The simulator replays branch events from a real RTL run and evaluates predictor
policies without rebuilding and rerunning the whole Verilated CPU for each
small predictor change.

## Input Trace

Generate a branch trace from the simulator:

```bash
./build/Vsim_top ./sw/build/coremark.bin --branch-trace
```

Or write to a custom path:

```bash
./build/Vsim_top ./sw/build/coremark.bin --branch-trace=branch_trace.log
```

Each line has this format:

```text
pc=30001234 btb_hit=1 pred=1 pred_target=30004567 actual=0 target=30001238
```

Fields:

- `pc`: branch PC
- `btb_hit`: whether the RTL BTB hit
- `pred`: RTL predicted taken bit
- `pred_target`: RTL predicted target
- `actual`: resolved branch direction
- `target`: resolved branch target

## Simulator Usage

Run the Python simulator:

```bash
python3 tools/predictor_sim/predictor_sim.py --trace branch_trace.log --policy current
python3 tools/predictor_sim/predictor_sim.py --trace branch_trace.log --policy gshare --ghr-bits 8 --pht-bits 10
python3 tools/predictor_sim/predictor_sim.py --trace branch_trace.log --policy local --lht-bits 10 --history-bits 6 --top-pcs 8
python3 tools/predictor_sim/predictor_sim.py --trace branch_trace.log --policy current_local --lht-bits 10 --history-bits 8
python3 tools/predictor_sim/predictor_sim.py --trace branch_trace.log --policy tournament --chooser-bits 10 --lht-bits 10 --history-bits 8
python3 tools/predictor_sim/predictor_sim.py --trace branch_trace.log --policy tournament_loop --chooser-bits 10 --lht-bits 10 --history-bits 8 --loop-confidence 3
```

Available policies:

- `current`: current BTB + BHT policy model
- `bimodal`: simple PC-indexed 2-bit predictor
- `gshare`: global-history XOR PC indexed predictor
- `local`: per-PC local history with shared pattern table
- `current_local`: current BTB target path with local-history fallback/tie-break
- `tournament`: chooser between `current` and `local`
- `loop`: current policy with an exit-only override for stable backward branches
- `tournament_loop`: tournament policy with the same loop-exit override

Useful options:

- `--top-pcs N`: print the worst branch PCs by mispredict count
- `--ghr-bits` / `--pht-bits`: tune `gshare`
- `--lht-bits` / `--history-bits`: tune `local`
- `--chooser-bits`: tune `tournament`
- `--loop-confidence`: tune when loop override starts trusting a trip count

## Notes

- The first version focuses on conditional branch direction quality.
- `current` models the existing direct-mapped BTB + BHT structure closely enough
  to compare hit-side policy changes.
- `bimodal`, `gshare`, and `local` in this first version are direction-only
  models. They do not model a separate target cache yet.
- The simulator is intended to rank candidate policies quickly, not to replace
  final RTL validation.
