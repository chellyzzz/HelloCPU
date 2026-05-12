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

Current validated throughput: `2.853 CoreMark/MHz`, `IPC=0.874`, `10.4%` stall rate.

## IFU

The IFU owns the fetch PC and selects the next PC from these sources, in priority order:

| Source | Purpose |
|--------|---------|
| EXU redirect | Mispredict recovery |
| WBU PC update | Architectural redirect / unresolved control flow |
| Predictor target | BTB, RAS, or static JAL prediction |
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

The IFU/IDU/IDU-EXU path uses pass-through ready chaining. Registered-valid and skid-buffer variants were tested and rejected because they break control-flow alignment.

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

This LSU work is the main reason CoreMark improved from `2.382` to `2.853 CoreMark/MHz`.

### LSU performance status

CoreMark ITER=100:

| Metric | Value |
|--------|-------|
| LSU wait | `7,107` cycles |
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

- total `795,702`
- branch `754,234` (94.8%)
- JAL `4,966`
- JALR `36,502`

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
| BTB | branch direction and target |
| RAS | return target prediction |
| Static JAL | JAL target generation in IFU |

Current CoreMark predictor status:

| Metric | Value |
|--------|-------|
| BTB hits | `5,939,881` |
| BTB misses | `1,025,583` |
| BTB mispredicts | `780,786` |
| Redirect cost | `3` avg cycles (`772,653` events) |

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

| Source | Cycles | % of stalls | Owner |
|--------|--------|-------------|-------|
| Frontend/empty | `2,005,006` | 55.0% | B |
| Other backend | `837,926` | 23.0% | A (currently mostly normal EXU→WBU pipe occupancy) |
| Control recovery | `795,702` | 21.8% | B |
| LSU wait | `7,107` | 0.2% | A done |
| DIV wait | `2,962` | 0.1% | A done |

This means HelloCPU is no longer limited by LSU/cache-hit latency. The current bottleneck is frontend redirect recovery. The `Other backend` bucket is now understood to be dominated by normal EXU→WBU pipe occupancy for ordinary scalar instructions, not a large true backend stall source.
