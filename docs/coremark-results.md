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
make clean
make sim
make -C sw benchmark ITER=100 -B
./build/Vsim_top sw/build/coremark.bin --max-cycles=100000000
```

Result:

```text
CoreMark Size    : 666
Total ticks      : 64632033
Iterations       : 100
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x988c
Correct operation validated.
Total cycles     : 64695430
CoreMark/MHz     : 1.545

[HelloCPU] PASS (cycles: 64701101)
```

## Current Benchmark Summary

| Run | Result | CoreMark cycles | Simulator cycles | CoreMark/MHz | IPC | Stall rate |
|-----|--------|-----------------|------------------|--------------|-----|------------|
| ITER=1, full predictor | Correct CRC | 711745 | 715631 | 1.404 | 0.463 | 52.5% |
| ITER=100, full predictor | Correct CRC | 64695430 | 64701101 | 1.545 | 0.473 | 51.5% |

ITER=100 is the better throughput reference because CoreMark initialization and reporting overhead are amortized across the timed workload.

## Predictor Comparison

| Configuration | Iterations | Result | Simulator cycles | CoreMark/MHz |
|---------------|------------|--------|------------------|--------------|
| No IFU prediction | 1 | Correct CRC | 855796 | 1.175 |
| BTB-only after branch recovery fix | 1 | Correct CRC | 744755 | 1.350 |
| Full BTB + RAS + static JAL | 1 | Correct CRC | 715631 | 1.404 |
| Full BTB + RAS + static JAL | 100 | Correct CRC | 64701101 | 1.545 |

The full predictor improves CoreMark ITER=1 by about 16.4% versus the no-prediction reference.

## Latest Performance Counters

```text
Total cycles         : 64701101
Total instructions   : 30617939 (IPC = 0.473)
Stall cycles         : 33293507 (51.5%)

ALU ops              : 15816201 (51.7%)
Branches             : 6241780 (20.4%)
Jumps (JAL+JALR)     : 633873 (2.1%)
Loads                : 5480739 (17.9%)
Stores               : 1505532 (4.9%)
Multiplies           : 939697 (3.1%)
Divides              : 114

BTB hits             : 5887743 (84.5%)
BTB misses           : 1081632 (15.5%)
BTB mispredicts      : 789656 (11.3%)
RAS hits             : 205556 (99.5%)
RAS misses           : 1045 (0.5%)
JAL target bad       : 0
WBU pcupdate         : 803517

ICache hits          : 63503760 (99.8%)
ICache misses        : 121414 (0.2%)
Load xacts           : 209 / done: 209
Store xacts          : 600 / done: 599
```

## Bottleneck Analysis

The current bottleneck is still pipeline stalls rather than instruction-cache capacity or external memory traffic.

| Area | Evidence | Impact |
|------|----------|--------|
| Pipeline stalls | `33293507` stall cycles, `51.5%` of total runtime | Dominant limiter of IPC |
| Load-use/data hazards | Loads are `17.9%` of committed instructions while load AXI transactions are only `209` | Most load cost is pipeline dependency handling, not DCache misses |
| Branch recovery | Branches are `20.4%`; BTB mispredicts are `789656` (`11.3%`) and WBU redirects are `803517` | Still meaningful, but smaller than general stalls |
| ICache misses | ICache hit rate is `99.8%`; only `121414` IFU fetches for 64.7M cycles | Not the primary bottleneck after 4 KB ICache |
| DCache/AXI traffic | Store/load bus transactions are low compared with instruction count | External memory bandwidth is not saturated |

The most useful next optimizations are therefore microarchitectural rather than predictor-capacity changes:

1. Reduce load-use penalties with stronger forwarding or a narrower interlock window.
2. Reduce structural stalls around LSU, WBU, and register-file bypass timing.
3. Improve branch recovery latency for the remaining `~0.8M` WBU redirects.
4. Revisit multi-cycle unit handshakes so non-dependent instructions can advance more often.

## Historical Baselines

| Stage | CoreMark/MHz | Notes |
|-------|--------------|-------|
| Initial ITER=1 baseline | 0.510 | Early simulation baseline |
| DCache enabled + ITER=100 | 0.662 | Reduced initialization skew |
| 4 KB ICache/DCache, no predictor | 1.293 | Historical ITER=100 result |
| No IFU prediction, ITER=1 | 1.175 | Correct CRC reference |
| Full predictor, ITER=1 | 1.404 | Current validated result |
| Full predictor, ITER=100 | 1.545 | Current throughput reference |

## Correctness Notes

CoreMark correctness must be judged from CoreMark's CRC output, not only from the simulator halt code. Earlier broken predictor configurations could print `[HelloCPU] PASS` while CoreMark itself printed `Errors detected`.
