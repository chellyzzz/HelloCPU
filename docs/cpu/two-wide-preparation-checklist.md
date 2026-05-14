# 2-Wide Preparation Checklist

## Goal

This checklist defines the minimum preparation work before HelloCPU starts a real `2-wide in-order` RTL implementation.

Current intent:

- keep small, low-risk single-issue improvements as secondary work
- move the main effort to structure cleanup and wider-issue readiness
- avoid starting `2-wide` RTL on top of ambiguous valid/ready/flush semantics

## Exit Criteria

The preparation phase is complete only when all of the following are true:

1. frontend boundaries have a written, reviewed contract
2. backend request / complete / flush semantics are unambiguous
3. a minimum queue / scoreboard plan exists
4. benchmark coverage is broader than CoreMark alone
5. the first `2-wide` implementation slice is small and explicitly scoped

## Checklist

### 1. Frontend Boundary Contract

- Define `IFU/IDU` accepted-payload semantics
- Define `IDU/EXU` accepted-payload semantics
- Define when `valid` may drop and when payload must hold
- Define redirect / flush / kill priority ordering
- Define whether future queue insertion happens before or after predictor metadata binding
- Record all of the above in a frontend boundary document

Current working document:

- `docs/cpu/ifu-idu-handshake-analysis.md`

Done when:

- A/B can answer boundary questions without reading RTL line by line
- no stage relies on implicit timing assumptions that are not written down

### 2. Redirect And Flush Semantics

- Separate architectural redirect from branch-mispredict redirect
- Define one owner for each redirect class
- Define how redirect interacts with COP / future vector side effects
- Define flush propagation timing across `IFU/IDU/IDU-EXU/EXU/WBU`
- Preserve the validated `2-cycle` recovery behavior while documenting the rule that enables it

Done when:

- a mispredict trace can be explained as a single clear control-flow recovery path

### 3. Backend Completion Semantics

- Define `accept`, `inflight`, `result valid`, and `architectural commit`
- Distinguish normal EXU->WBU pipe occupancy from true backend blocking
- Unify LSU / MUL / DIV / COP completion language
- Define how future multi-result or dual-writeback cases would map onto current semantics

Done when:

- performance counters and RTL use the same meaning for "stall" and "occupied"

### 4. Queue Insertion Points

- Decide whether a fetch queue is required before `2-wide`
- Decide whether a decode queue is required before `2-wide`
- Define queue depth targets for the first prototype
- Define queue flush semantics
- Define predictor metadata storage and kill behavior inside queues

Current recommendation:

- fetch queue: yes, already the preferred first decoupling point
- decode queue: no, not before the first pairing / hazard matrix exists
- predecode storage: allowed only for instruction-local fields and must remain attached to the same fetch identity

Done when:

- queue placement is explicit and no longer a hand-wavy "maybe later" idea

### 5. Scoreboard And Hazard Rules

- List hazards that a minimum `2-wide` design must handle
- Define RAW / WAW / structural hazard policy for first implementation
- Define whether branch may pair with ALU / LSU / MUL in v1
- Define whether same-cycle dual issue may target one or two writeback slots
- Define the smallest acceptable scoreboard scope

Current draft:

- Stage 0 remains `2-wide fetch/predecode` with single issue preserved, so no execution-side pairing is required yet.
- A-line backend constraints for the first issue-capable handoff are pinned in `docs/cpu/a-line-backend-constraints.md`; frontend work should treat that note as the backend truth source until those constraints change.
- The first issue-capable prototype must reject any same-cycle pair with slot-to-slot `RAW` dependence.
- The first issue-capable prototype must reject any same-cycle pair with `WAW` to the same architectural `rd`.
- The first issue-capable prototype must reject any pair that needs the same exclusive backend owner in the same cycle: `LSU`, `MUL/DIV`, `COP`, or redirect/control owner.
- Until writeback bandwidth is widened explicitly, default policy is to reject pairs where both instructions would require normal architectural writeback.
- The only pairing candidate worth evaluating first is `simple ALU + branch`, and even that stays draft-only until backend/control-path review is complete.

Smallest acceptable scoreboard scope:

- slot-local `RAW/WAW` check between the two visible instructions
- one busy view for long-latency exclusive backends
- one rule that control/redirect-generating instructions are pairing-hostile by default

Done when:

- the first `2-wide` pairing matrix is written down and reviewable

### 6. Register File / Bypass / Writeback Capacity

