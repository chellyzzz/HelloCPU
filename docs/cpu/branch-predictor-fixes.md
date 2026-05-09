# Branch Predictor Fixes

This document records the fixes that made the full BTB + RAS + static JAL predictor pass CoreMark and the CPU test suite.

## Historical Validation Snapshot

This document records the branch-predictor correctness fixes. The numbers below are the validation snapshot from that fix series, not the latest whole-CPU performance reference. Current CoreMark results live in `coremark-results.md`.

| Command | Result |
|---------|--------|
| `make run` | Historical snapshot: `40 passed, 0 failed` |
| `make run ALL=quick-sort` | Historical snapshot: PASS, `6750` cycles |
| `./build/Vsim_top sw/build/coremark.bin --max-cycles=100000000` | Correct CoreMark CRC |

CoreMark ITER=1 predictor-fix result:

```text
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xe714
Correct operation validated.
Total cycles     : 711745
CoreMark/MHz     : 1.404
[HelloCPU] PASS (cycles: 715631)
```

## Root Causes Fixed

### 1. Predicted-Taken / Actual-Not-Taken Branches Did Not Redirect

The previous WBU redirect condition used the actual taken signal (`i_brch`) to decide whether a branch needed PC recovery. That missed this case:

```text
predicted taken, actual not taken
```

Because actual taken was false, WBU skipped `pc_update`, so the CPU stayed on the wrong target path.

Fixes:

| File | Change |
|------|--------|
| `vsrc/cpu/exu/exu.v` | `predict_correct` now means any correctly predicted control flow, including not-taken branches |
| `vsrc/cpu/wbu/wbu.v` | Redirect decision uses `i_is_brch && !i_predict_correct`, not actual-taken branch output |
| `vsrc/cpu/top/hcpu.v` | Branch WBU redirect PC uses EXU `o_redirect_pc`, so not-taken recovery redirects to `pc + 4` |

### 2. Correctly Predicted JAL/JALR Still Forced WBU Redirects

When static JAL and RAS prediction were re-enabled, CoreMark could loop because correct call/return predictions were still flushed by WBU.

Fix:

```verilog
o_pc_update <= i_pre_valid &&
               (i_ecall || i_mret ||
                ((i_jal || i_jalr || i_is_brch) && !i_predict_correct));
```

Correctly predicted JAL/JALR/branch instructions now continue on the already fetched path.

### 3. Register Forwarding Incorrectly Forwarded Writes To `x0`

After JAL/RAS prediction was restored, the next instruction could see a wrong forwarded value from a retiring `ret` (`jalr x0, ra, 0`). Architecturally `x0` ignores writes, but the bypass network still forwarded `rd == x0`.

Fix:

```verilog
(raddr == exu_rd && exu_rd != 5'b0 && ...)
(raddr == wbu_rd && wbu_rd != 5'b0 && ...)
```

This keeps `x0` hardwired to zero in both storage and bypass behavior.

### 4. EXU/WBU Valid Handling During Flush

The EXU/WBU register can see a one-cycle flush window after a misprediction. It now clears valid when `i_flush` is observed with downstream readiness, preventing stale or wrong-path entries from being committed twice.

## Diagnostic Method Used

The successful debug path was architectural trace comparison:

1. Build a no-BTB reference with `EXTRA_VERILATOR_FLAGS=+define+DISABLE_BTB_PRED`.
2. Generate `--commit-trace` and `--mem-trace` for CoreMark.
3. Compare committed `pc/rd/wdata/store` streams.
4. Ignore timing-only differences from `mcycle` reads.
5. Fix the first real architectural divergence.

Important lesson: the simulator halt code is not sufficient for CoreMark correctness. CoreMark must be judged by its CRC text.

## Rejected Experiments

| Experiment | Result |
|------------|--------|
| Reset EXU/WBU directly on flush | Broke control-flow handoff |
| Flush earlier in the same branch cycle | Broke `quick-sort` or CoreMark |
| Gate EXU/LSU entry with flush | Broke multi-cycle handshakes |
| Keep BTB-only and disable JAL/RAS permanently | Correctness could be recovered, but left predictor incomplete |

These experiments were removed or superseded by the targeted fixes above.
