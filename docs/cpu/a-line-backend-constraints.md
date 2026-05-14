# A-Line Backend Constraints

This note defines the current backend constraints that B-line may assume while `2-wide` preparation stays in `observe / classify / single-issue fallback` mode.

## Stable Point

- current backend semantics already distinguish `accept`, `done`, and `commit-visible`
- `flush/kill` beats `commit-visible`
- top-level memory ownership remains V1 single-owner and single-entry
- focused regressions cover scalar stale completion, COP stale completion, COP store kill, and commit-visible redirect gating

## Hard Constraints

### 1. Single backend accept domain

- scalar backend accept is still structurally single-issue
- COP issue already has its own inflight ownership and blocks unrelated younger COP issue
- no current path accepts two independent backend operations for normal execution in the same cycle

### 2. Single normal commit-visible result

- the machine still has one normal architectural commit-visible path through `EXU/WBU`
- `hcpu_WBU` still behaves as `always accepts`; true WBU backpressure is not part of the supported contract
- any prototype that would require two ordinary architectural writebacks in one cycle is out of scope for the current backend

### 3. Exclusive backend owners stay exclusive

- `LSU` remains a single exclusive backend owner
- `MUL/DIV` remains a single exclusive long-latency owner
- `COP` remains a single exclusive owner for its issue / response lifetime
- redirect / control-side effects remain pairing-hostile by default

### 4. Memory service remains single-entry

- `hcpu_memory_service` still exposes one global memory owner at a time
- request ownership, completion arrival, and response visibility are now separated more explicitly, but they are not queued
- current COP memory slot is still a single-entry skeleton, not a store buffer with overlap
- no tagged requests, no multi-request overlap, no vector-memory arbitration are available in this contract

### 5. Completion arrival does not imply visibility

- scalar and COP paths both follow `completion arrival != commit-visible`
- killed or stale completion must be absorbed before architectural visibility
- frontend redirect and backend completion cause must remain separately owned

## What B-Line May Assume Now

- two visible decode lanes may be observed and classified in the frontend
- pair classification may reject `RAW`, `WAW`, exclusive-owner conflicts, and redirect-hostile combinations before issue
- single-issue fallback is the expected near-term handoff target
- the only plausible first issue-capable candidate remains `simple ALU + branch`, and even that is blocked on RF/writeback and same-cycle accept review

## What B-Line Must Not Assume Yet

- dual dispatch into backend execution
- dual normal writeback
- multi-request memory overlap
- queue-based backend ownership
- reorder or scoreboard semantics beyond the current minimal pairing draft

## Validation References

- `docs/cpu/a-line-backend-contract-audit.md`
- `docs/cpu/a-line-2wide-prep-plan.md`
- `docs/interface/cpu-memory-service-model.md`
- `make backend_contract_checks`
