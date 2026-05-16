# CoreMark Results

This document records CoreMark correctness and performance for HelloCPU.

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

## Latest Validated Result

Command sequence:

```bash
make bench_only ITER=100 EXTRA_VERILATOR_FLAGS='-j 1'
```

Result:

```text
CoreMark Size    : 666
Total ticks      : 32236520
Iterations       : 100
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x988c
Correct operation validated.
Total cycles     : 32275229
CoreMark/MHz     : 3.098

[HelloCPU] PASS (cycles: 32279748)
```

This result was revalidated on the current stage-4 frontend-boundary branch on 2026-05-17, and it matched the existing validated baseline: `3.098 CoreMark/MHz` with `32,279,748` simulator cycles.

## Current Benchmark Summary

| Run | Result | CoreMark cycles | Simulator cycles | CoreMark/MHz | IPC | Stall rate |
|-----|--------|-----------------|------------------|--------------|-----|------------|
| ITER=1, full predictor + LSU fast paths | Correct CRC | 488632 | 491595 | 2.046 | 0.674 | 30.9% |
| ITER=100, full predictor + LSU fast paths | Correct CRC | 43871567 | 43876399 | 2.279 | 0.698 | 28.4% |
| ITER=100, low MUL fast path | Correct CRC | 41995856 | 42000681 | 2.381 | 0.729 | 25.2% |
| ITER=100, 128-entry BTB | Correct CRC | 41981715 | 41986504 | 2.381 | 0.729 | 25.2% |
| ITER=100, 128-entry BTB + LSU fast_done paths | Correct CRC | 41981176 | 41985905 | 2.382 | 0.729 | 25.2% |
| ITER=100, same-cycle load hit | Correct CRC | 36530875 | 36535445 | 2.737 | 0.838 | 14.1% |
| ITER=100, same-cycle load+store hit | Correct CRC | 35043392 | 35047662 | 2.853 | 0.874 | 10.4% |
| ITER=100, same-cycle hit + DIV fast path | Correct CRC | 35043392 | 35047662 | 2.853 | 0.874 | 10.4% |
| ITER=100, tournament+loop + 2-cycle redirect recovery + fetch queue checkpoint | Correct CRC | 32275229 | 32279748 | 3.098 | 0.883 | 11.7% |

ITER=100 is the better throughput reference because CoreMark initialization and reporting overhead are amortized across the timed workload. The current reference is the frontend branch run with tournament+loop predictor, validated `2-cycle` redirect recovery, and the current fetch-queue verification checkpoint.

Compared with the pre-LSU-fast-path ITER=100 reference (`1.545 CoreMark/MHz`, `IPC=0.473`, `51.5%` stalls), the current run raises throughput by about `100.5%` and cuts stall rate by `39.8` percentage points.

## Public Processor Comparison

The table below gives rough positioning against selected public EEMBC CoreMark submissions. It should not be read as a strict apples-to-apples ranking: compiler, memory placement, cache state, certification status, core count, and benchmark harness differ across submissions. For HelloCPU, the value is the local `ITER=100` simulator run above.

Source for external rows: EEMBC public CoreMark score database, queried on 2026-05-08.

| Processor / board | ISA / class | CoreMark/MHz | Relative to HelloCPU | Notes |
|-------------------|-------------|--------------|----------------------|-------|
| GOWIN PicoRV32 | RV32 softcore | 0.57 | 0.18x | Small FPGA-oriented RISC-V softcore |
| STM32F103C8T6 / Cortex-M3 | Arm Cortex-M3 MCU | 2.21 | 0.71x | Common low-cost MCU reference |
| Allwinner D1 | RISC-V application-class SoC | 2.24 | 0.72x | Public RISC-V Linux-capable SoC result |
| STM32F407VGT6 / Cortex-M4 | Arm Cortex-M4 MCU | 2.86 | 0.92x | Widely used MCU baseline |
| HelloCPU current | RV32IM + Zicsr teaching core | 3.098 | 1.00x | Local Verilator result, `ITER=100` |
| VEGA THEJAS32 | RISC-V MCU-class core | 3.33 | 1.08x | Public RISC-V microcontroller-class result |
| Renesas RA8T2 / Cortex-M33 | Arm Cortex-M33 MCU | 4.05 | 1.31x | Modern Cortex-M33 class |
| STM32F746 / Cortex-M7 | Arm Cortex-M7 MCU | 5.01 | 1.62x | High-performance Cortex-M MCU baseline |
| STM32H7Rx/7Sx / Cortex-M7 | Arm Cortex-M7 MCU | 5.33 | 1.72x | Faster Cortex-M7-class MCU result |
| Renesas RA8T2 / Cortex-M85 | Arm Cortex-M85 MCU | 6.38 | 2.06x | Modern high-end Cortex-M baseline |
| Raspberry Pi 4B / Cortex-A72 | Arm Cortex-A application core | 22.67 | 7.32x | Out-of-class application processor reference |

