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
make sim
make -C sw benchmark ITER=100 -B
./build/Vsim_top sw/build/coremark.bin --max-cycles=100000000
```

Result:

```text
CoreMark Size    : 666
Total ticks      : 35044000
Iterations       : 100
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x988c
Correct operation validated.
Total cycles     : 35044000
CoreMark/MHz     : 2.853

[HelloCPU] PASS (cycles: 35048462)
```

## Current Benchmark Summary

| Run | Result | CoreMark cycles | Simulator cycles | CoreMark/MHz | IPC | Stall rate |
|-----|--------|-----------------|------------------|--------------|-----|------------|
| ITER=1, full predictor + LSU fast paths | Correct CRC | 488632 | 491595 | 2.046 | 0.674 | 30.9% |
| ITER=100, full predictor + LSU fast paths | Correct CRC | 43871567 | 43876399 | 2.279 | 0.698 | 28.4% |
| ITER=100, low MUL fast path | Correct CRC | 41995856 | 42000681 | 2.381 | 0.729 | 25.2% |
| ITER=100, 128-entry BTB | Correct CRC | 41981715 | 41986504 | 2.381 | 0.729 | 25.2% |
| ITER=100, 128-entry BTB + LSU fast_done paths | Correct CRC | 41981176 | 41985905 | 2.382 | 0.729 | 25.2% |
| ITER=100, same-cycle load hit | Correct CRC | 36530875 | 36535445 | 2.737 | 0.838 | 14.1% |
| ITER=100, same-cycle load+store hit | Correct CRC | 35044000 | 35048462 | 2.853 | 0.874 | 10.4% |

ITER=100 is the better throughput reference because CoreMark initialization and reporting overhead are amortized across the timed workload. The current reference is the same-cycle load+store hit run.

Compared with the pre-LSU-fast-path ITER=100 reference (`1.545 CoreMark/MHz`, `IPC=0.473`, `51.5%` stalls), the same-cycle LSU hit optimizations raise throughput by about 84.7% and cut stall rate by 41.1 percentage points.

## Public Processor Comparison

The table below gives rough positioning against selected public EEMBC CoreMark submissions. It should not be read as a strict apples-to-apples ranking: compiler, memory placement, cache state, certification status, core count, and benchmark harness differ across submissions. For HelloCPU, the value is the local `ITER=100` simulator run above.

Source for external rows: EEMBC public CoreMark score database, queried on 2026-05-08.

| Processor / board | ISA / class | CoreMark/MHz | Relative to HelloCPU | Notes |
|-------------------|-------------|--------------|----------------------|-------|
| GOWIN PicoRV32 | RV32 softcore | 0.57 | 0.24x | Small FPGA-oriented RISC-V softcore |
| STM32F103C8T6 / Cortex-M3 | Arm Cortex-M3 MCU | 2.21 | 0.93x | Common low-cost MCU reference |
| Allwinner D1 | RISC-V application-class SoC | 2.24 | 0.94x | Public RISC-V Linux-capable SoC result |
| HelloCPU current | RV32IM + Zicsr teaching core | 2.853 | 1.00x | Local Verilator result, `ITER=100` |
| STM32F407VGT6 / Cortex-M4 | Arm Cortex-M4 MCU | 2.86 | 1.00x | Widely used MCU baseline |
| VEGA THEJAS32 | RISC-V MCU-class core | 3.33 | 1.40x | Public RISC-V microcontroller-class result |
| Renesas RA8T2 / Cortex-M33 | Arm Cortex-M33 MCU | 4.05 | 1.70x | Modern Cortex-M33 class |
| STM32F746 / Cortex-M7 | Arm Cortex-M7 MCU | 5.01 | 2.10x | High-performance Cortex-M MCU baseline |
| STM32H7Rx/7Sx / Cortex-M7 | Arm Cortex-M7 MCU | 5.33 | 2.24x | Faster Cortex-M7-class MCU result |
| Renesas RA8T2 / Cortex-M85 | Arm Cortex-M85 MCU | 6.38 | 2.68x | Modern high-end Cortex-M baseline |
| Raspberry Pi 4B / Cortex-A72 | Arm Cortex-A application core | 22.67 | 9.52x | Out-of-class application processor reference |

This places the current HelloCPU CoreMark/MHz approximately level with the Cortex-M4 class, below mature Cortex-M7/M85 microcontroller-class cores, and far below application-class out-of-order or superscalar cores. That positioning is consistent with the current design: a simple in-order RV32IM core with branch prediction, caches, and same-cycle LSU hit eliminating load/store pipeline stalls.

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
| Same-cycle load+store hit | 100 | Correct CRC | 35048462 | 2.853 |

The full predictor improved CoreMark ITER=1 by about 16.4% versus the no-prediction reference. The LSU fast-path work improved ITER=100 throughput by about 47.5% over the previous full-predictor baseline, and the low `MUL` fast path adds another 4.5% over the LSU fast-path reference. The same-cycle LSU hit (load + store) adds a further 19.8% over the pre-same-cycle baseline, for a cumulative 84.7% improvement from the pre-LSU-fast-path reference.

## Latest Performance Counters

```text
Total cycles         : 35048462
Total instructions   : 30618174 (IPC = 0.874)
Stall cycles         : 3649503 (10.4%)

