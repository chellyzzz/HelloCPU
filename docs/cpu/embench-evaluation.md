# Embench Evaluation

This document records the current HelloCPU `Embench` bring-up subset and uses it as a second performance view alongside `CoreMark`.

## Environment

| Item | Value |
|------|-------|
| ISA | RV32IM + Zicsr |
| Compiler | `riscv64-linux-gnu-gcc 11.4.0` |
| Compiler flags | `rv32im_zicsr_-O2` |
| Memory base | `0x30000000` |
| ICache | 4 KB |
| DCache | 4 KB |
| Simulator | Verilator 5.008 |
| Embench mode | Minimal subset bring-up |
| `GLOBAL_SCALE_FACTOR` | `1` |
| `WARMUP_HEAT` | `1` |

## Commands

Fetch source:

```bash
make embench-fetch
```

Build subset:

```bash
make embench-build EXTRA_VERILATOR_FLAGS='-j 1'
```

Run subset:

```bash
make embench-run EXTRA_VERILATOR_FLAGS='-j 1'
```

Run one benchmark:

```bash
make embench-run-one ALL=crc32 EXTRA_VERILATOR_FLAGS='-j 1'
```

Logs are written to `build/embench/*.log`.

## Current Benchmark Summary

The current validated subset contains seven benchmarks:

- `crc32`
- `matmult-int`
- `nettle-aes`
- `nettle-sha256`
- `ud`
- `edn`
- `md5sum`

This is intentionally not a full-suite score run. The goal is broader workload coverage with a stable, reproducible subset that already separates frontend-sensitive, memory-sensitive, and long-latency-sensitive behavior.

| Benchmark | Result | Cycles | IPC | Stall rate | LSU wait | MUL/DIV wait | Control recovery | BTB mispredicts | Redirect cost |
|-----------|--------|--------|-----|------------|----------|--------------|------------------|-----------------|---------------|
| `crc32` | PASS | 4,031,588 | 1.000 | 0.0% | 1,114 | 0 | 20 | 10 | 3 avg |
| `matmult-int` | PASS | 3,304,620 | 0.842 | 15.8% | 494,061 | 26,208 | 100 | 50 | 3 avg |
| `nettle-aes` | PASS | 7,092,969 | 0.628 | 37.2% | 2,081,071 | 264,264 | 3,014 | 1,507 | 4 avg |
| `nettle-sha256` | PASS | 29,307,335 | 0.168 | 83.2% | 1,261 | 0 | 2,332 | 1,166 | 9 avg |
| `ud` | PASS | 3,336,091 | 0.789 | 21.1% | 713 | 494,722 | 103,758 | 51,879 | 3 avg |
| `edn` | PASS | 3,391,974 | 0.997 | 0.3% | 4,603 | 0 | 486 | 243 | 3 avg |
| `md5sum` | PASS | 3,090,145 | 0.989 | 1.1% | 3,635 | 0 | 13,636 | 6,818 | 3 avg |

Reference `CoreMark` snapshot from `docs/cpu/coremark-results.md`:

| Benchmark | Result | Cycles | IPC | Stall rate | LSU wait | Control recovery | BTB mispredicts | Redirect cost |
|-----------|--------|--------|-----|------------|----------|------------------|-----------------|---------------|
| `CoreMark` | PASS | 34,010,300 | 0.900 | 10.0% | 6,826 | 1,043,090 | 521,545 | 3 avg |

## Bottleneck Analysis

The current subset already shows that `CoreMark` is not a sufficient single benchmark lens.

### Regular scalar kernels

| Benchmark | Evidence | Interpretation |
|-----------|----------|----------------|
| `crc32` | `IPC = 1.000`, `1,712` true stall cycles, `10` BTB mispredicts | Confirms the scalar pipeline is healthy when the workload is regular and branch behavior is predictable. |
| `edn` | `IPC = 0.997`, `0.3%` stalls, `243` BTB mispredicts | Another near-ideal kernel; minor losses are not structural bottlenecks. |
| `md5sum` | `IPC = 0.989`, `1.1%` stalls, `13,636` control recovery cycles | Good throughput with some visible branch cost, but still close to the single-issue practical ceiling. |

These three runs matter because they show the machine is no longer broadly constrained by simple load-hit latency. On favorable kernels, most of the available single-issue throughput has already been recovered.