This places the current HelloCPU CoreMark/MHz slightly above the Cortex-M4 class, below the VEGA THEJAS32 / Cortex-M33 class, and far below application-class out-of-order or superscalar cores. That positioning is consistent with the current design: a simple in-order RV32IM core with branch prediction, caches, and same-cycle LSU hit eliminating load/store pipeline stalls.

## Predictor Comparison

| Configuration | Iterations | Result | Simulator cycles | CoreMark/MHz |
|---------------|------------|--------|------------------|--------------|
| No IFU prediction | 1 | Correct CRC | 855796 | 1.175 |
| BTB-only after branch recovery fix | 1 | Correct CRC | 744755 | 1.350 |
| Full BTB + RAS + static JAL | 1 | Correct CRC | 715631 | 1.404 |
| Full BTB + RAS + static JAL | 100 | Correct CRC | 64701101 | 1.545 |
| Full predictor + LSU fast paths | 1 | Correct CRC | 491595 | 2.046 |
| Full predictor + LSU fast paths | 100 | Correct CRC | 43876399 | 2.279 |
| Low `MUL` fast path | 100 | Correct CRC | 42000681 | 2.381 |
| 128-entry BTB | 100 | Correct CRC | 41986504 | 2.381 |
| Same-cycle load hit | 100 | Correct CRC | 36535445 | 2.737 |
| Same-cycle load+store hit | 100 | Correct CRC | 35047662 | 2.853 |
| Tournament+loop + 2-cycle redirect recovery + fetch queue checkpoint | 100 | Correct CRC | 32279748 | 3.098 |

The full predictor improved CoreMark ITER=1 by about 16.4% versus the no-prediction reference. The LSU fast-path work improved ITER=100 throughput by about 47.5% over the previous full-predictor baseline, and the low `MUL` fast path adds another 4.5% over the LSU fast-path reference. The same-cycle LSU hit (load + store) adds a further 19.8% over the pre-same-cycle baseline. The frontend branch predictor/recovery work then lifts throughput to `3.098 CoreMark/MHz`, for a cumulative 100.5% improvement from the pre-LSU-fast-path reference.

## Latest Performance Counters

```text
Total cycles         : 32279748
Total instructions   : 28511224 (IPC = 0.883)
True stall cycles    : 3768525 (11.7%)
Backend pipe occ     : 0 (0.0%)

Frontend/empty       : 3486137 (92.5% of stalls)
IFU held valid       : 10115 (0.3% of stalls)
  LSU                : 7284 (72.0% of held-valid stalls)
  MUL/DIV            : 2831 (28.0% of held-valid stalls)
    MUL              :    1 ( 0.0%)
    DIV              : 2830 (100.0%)
LSU wait             : 7562 (0.2% of stalls)
  start              : 777 (10.3% of LSU wait)
    load             : 98 (12.6% of start)
    store            : 679 (87.4% of start)
  refill             : 4172 (55.2% of LSU wait)
  uncached           : 2232
  writeback          : 381
MUL/DIV wait         : 2832 (0.1% of stalls)
  MUL                :    2 ( 0.1%)
  DIV                : 2830 (99.9%)
Control recovery     : 271994 (7.2% of stalls)
Other blocked bknd   : 0 (0.0% of stalls)

ALU ops              : 14766235 (51.8%)
Branches             : 5275333 (18.5%)
Jumps (JAL+JALR)     : 636912 (2.2%)
Loads                : 5473245 (19.2%)
Stores               : 1419687 (5.0%)
Multiplies           : 939699 (3.3%)
Divides              : 110

BTB hits             : 4518469 (84.8%)
BTB misses           : 807477 (15.2%)
BTB mispredicts      : 271994 (5.1%)
RAS hits             : 183025 (100.0%)
RAS misses           : 4
JAL target bad       : 0
WBU pcupdate         : 0
  branch             : 0 (0.0% of WBU pcupdate)
  JAL                : 0 (0.0% of WBU pcupdate)
  JALR               : 0 (0.0% of WBU pcupdate)
  ECALL              : 0
  MRET               : 0

Redirect cost        : 2 avg cycles (268639 events)
  branch             : 2 avg (236315 events)
  JALR               : 2 avg (32324 events)

ICache hits          : 29057825 (99.0%)
ICache misses        : 287147 (1.0%)
Load xacts           : 245 / done: 245
Store xacts          : 612 / done: 611
```

## Bottleneck Analysis

The same-cycle LSU hit optimizations fundamentally changed the bottleneck profile, and the frontend predictor/recovery work then removed another full redirect cycle. Total stalls dropped from `51.5%` (pre-LSU-fast-path) to `11.7%` on ITER=100. LSU wait remains negligible (`7,562` cycles, `0.2%` of stalls).