- Count required read ports for minimum `2-wide`
- Count required write ports or equivalent staging
- Define bypass paths needed on day one versus later
- Define whether dual writeback is mandatory in v1 or can be staged

Done when:

- the first implementation is blocked by zero unknowns in RF / bypass bandwidth planning

### 7. Benchmark Matrix

- Keep `CoreMark ITER=100` as a baseline benchmark
- Add at least one branch-heavy benchmark
- Add at least one load/store-heavy benchmark
- Add at least one ALU-heavy benchmark
- Add at least one mul/div-heavy benchmark
- Add at least one COP/vector-mixed benchmark

Done when:

- we can judge whether a future `2-wide` design helps more than one workload style

### 8. First 2-Wide Slice Definition

- Define the minimum first RTL slice
- Prefer a narrow scope such as:
- `2-wide fetch/predecode` only, or
- `2-wide decode + single-issue fallback`, or
- limited pairing such as `ALU + branch`
- Define what is explicitly out of scope for v1

Current preferred first slice:

- `2-wide fetch/predecode` only
- next handoff-ready intermediate slice may add `dual-lane observe/classify + single-issue fallback`, but still must not dual-dispatch into backend execution
- single dequeue into the existing decode/register-read path
- no decode queue, no dual dispatch, no dual writeback in v1
- an intermediate safe step is allowed: store instruction-local predecode sidecar bits in fetch-queue entries without changing issue width
- another intermediate safe step is allowed: compute pair-screen observability over the oldest two fetch entries without changing issue width
- another intermediate safe step is allowed: compute decode-entrance slot-1 policy observability without changing issue width
- another intermediate safe step is allowed: refine that policy so only `older ALU + younger branch` is directional slot-1 eligible
- another intermediate safe step is allowed: expose the younger queued entry and derive a non-binding `slot0/slot1` packing skeleton without changing issue width
- another intermediate safe step is allowed: decode that packed slot-1 surface for observability while still keeping only one live instruction on the execute path
- another intermediate safe step is allowed: keep slot-1 observability visible under non-fireable conditions, as long as `allow_second` remains the stricter execution gate
- another intermediate safe step is allowed: expand slot-1 observability to richer decode metadata as long as it remains checked against queue sidecar state and does not feed execution
- another intermediate safe step is allowed: require top-level coverage for `visible + fireable`, `visible + blocked`, and `visible + flushed` slot-1 states before attempting any real second-lane transport
- another intermediate safe step is allowed: capture visible slot-1 metadata into a shadow transport register surface, as long as it clears on flush, never adds backpressure, and never reaches execute/commit

Done when:

- the first implementation milestone is small enough to land without a full-core rewrite

## Recommended Order

1. Finish frontend boundary contract
2. Finish redirect / flush ownership rules
3. Finish backend completion vocabulary
4. Decide queue insertion points
5. Write first pairing / scoreboard matrix
6. Expand benchmark matrix
7. Define the first narrow `2-wide` RTL slice

## First Pairing Matrix Draft

This is a conservative draft for review, not a claim that the current backend can already support these pairs.

| Pair class | Draft status | Reason |
|-----------|--------------|--------|
| `ALU + ALU` | Reject for v1 | current single writeback path makes two normal writers unsafe by default |
| `ALU + branch` | Candidate | one potential writer plus one control op is the least disruptive future pairing to study |
| `ALU + load/store` | Reject for v1 | LSU is a single exclusive backend owner today |
| `ALU + MUL/DIV` | Reject for v1 | mul/div is exclusive and long-latency |
| `ALU + COP` | Reject for v1 | COP path already has dedicated inflight / commit serialization |
| `branch + branch` | Reject for v1 | redirect ownership should remain single and unambiguous |
| `branch + load/store` | Reject for v1 | mixes control recovery with LSU ownership too early |
| any pair with `JAL/JALR` | Reject for v1 | link writeback plus redirect semantics should stay single-issue initially |
| any pair with `fence.i` / `ECALL` / `MRET` / `EBREAK` | Reject for v1 | architectural control side effects are intentionally pairing-hostile |

The practical implication is simple:

- before backend/writeback expansion, the project should treat `2-wide fetch/predecode` as the real near-term slice
- a real issue-pairing attempt should start from one narrow candidate, not a broad dual-issue matrix

## Non-Goals

- chasing tiny branch hit-rate improvements as the main workstream
- starting full `2-wide` RTL before queue / flush / commit rules are written down
- using CoreMark as the only decision input for wider-issue readiness
