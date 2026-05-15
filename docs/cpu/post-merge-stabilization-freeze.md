# Post-Merge Stabilization Freeze

This document records the current CPU mainline stabilization freeze after landing the reviewed memory-owner work and predictor/recovery work.

## Freeze Scope

- Branch: `cpu-mainline-branch`
- Freeze mode: stabilization-first
- Validation point: post-merge mainline state documented by `4cda60b` and `41b0734`

Landed content included in this freeze:

1. scalar memory-owner V1 boundary and top-level owner skeleton.
2. COP memory owner routing through the frozen V1 owner boundary.
3. tournament/loop predictor recovery and IFU/IDU registered-valid repair.
4. Legacy COP wiring cleanup in `vsrc/cpu/exu/exu.v` to match the merged interface shape.

## Frozen Decisions

- Memory owner V1 remains single-owner.
- Request and completion ownership remain coupled at the owner boundary.
- V1 is not treated as a one-cycle decoupled launch protocol.
- COP memory access remains a named client under the owner mux, not a bypass path.
- Post-merge priority is branch stabilization and measurement, not new feature RTL.

## Validation Snapshot

The following checks were re-run during integration stabilization:

- `make ifu_idu_backpressure`: PASS
- `make run ALL=quick-sort`: PASS
- `make run ALL=cop-chain`: PASS
- `make run ALL=sum`: PASS

`make sim` currently reports `Nothing to be done for 'sim'` in this tree and did not expose a new failure.

## Current Performance Reference

Use the current post-merge CoreMark `ITER=100` result as the formal throughput reference for this freeze:

- `CoreMark/MHz = 2.940`
- `IPC = 0.900`
- `True stall cycles = 3,392,318` (`10.0%`)
- `Frontend/empty = 2,339,440`
- `Control recovery = 1,043,090`
- `BTB mispredicts = 521,545`
- `Redirect cost = 3 avg cycles`

Interpretation at freeze time:

- LSU and DIV are no longer the dominant optimization target.
- The remaining first-order cost is still frontend redirect behavior.
- The next performance question is recovery cost compression, not immediate large predictor expansion.

## Immediate Operating Rule

Before any new RTL feature work on mainline:

1. Preserve this branch state as the reference stabilization point.
2. Keep new work scoped to measurement, documentation, or minimal non-behavioral cleanup unless a new change is explicitly justified.
3. Treat redirect/recovery analysis as the default next investigation path.

## Related Documents

- `docs/cpu/coremark-results.md`
- `docs/cpu/microarchitecture.md`
- `docs/cpu/cpu-evolution-roadmap.md`
- `docs/interface/cpu-memory-service-model.md`
- `docs/interface/vector-coprocessor-interface.md`