### Memory-service dominated kernels

| Benchmark | Evidence | Interpretation |
|-----------|----------|----------------|
| `matmult-int` | `494,061` LSU wait cycles, `182,998` writeback cycles inside LSU wait | Dense arithmetic does not make this frontend-bound; memory service remains the dominant cost. |
| `nettle-aes` | `2,081,071` LSU wait cycles, `264,264` divide wait cycles | This workload is clearly backend-dominated, with memory first and long-latency arithmetic second. |

These runs show that frontend gains which helped `CoreMark` do not move every integer workload equally. The next gains here come more from memory-service behavior and backend latency than from predictor tuning alone.

### Control and frontend dominated kernels

| Benchmark | Evidence | Interpretation |
|-----------|----------|----------------|
| `ud` | `103,758` control recovery cycles, `51,879` BTB mispredicts, `494,722` divide wait cycles | `ud` is split between redirect pressure and long-latency divide pressure; it is not well-described by `CoreMark` alone. |
| `nettle-sha256` | `24,389,124` frontend/empty stall cycles, `29.2%` ICache miss rate, `9` average redirect cost | This run is overwhelmingly frontend-dominated and is the strongest warning that broader code footprints still expose instruction-side structural limits. |

`nettle-sha256` is the standout counterexample to any claim that the current optimization story is mainly "done except for small cleanup." Its LSU wait is negligible, but it still collapses to `IPC = 0.168` because instruction-side delivery dominates the machine.

## What Embench Adds Beyond CoreMark

`CoreMark` still remains useful as a fast scalar sanity benchmark, but the Embench subset changes the architecture picture in three important ways.

1. It confirms the optimized scalar path is real.
   `crc32`, `edn`, and `md5sum` all run near `IPC = 1`, so the existing predictor and LSU work are not fake wins limited to one benchmark.

2. It shows the next bottleneck is workload-dependent.
   `matmult-int` and `nettle-aes` are mainly backend and memory-service limited, while `ud` mixes redirect and divide pressure, and `nettle-sha256` is dominated by frontend delivery.

3. It shows that additional local tuning will not produce a universal next jump.
   The remaining losses rotate between instruction delivery, redirect recovery, memory service, and long-latency arithmetic.

That is different from the earlier phase where one class of optimization, especially same-cycle LSU hit handling, clearly dominated the payoff curve.

## Decision Value

### Is the current optimization only helping `CoreMark`?

No.

The best Embench kernels also benefit: `crc32`, `edn`, and `md5sum` all validate that HelloCPU can now sustain near-ideal throughput on regular scalar code. But `CoreMark` still over-represents one part of the design space, because several Embench kernels are dominated by very different limits.

### Is it time to prepare for wider issue / multi-issue structure?

Yes.

The reason is not that every benchmark is already near `IPC = 1`. The reason is that the machine has reached the phase where no single local patch explains the remaining losses across the workload mix.

- Favorable kernels are already close to the practical single-issue ceiling.
- Unfavorable kernels now separate into distinct structural bottlenecks.
- Those bottlenecks sit at architectural boundaries: frontend delivery, redirect recovery, memory service, and long-latency execution.

That is exactly the stage where cleaner boundaries and wider-issue preparation become more valuable than continuing to treat `CoreMark` as the universal truth source.

## Recommendation

1. Keep `CoreMark` as the fast scalar regression benchmark.
2. Require this Embench subset in serious performance discussions.
3. Expand toward a larger subset or full suite later, but do not block current architecture judgment on official full-suite scoring.
4. Bias next architecture work toward boundary cleanup and wider-issue preparation rather than another round of benchmark-specific local tuning.

## Known Bring-Up Failure

`aha-mont64` is currently excluded from the default subset.

| Benchmark | Result | Cycles | IPC | Stall rate | LSU wait | MUL wait | Control recovery | BTB mispredicts | Redirect cost |
|-----------|--------|--------|-----|------------|----------|----------|------------------|-----------------|---------------|
| `aha-mont64` | FAIL | 5,440,738 | 0.943 | 5.7% | 375 | 32,653 | 136,560 | 68,280 | 3 avg |

The failure does not look like a simple memory bottleneck. The counters show low LSU pressure but meaningful multiply wait and high redirect activity, so this benchmark remains a useful follow-up for correctness/debug rather than a default performance subset member.
