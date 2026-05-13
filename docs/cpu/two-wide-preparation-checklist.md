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
- single dequeue into the existing decode/register-read path
- no decode queue, no dual dispatch, no dual writeback in v1

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

## Non-Goals

- chasing tiny branch hit-rate improvements as the main workstream
- starting full `2-wide` RTL before queue / flush / commit rules are written down
- using CoreMark as the only decision input for wider-issue readiness
