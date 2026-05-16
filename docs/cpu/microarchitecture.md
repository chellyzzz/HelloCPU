# HelloCPU Microarchitecture

This document describes the current CPU microarchitecture. Build commands and usage live in `../../README.md`.

## Pipeline Overview

HelloCPU is an in-order RV32IM + Zicsr core with valid/ready pipeline control.

```text
IFU -> IDU -> EXU/COP -> WBU -> Register File
 |              |
 v              v
ICache        ALU / LSU / Multiplier / Divider / Branch / COP backend
 |              |
 +--------------+-> Xbar -> AXI RAM / MMIO
```

Current validated throughput: `2.940 CoreMark/MHz`, `IPC=0.900`, `10.0%` stall rate.

## IFU

The IFU owns the fetch PC and selects the next PC from these sources, in priority order:

| Source | Purpose |
|--------|---------|
| EXU redirect | Mispredict recovery |
| WBU PC update | Architectural redirect / unresolved control flow |
| Predictor target | BTB/tournament/loop, RAS, or static JAL prediction |
| `pc + 4` | Sequential fetch |

The IFU reads through a 4 KB ICache. Cache hit rate on CoreMark is `99.6%`, so current frontend bottleneck is not cache capacity but redirect recovery.

## IDU

The IDU is combinational. It decodes RV32I, RV32M, and Zicsr instructions and produces:

- immediate values
- ALU operation
- EXU operation (load/store width, mul/div mode, branch mode)
- register controls
- control-flow signals
- predictor metadata

The IFU/IDU boundary uses registered valid with payload and predictor metadata held stable under backpressure. IDU/EXU captures the accepted payload so branch resolution checks the prediction attached to the same instruction.

## EXU

The EXU contains the ALU, branch logic, multiplier, divider, LSU, and redirect generation.

| Unit | Latency | Notes |
|------|---------|-------|
| ALU | 1 cycle | add/sub/logic/shift/compare |
| Branch | 1 cycle | resolves direction and target |
| Multiplier | 0 or 2 cycles | low `MUL` fast path is combinational; high-part multiply remains multi-cycle |
| Divider | multi-cycle | radix-2 non-restoring divider with trivial fast paths |
| LSU | 0 / variable | same-cycle cache-hit paths; miss and uncached remain blocking |

On branch mismatch, EXU raises `o_mispredict_flush` and provides `o_redirect_pc`.

## LSU

The LSU contains the DCache arrays, cache hit/miss logic, refill/writeback control, and uncached AXI paths.

### Current LSU behavior

| Path | Current behavior |
|------|------------------|
| Load hit | completes in `S_IDLE` same cycle from `alu_res` tag lookup |
| Store hit | completes in `S_IDLE` same cycle; updates cache data/dirty/PLRU |
| Load/store miss | blocking FSM through refill / writeback paths |
| Uncached access | single-beat AXI path |
| Refill completion | conservative pulsed `RREADY` |

This LSU work is the main reason CoreMark improved from `2.382` to `2.853 CoreMark/MHz`; the current `2.940 CoreMark/MHz` reference adds the post-merge predictor/recovery work.

### LSU performance status

CoreMark ITER=100:

| Metric | Value |
|--------|-------|
| LSU wait | `6,826` cycles |
| LSU stall share | `0.2%` |
| Load transactions | `209` |
| Store transactions | `600` |

LSU is no longer a first-order performance bottleneck.

## Multiplier And Divider

### Multiplier

- ordinary `MUL` uses a low fast path
- `MULH`, `MULHSU`, `MULHU` still use the multi-cycle multiplier

### Divider

- radix-2 non-restoring divider
- `div_by_zero`, signed overflow, `div_by_one`, and `|divisor| > |dividend|` use fast paths

CoreMark DIV cost is now `2,962` cycles across `114` divides.

## WBU

The WBU commits register/CSR writes and generates architectural PC updates.

Correctly predicted branches/JAL/JALR do not force redundant redirects. Remaining WBU redirect events on CoreMark:

- total `521,545`
- branch `489,459` (93.8%)
- JAL `0`
- JALR `32,086`

## Register File

The scalar register file has 32 architectural registers, with `x0` hardwired to zero. It supports two read ports, one write port, and forwarding from EXU/WBU.

## Caches And Memory

| Component | Configuration |
|-----------|---------------|
| ICache | 4 KB |
| DCache | 4 KB, write-back/write-allocate |
| Cacheable range | `0x30000000` to `0x40000000` |
| Main memory | 64 MB DPI-C model at `0x30000000` |

The Xbar arbitrates RAM and MMIO access.

## Branch Prediction

| Component | Role |
|-----------|------|
| BTB | branch target cache and weak/strong direction input |
| Global BHT | fallback direction predictor, including BTB-miss taken prediction |
| Local history + PHT | local direction predictor |
| Chooser | selects local predictor or BTB/BHT path |
| Loop-exit override | predicts confident loop exits as not-taken |
| RAS | return target prediction |
| Static JAL | JAL target generation in IFU |

Current CoreMark predictor status:

| Metric | Value |
|--------|-------|
| BTB hits | `5,779,930` |
| BTB misses | `914,458` |
| BTB mispredicts | `521,545` |
| Target-bad events | `0` |
| RAS hits / misses | `194,363 / 3` |
| Redirect cost | `3` avg cycles (`514,396` events) |

Redirect-related frontend refill is now the dominant bottleneck.

## COP / Vector Backend

COP/custom instructions are routed to `vsrc/vector/cop` and committed through the shared WBU path.

Current CPU-side COP interface remains stable:

- issue
- response
- kill / flush

Future vector memory access and RVV migration will require CPU-side decode, LSU interface, and CSR expansion, but the current scalar microarchitecture remains independent.

## Performance Counter View

Current CoreMark ITER=100 stall picture:

Current counter semantics print `True stall cycles` separately from `Backend pipe occ`, so normal EXU->WBU occupancy is no longer presented as backend stall.
Current multiply reporting also distinguishes immediate `MUL-low` from multi-cycle `MUL-high`, so multiply behavior no longer needs to be inferred from the old `Other backend` bucket.

Current backend contract semantics use three layers consistently:

- `accept`: payload enters backend ownership
- `done`: backend function completes
- `commit-visible`: result may enter shared WBU / architectural side effects

Killed or stale completions are filtered before `commit-visible`.

| Source | Cycles | % of stalls | Status |
|--------|--------|-------------|--------|
| Frontend/empty | `1,833,135` | 77.5% | multi-issue prep target |
| Control recovery | `521,776` | 22.1% | stable but no longer main tuning target |
| IFU held valid | `9,582` | 0.4% | bounded |
| LSU wait | `6,913` | 0.3% | solved enough for current phase |
| DIV wait | `2,896` | 0.1% | solved enough for current phase |
| Other blocked backend | `0` | 0.0% | cleaned up |

This means HelloCPU is no longer limited by LSU/cache-hit latency. The remaining stall concentration is real, but the next highest-ROI step is not more single-issue branch polish; it is moving into multi-issue preparation while keeping the current recovery path stable.
