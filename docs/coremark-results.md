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
Total ticks      : 41948024
Iterations       : 100
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x988c
Correct operation validated.
Total cycles     : 41995856
CoreMark/MHz     : 2.381

[HelloCPU] PASS (cycles: 42000681)
```

## Current Benchmark Summary

| Run | Result | CoreMark cycles | Simulator cycles | CoreMark/MHz | IPC | Stall rate |
|-----|--------|-----------------|------------------|--------------|-----|------------|
| ITER=1, full predictor + LSU fast paths | Correct CRC | 488632 | 491595 | 2.046 | 0.674 | 30.9% |
| ITER=100, full predictor + LSU fast paths | Correct CRC | 43871567 | 43876399 | 2.279 | 0.698 | 28.4% |
| ITER=100, low MUL fast path | Correct CRC | 41995856 | 42000681 | 2.381 | 0.729 | 25.2% |

ITER=100 is the better throughput reference because CoreMark initialization and reporting overhead are amortized across the timed workload. The current reference is the low `MUL` fast-path run.

The current A stable-candidate WIP adds only LSU start load/store attribution and behavior-equivalent IFU `fetch_fire` naming on top of that result, so the CoreMark throughput number remains unchanged.

Compared with the pre-LSU-fast-path ITER=100 reference (`1.545 CoreMark/MHz`, `IPC=0.473`, `51.5%` stalls), the LSU and low `MUL` fast-path optimizations raise throughput by about 54.1% and cut stall rate by 26.3 percentage points.

## Public Processor Comparison

The table below gives rough positioning against selected public EEMBC CoreMark submissions. It should not be read as a strict apples-to-apples ranking: compiler, memory placement, cache state, certification status, core count, and benchmark harness differ across submissions. For HelloCPU, the value is the local `ITER=100` simulator run above.

Source for external rows: EEMBC public CoreMark score database, queried on 2026-05-08.

| Processor / board | ISA / class | CoreMark/MHz | Relative to HelloCPU | Notes |
|-------------------|-------------|--------------|----------------------|-------|
| GOWIN PicoRV32 | RV32 softcore | 0.57 | 0.24x | Small FPGA-oriented RISC-V softcore |
| STM32F103C8T6 / Cortex-M3 | Arm Cortex-M3 MCU | 2.21 | 0.93x | Common low-cost MCU reference |
| Allwinner D1 | RISC-V application-class SoC | 2.24 | 0.94x | Public RISC-V Linux-capable SoC result |
| HelloCPU current | RV32IM + Zicsr teaching core | 2.381 | 1.00x | Local Verilator result, `ITER=100` |
| STM32F407VGT6 / Cortex-M4 | Arm Cortex-M4 MCU | 2.86 | 1.20x | Widely used MCU baseline |
| VEGA THEJAS32 | RISC-V MCU-class core | 3.33 | 1.40x | Public RISC-V microcontroller-class result |
| Renesas RA8T2 / Cortex-M33 | Arm Cortex-M33 MCU | 4.05 | 1.70x | Modern Cortex-M33 class |
| STM32F746 / Cortex-M7 | Arm Cortex-M7 MCU | 5.01 | 2.10x | High-performance Cortex-M MCU baseline |
| STM32H7Rx/7Sx / Cortex-M7 | Arm Cortex-M7 MCU | 5.33 | 2.24x | Faster Cortex-M7-class MCU result |
| Renesas RA8T2 / Cortex-M85 | Arm Cortex-M85 MCU | 6.38 | 2.68x | Modern high-end Cortex-M baseline |
| Raspberry Pi 4B / Cortex-A72 | Arm Cortex-A application core | 22.67 | 9.52x | Out-of-class application processor reference |

This places the current HelloCPU CoreMark/MHz slightly above older Cortex-M3 / entry RISC-V public submissions, below mature Cortex-M4/M7/M85 microcontroller-class cores, and far below application-class out-of-order or superscalar cores. That positioning is consistent with the current design: a simple in-order RV32IM core with useful branch prediction and caches, but still significant LSU/load-use backpressure.

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

The full predictor improved CoreMark ITER=1 by about 16.4% versus the no-prediction reference. The LSU fast-path work improved ITER=100 throughput by about 47.5% over the previous full-predictor baseline, and the low `MUL` fast path adds another 4.5% over the LSU fast-path reference.

## Latest Performance Counters

```text
Total cycles         : 42000681
Total instructions   : 30618174 (IPC = 0.729)
Stall cycles         : 10592012 (25.2%)

