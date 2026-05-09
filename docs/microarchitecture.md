# HelloCPU Microarchitecture

This document describes the CPU microarchitecture. Project usage, build commands, and validation status live in `../README.md`.

## Pipeline Overview

HelloCPU is an in-order RV32IM + Zicsr core with valid/ready-style pipeline flow control.

```text
IFU -> IDU -> EXU -> WBU -> Register File
 |            |
 v            v
ICache      ALU / LSU / Multiplier / Divider / Branch
 |            |
 +------------+-> Xbar -> AXI RAM / MMIO
```

Pipeline stages exchange `valid` and `ready` information so multi-cycle units can apply backpressure.

## IFU

The instruction fetch unit owns the fetch PC and selects the next PC from these sources, in priority order:

| Source | Purpose |
|--------|---------|
| EXU redirect | Recovery from misprediction |
| WBU PC update | Architectural redirect for unresolved control flow and traps |
| Predictor target | BTB, RAS, or static JAL prediction |
| `pc + 4` | Sequential fetch |

The IFU reads instructions through a 4 KB ICache. A cache hit can deliver an instruction without an AXI transaction; a miss fetches a cache line through the Xbar.

## IDU

The instruction decode unit is combinational and decodes RV32I, RV32M, and Zicsr instructions. It generates:

| Output | Purpose |
|--------|---------|
| Immediate values | I/S/B/U/J formats |
| ALU operation | Arithmetic, logic, shift, compare |
| EXU operation | Load/store width, multiply/divide mode, branch mode |
| Register controls | Source/destination register addresses and write enable |
| Control-flow signals | Branch, JAL, JALR, ecall, mret |
| Predictor metadata | Predicted-taken bit and predicted target |

## EXU

The execution stage contains the ALU, branch comparator, multiplier, divider, LSU, and predictor update logic.

| Unit | Latency | Notes |
|------|---------|-------|
| ALU | 1 cycle | Add/sub, logic, shifts, comparisons |
| Branch | 1 cycle | BEQ/BNE/BLT/BGE/BLTU/BGEU |
| Multiplier | 2 cycles | Booth-2 partial products and Wallace tree compression |
| Divider | Multi-cycle | Radix-2 non-restoring divider |
| LSU | Variable | DCache access or uncached AXI transaction |

The EXU checks predicted direction and target against actual control-flow results. On mismatch it raises `o_mispredict_flush` and provides `o_redirect_pc`.

### LSU Timing

The LSU contains the DCache arrays, cache hit/miss logic, refill/writeback control, and uncached AXI paths. It is still a blocking in-order unit from the pipeline's point of view, but several high-frequency paths are shortened:

| Path | Current behavior |
|------|------------------|
| Load hit | Completes from `S_CHECK` with combinational `load_res` selection |
| Store hit | Completes from `S_CHECK` while updating cache data, dirty state, and PLRU |
| LSU request start | Uses a single registered previous-start bit to detect a new transaction without the older extra delay flop |
| Refill | Uses conservative pulsed `RREADY`; continuous `RREADY` was tested and rejected because it can hang refill reception |
| Uncached access | Remains a simple single-beat AXI path |

The important design boundary is that fast cache-hit paths are allowed to reduce visible LSU latency, while refill burst timing stays conservative until the AXI RAM model and LSU response path are refactored together.

## WBU

The writeback unit commits EXU results into the register file or CSR file and generates architectural PC updates. Correctly predicted branches, JALs, and JALRs do not force redundant WBU redirects; unresolved or mispredicted control flow still redirects the front end.

## Register File

The register file has 32 architectural registers, with `x0` hardwired to zero. It supports two read ports, one write port, and bypassing from EXU/WBU results.

Forwarding excludes `rd == x0` so writes that architecturally disappear do not pollute dependent source reads.

## Caches And Memory

| Component | Configuration |
|-----------|---------------|
| ICache | 4 KB, line refill through AXI read channel |
| DCache | 4 KB, write-back/write-allocate |
| Cacheable range | `0x30000000` to `0x40000000` |
| Main memory | 64 MB DPI-C model at `0x30000000` |

The IFU uses read-only AXI channels. The LSU uses AXI read, write, and response channels. The Xbar arbitrates access to RAM and MMIO.

## CSRs

Implemented CSR support includes machine-level CSRs used by the test environment and CoreMark timing path, including `mcycle`.

## Branch Prediction Summary

The predictor is integrated into IFU and verified in EXU:

| Component | Role |
|-----------|------|
| BTB | Conditional branch direction and target prediction |
| RAS | Return target prediction for `jalr x0, ra, 0` |
| Static JAL | JAL target computation in IFU |

Detailed predictor behavior is documented in `branch-predictor-design.md`.

## Performance Counters

Performance counter hooks are emitted from `vsrc/top/hcpu.v` through DPI-C calls. They report instruction mix, stalls, cache activity, AXI transactions, branch prediction statistics, and commit PC hotspots.

The current stall counters distinguish `Frontend/empty`, `IFU held valid`, `LSU wait`, `MUL/DIV wait`, `COP wait`, `Control recovery`, and `Other backend`. LSU wait is further split into hit, refill, refill AR wait, refill R data, uncached, and writeback classes. MUL/DIV wait is also split into MUL and DIV sub-classes, including the IFU-held-valid view.

Current CoreMark `ITER=100` reference after the LSU fast-path work:

| Metric | Value |
|--------|-------|
| CoreMark/MHz | `2.381` |
| Simulator cycles | `42000681` |
| IPC | `0.729` |
| Stall rate | `25.2%` |
| LSU wait | `6980532` cycles (`65.9%` of stalls) |
| MUL/DIV wait | `3762` cycles, all from DIV after the low `MUL` fast path |

This confirms that the remaining CoreMark bottleneck is not ICache capacity or AXI refill bandwidth. LSU hit/load-use coupling is still the largest issue; low `MUL` backpressure has been removed from the CoreMark bottleneck list.