Frontend/empty       : 2005006 (54.9% of stalls)
IFU held valid       : 849791 (23.3% of stalls)
  LSU                : 819511 (96.4% of held-valid stalls)
  MUL/DIV            : 30280 (3.6% of held-valid stalls)
    MUL              :     0 ( 0.0% of MUL/DIV held-valid stalls)
    DIV              : 30280 (100.0% of MUL/DIV held-valid stalls)
LSU wait             : 7107 (0.2% of stalls)
  start              : 6474 (91.1% of LSU wait)
    load             : 6043 (93.3% of start)
    store            : 431 (6.7% of start)
  refill             : 260 (3.7% of LSU wait)
    AR wait          : 81 (31.2% of refill)
    R data           : 159 (61.2% of refill)
  uncached           : 152
  writeback          : 18
MUL/DIV wait         : 30280 (0.8% of stalls)
  MUL                :     0 ( 0.0% of MUL/DIV wait)
  DIV                : 30280 (100.0% of MUL/DIV wait)
Control recovery     : 795702 (21.8% of stalls)
Other backend        : 0 (0.0% of stalls)

ALU ops              : 15816432 (51.7%)
Branches             : 6241782 (20.4%)
Jumps (JAL+JALR)     : 633875 (2.1%)
Loads                : 5480739 (17.9%)
Stores               : 1505532 (4.9%)
Multiplies           : 939697 (3.1%)
Divides              : 114

BTB hits             : 5939881 (85.3%)
BTB misses           : 1025584 (14.7%)
BTB mispredicts      : 780786 (11.2%)
RAS hits             : 204795 (99.4%)
RAS misses           : 1268 (0.6%)
JAL target bad       : 0
WBU pcupdate         : 795702
  branch             : 754234 (94.8% of WBU pcupdate)
  JAL                : 4966 (0.6% of WBU pcupdate)
  JALR               : 36502 (4.6% of WBU pcupdate)
  ECALL              : 0
  MRET               : 0

Redirect cost        : 3 avg cycles (772653 events)
  branch             : 3 avg (731392 events)
  JAL                : 20 avg (4962 events)
  JALR               : 3 avg (36299 events)