Frontend/empty       : 1955405 (18.5% of stalls)
IFU held valid       : 6973146 (65.8% of stalls)
  LSU                : 6969244 (99.9% of held-valid stalls)
  MUL/DIV            :    3689 ( 0.1% of held-valid stalls)
    MUL              :       0 ( 0.0% of MUL/DIV held-valid stalls)
    DIV              :    3689 (100.0% of MUL/DIV held-valid stalls)
LSU wait             : 6980532 (65.9% of stalls)
  start              : 6973588 (99.9% of LSU wait)
    load             : 5473195 (78.5% of start)
    store            : 1500393 (21.5% of start)
  refill             : 3965 (0.1% of LSU wait)
    AR wait          : 1130 (28.5% of refill)
    R data           : 2508 (63.2% of refill)
  uncached           : 2705
  writeback          : 274
MUL/DIV wait         :    3762 (0.0% of stalls)
  MUL                :       0 ( 0.0% of MUL/DIV wait)
  DIV                :    3762 (100.0% of MUL/DIV wait)
Control recovery     : 805218 (7.6% of stalls)
Other backend        : 847095 (8.0% of stalls)

ALU ops              : 15816432 (51.7%)
Branches             : 6241782 (20.4%)
Jumps (JAL+JALR)     : 633875 (2.1%)
Loads                : 5480739 (17.9%)
Stores               : 1505532 (4.9%)
Multiplies           : 939697 (3.1%)
Divides              : 114

BTB hits             : 5887034 (84.5%)
BTB misses           : 1082991 (15.5%)
BTB mispredicts      : 790496 (11.3%)
RAS hits             : 204863 (99.2%)
RAS misses           : 1738 (0.8%)
JAL target bad       : 0
WBU pcupdate         : 805218

ICache hits          : 40739669 (99.7%)
ICache misses        : 122768 (0.3%)
Load xacts           : 209 / done: 209
Store xacts          : 596 / done: 595
```

## Bottleneck Analysis

The current bottleneck is still pipeline stalls rather than instruction-cache capacity or external memory traffic, but the LSU and low `MUL` fast-path work changed the scale of the problem: total stalls dropped from `51.5%` to `25.2%` on ITER=100.

| Area | Evidence | Impact |
|------|----------|--------|
| LSU/internal data stalls | `LSU wait` is `6980532` cycles, `65.9%` of all stalls; `start` is `6973588` cycles (`78.5%` load / `21.5%` store); refill is only `3965` cycles | Remaining LSU cost is mostly request start, load-use, and main-pipeline coupling, not memory refill |
| Branch recovery | Branches are `20.4%`; BTB mispredicts are `790496` (`11.3%`) and WBU redirects are `805218` | Now the second-largest explicit remaining class after LSU |
| MUL/DIV stalls | `MUL/DIV wait` is only `3762` cycles after the low `MUL` fast path, all from DIV | No longer a CoreMark bottleneck, but still relevant for division-heavy programs |
| ICache misses | ICache hit rate is `99.7%`; only `122768` IFU fetches for 42.0M cycles | Not the primary bottleneck after 4 KB ICache |
| DCache/AXI traffic | Load transactions are only `209`; store transactions are `596` | External memory bandwidth is not saturated |

The most useful next optimizations are therefore microarchitectural rather than predictor-capacity changes:

1. Continue LSU work, but focus on hit/load-use/internal coupling rather than raw AXI refill bandwidth.
2. Improve branch recovery latency for the remaining `~0.8M` WBU redirects.
3. Keep DIV as a separate target for division-heavy programs.
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

## Correctness Notes

CoreMark correctness must be judged from CoreMark's CRC output, not only from the simulator halt code. Earlier broken predictor configurations could print `[HelloCPU] PASS` while CoreMark itself printed `Errors detected`.
