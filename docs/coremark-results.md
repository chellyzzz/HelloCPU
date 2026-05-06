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
make -C sw benchmark ITER=1 -B
./build/Vsim_top sw/build/coremark.bin --max-cycles=100000000
```

Result:

```text
CoreMark Size    : 666
Total ticks      : 648967
Iterations       : 1
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xe714
Correct operation validated.
Total cycles     : 711745
CoreMark/MHz     : 1.404

[HelloCPU] PASS (cycles: 715631)
```

## Predictor Comparison

| Configuration | Result | Simulator cycles | CoreMark/MHz |
|---------------|--------|------------------|--------------|
| No IFU prediction | Correct CRC | 855796 | 1.175 |
| BTB-only after branch recovery fix | Correct CRC | 744755 | 1.350 |
| Full BTB + RAS + static JAL | Correct CRC | 715631 | 1.404 |

The full predictor improves CoreMark ITER=1 by about 16.4% versus the no-prediction reference.

## Latest Performance Counters

```text
Total cycles         : 715631
Total instructions   : 331154 (IPC = 0.463)
Stall cycles         : 375792 (52.5%)

ALU ops              : 170818 (51.6%)
Branches             : 66856 (20.2%)
Jumps (JAL+JALR)     : 8044 (2.4%)
Loads                : 57920 (17.5%)
Stores               : 17921 (5.4%)
Multiplies           : 9493 (2.9%)
Divides              : 99

BTB hits             : 62766 (84.0%)
BTB misses           : 11950 (16.0%)
BTB mispredicts      : 8686 (11.6%)
RAS hits             : 2732 (98.0%)
RAS misses           : 55 (2.0%)
JAL target bad       : 0
WBU pcupdate         : 8909
```

## Historical Baselines

| Stage | CoreMark/MHz | Notes |
|-------|--------------|-------|
| Initial ITER=1 baseline | 0.510 | Early simulation baseline |
| DCache enabled + ITER=100 | 0.662 | Reduced initialization skew |
| 4 KB ICache/DCache, no predictor | 1.293 | Historical ITER=100 result |
| No IFU prediction, ITER=1 | 1.175 | Correct CRC reference |
| Full predictor, ITER=1 | 1.404 | Current validated result |

## Correctness Notes

CoreMark correctness must be judged from CoreMark's CRC output, not only from the simulator halt code. Earlier broken predictor configurations could print `[HelloCPU] PASS` while CoreMark itself printed `Errors detected`.