ICache hits          : 35234468 (99.6%)
ICache misses        : 124452 (0.4%)
Load xacts           : 209 / done: 209
Store xacts          : 600 / done: 599
```

## Bottleneck Analysis

The same-cycle LSU hit optimizations have fundamentally changed the bottleneck profile. Total stalls dropped from `51.5%` (pre-LSU-fast-path) to `10.4%` on ITER=100. LSU wait is now negligible (`7,107` cycles, `0.2%` of stalls).

| Area | Evidence | Impact |
|------|----------|--------|
| Frontend/empty | `2,005,006` cycles, `54.9%` of all stalls | **New #1 bottleneck.** Likely dominated by branch recovery pipeline bubble (772K redirects × 3 cycles ≈ 2.3M) |
| Branch recovery | `795,702` redirects, `3` avg cycles, `21.8%` of stalls; `754,234` branch (`94.8%`), `4,962` JAL (`0.6%`), `36,502` JALR (`4.6%`) | Now second-largest stall class; most recovery cost is branch-driven |
| DIV stalls | `30,280` cycles, `0.8%` of stalls | Small but non-zero; 114 divides |
| LSU wait | `7,107` cycles, `0.2%` of stalls — only cache miss refill and uncacheable | **Solved.** Same-cycle load+store hit eliminated 99.9% of LSU stall |
| ICache misses | `124,452` misses, `99.6%` hit rate | Not the primary bottleneck |
| DCache/AXI traffic | Load transactions `209`; store transactions `600` | External memory bandwidth is not saturated |

### Same-Cycle LSU Hit Results

Two phases of LSU same-cycle optimization:

| Phase | Change | CoreMark/MHz | LSU wait |
|-------|--------|--------------|----------|
| Baseline (pre-same-cycle) | 1-cycle S_IDLE→S_CHECK penalty on every load/store | 2.382 | 6,979,639 (65.9%) |
| Same-cycle load hit | Load cache hit completes in S_IDLE, FSM stays idle | 2.737 (+14.9%) | 1,506,625 (29.3%) |
| Same-cycle store hit | Store cache hit completes in S_IDLE, writes data+dirty same cycle | 2.853 (+4.2%) | 7,107 (0.2%) |

Implementation: `lsu.v` only, +86 lines total. Adds combinational tag lookup from `alu_res` alongside existing `lat_addr` path. On cache hit, `lsu_done=1` same cycle, FSM stays `S_IDLE`. No frontend/pipeline protocol changes.

### Remaining Optimization Opportunities

1. **Frontend bubble reduction** (highest yield, +5-6% CoreMark/MHz): 2M frontend/empty cycles. Root cause analysis needed — likely branch recovery pipeline bubble. B-line Task-4 assigned.
2. **Branch recovery -1 cycle** (medium yield, +2% CoreMark/MHz): Reducing 3→2 avg cycles saves ~772K cycles. Requires redirect/flush timing redesign.
3. **DIV optimization** (low yield for CoreMark, relevant for other workloads): 30K cycles from 114 divides.
4. **AXI-level optimizations** (negligible for CoreMark): Combinational RREADY abandoned; AXI RAM model incompatible.

### LSU AXI Optimization Results

Two approaches were tested:

| Approach | CoreMark Impact | Status |
|----------|----------------|--------|
| `fast_refill_done`, `fast_uncache_r_done`, `fast_uncache_b_done` | ~0% (-cache misses negligible) | Landed in `lsu.v` |
| Combinational RREADY (no registered handshake) | Simulation hang | Reverted; AXI RAM model requires 2-phase RVALID/RREADY |

The fast_done paths are kept because they improve uncache-path latency (relevant for MMIO workloads) and are correct. Combinational RREADY was abandoned because the simulation AXI RAM model uses a 2-phase FSM for R channel and cannot handle immediate RREADY assertion.
4. Revisit register-file bypass and interlock timing once pipeline valid/ready boundaries are cleaner.

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

## Correctness Notes

CoreMark correctness must be judged from CoreMark's CRC output, not only from the simulator halt code. Earlier broken predictor configurations could print `[HelloCPU] PASS` while CoreMark itself printed `Errors detected`.