| Area | Evidence | Impact | Owner |
|------|----------|--------|-------|
| Frontend/empty | `3,486,137` cycles, `92.5%` of all stalls | **#1 bottleneck.** Redirect bubbles still dominate, but each redirect is now cheaper. | B |
| Control recovery | `271,994` cycles, `7.2%` of stalls | Redirect cost is now `2 avg cycles`, matching the intended recovery target. | B |
| Other blocked backend | `0` cycles, `0.0%` of stalls | Counter cleanup separates true stall from normal backend occupancy. | A |
| DIV stalls | `2,830` cycles, `0.1%` — 110 divides; still minimal for CoreMark. | Solved. Minimal for CoreMark. | A |
| LSU wait | `7,562` cycles, `0.2%` — only cache miss refill and uncached | **Solved.** Same-cycle load+store hit eliminated the dominant LSU stall. | A |
| ICache misses | `287,147` misses, `99.0%` hit rate | Not the primary bottleneck. | — |

### Same-Cycle LSU Hit Results

Two phases of LSU same-cycle optimization:

| Phase | Change | CoreMark/MHz | LSU wait |
|-------|--------|--------------|----------|
| Baseline (pre-same-cycle) | 1-cycle S_IDLE→S_CHECK penalty on every load/store | 2.382 | 6,979,639 (65.9%) |
| Same-cycle load hit | Load cache hit completes in S_IDLE, FSM stays idle | 2.737 (+14.9%) | 1,506,625 (29.3%) |
| Same-cycle store hit | Store cache hit completes in S_IDLE, writes data+dirty same cycle | 2.853 (+4.2%) | 7,107 (0.2%) |

Implementation: `lsu.v` only, +86 lines total. Adds combinational tag lookup from `alu_res` alongside existing `lat_addr` path. On cache hit, `lsu_done=1` same cycle, FSM stays `S_IDLE`. No frontend/pipeline protocol changes.

### Remaining Optimization Opportunities

| # | Optimization | Yield | Owner | Status |
|---|---|---|---|---|
| 1 | **Predictor direction refinement** (521K remaining mispredicts) | +1-3% | B | Current next target; errors are still mostly BTB-hit direction misses |
| 2 | **Stall counter cleanup** (separate true stall from normal backend occupancy) | Better observability | A | Done in current branch view |
| 3 | **Redirect recovery -1 cycle** | Achieved | B | Done in frontend branch; validated at `2 avg cycles` |
| 4 | DIV fast path (by-1, trivial-zero) | +0% for CoreMark | A | Done (`8f48295`) |
| 5 | AXI-level (combinational RREADY) | ~0% | — | Abandoned, AXI RAM incompatible |

### LSU AXI Optimization Results

Two approaches were tested:

| Approach | CoreMark Impact | Status |
|----------|----------------|--------|
| `fast_refill_done`, `fast_uncache_r_done`, `fast_uncache_b_done` | ~0% (-cache misses negligible) | Landed in `lsu.v` |
| Combinational RREADY (no registered handshake) | Simulation hang | Reverted; AXI RAM model requires 2-phase RVALID/RREADY |

The fast_done paths are kept because they improve uncache-path latency (relevant for MMIO workloads) and are correct. Combinational RREADY was abandoned because the simulation AXI RAM model uses a 2-phase FSM for R channel and cannot handle immediate RREADY assertion.

## Historical Baselines

| Stage | CoreMark/MHz | Notes |
|-------|--------------|-------|
| Initial ITER=1 baseline | 0.510 | Early simulation baseline |
| DCache enabled + ITER=100 | 0.662 | Reduced initialization skew |
| 4 KB ICache/DCache, no predictor | 1.293 | Historical ITER=100 result |
| No IFU prediction, ITER=1 | 1.175 | Correct CRC reference |
| Full predictor, ITER=1 | 1.404 | Historical predictor bring-up result |
| Full predictor, ITER=100 | 1.545 | Historical pre-LSU-fast-path throughput reference |
| LSU load/store hit fast paths + start pulse, ITER=1 | 2.046 | Current correctness smoke reference |
| LSU load/store hit fast paths + start pulse, ITER=100 | 2.279 | Historical pre-low-MUL-fast-path throughput reference |
| Low `MUL` fast path, ITER=100 | 2.381 | Current throughput reference |
| 128-entry BTB, ITER=100 | 2.381 | Small cycle reduction from `42000681` to `41986504`; rounded CoreMark/MHz unchanged |
| Same-cycle load hit, ITER=100 | 2.737 | +14.9% over baseline; LSU wait -78.4% |
| Same-cycle load+store hit, ITER=100 | 2.853 | +19.8% over baseline; LSU wait -99.9% |
| Same-cycle hit + DIV fast path, ITER=100 | 2.853 | DIV wait 3762→2962 (-21%); CoreMark unchanged |
| Tournament+loop + 2-cycle redirect recovery + fetch queue checkpoint, ITER=100 | 3.098 | +8.6% over same-cycle LSU baseline; redirect cost `3 -> 2` |

## Correctness Notes

CoreMark correctness must be judged from CoreMark's CRC output, not only from the simulator halt code. Earlier broken predictor configurations could print `[HelloCPU] PASS` while CoreMark itself printed `Errors detected`.
