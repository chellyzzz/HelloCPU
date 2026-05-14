# CPU Memory Service Model

## Goal

This document defines the A-line target shape for memory access inside HelloCPU.

It is **not** an immediate RTL refactor plan. It is a structural guide for how scalar LSU, future COP memory access, and later RVV/vector memory should relate to each other.

The purpose is to stop treating memory as a set of one-off special cases and instead move toward a shared service model.

## Why This Is Needed

Current scalar performance work already pushed LSU wait from `6.98M` cycles to `7K`, so memory is no longer the dominant CoreMark bottleneck.

That changes the role of LSU work:

- short-term: not the biggest performance hotspot anymore
- long-term: still the most important structural integration point for COP memory and future vector memory

If memory remains a blocking scalar-only FSM with special-case top-level wiring, later COP/vector integration will become increasingly expensive and fragile.

## Current Situation

Today the scalar LSU behaves like this:

1. EXU issues a scalar load/store
2. LSU owns the request lifecycle internally
3. LSU blocks the scalar pipeline until completion
4. Result or completion status returns directly into scalar EXU/WBU flow

This works well for the current scalar core, but it means:

- scalar LSU is not yet expressed as a reusable request/response service
- COP memory cannot naturally reuse it without ad-hoc top-level arbitration
- future vector memory would either bypass LSU or distort LSU internals

## A-Line Design Principle

The long-term goal is:

> **memory should look like a service, not like a blocking function call embedded inside scalar EXU semantics**

That means future CPU-side memory structure should separate:

1. request launch
2. request ownership
3. completion response
4. architectural commit side effects
5. flush / kill / exception interaction

## Minimal Service Model

The first useful abstraction is intentionally small.

### Request side

Every memory client should conceptually generate:

- `req_valid`
- `req_kind` (`load` / `store`)
- `req_addr`
- `req_wdata`
- `req_size`
- `req_tag` (optional in first version)

### Response side

The memory service should conceptually generate:

- `resp_valid`
- `resp_rdata`
- `resp_status`
- `resp_tag` (optional in first version)

### Ownership rule

In V1, only **one request may be in flight globally**.

That means the service model can still be single-transaction and blocking, but the interface semantics become clearer and reusable.

This gives a clean migration path:

- V1: single in-flight memory service
- V2: tagged or queued requests
- V3: scalar + COP/vector overlap or arbitration

## Mapping To Current CPU

### Current code attachment points

The current CPU-side attachment points are:

- `vsrc/cpu/exu/lsu.v`: current scalar memory execution and completion core
- `vsrc/cpu/top/hcpu.v`: top-level ownership, stall accounting, and future service boundary shaping
- `vsrc/cpu/wbu/*`: architectural writeback / commit-side observation point
- `vsrc/vector/cop/*`: current COP issue/response path that will later need memory-client hookup
- `docs/interface/vector-coprocessor-interface.md`: current landed COP issue/response/kill contract

This means the first service-model evolution should happen at the CPU top-level boundary, not by immediately rewriting all LSU internals.

### Scalar LSU today

Scalar LSU already contains all the internal logic needed for:

- cacheable hit path
- refill path
- writeback path
- uncached path

What it lacks is a **service-facing boundary**.

So the near-term A-line goal is not “rewrite LSU”, but:

1. identify the scalar request boundary
2. identify the scalar completion boundary
3. make those boundaries explicit in documentation and top-level wiring

Current V1 code-facing boundary signals are now exposed at CPU top level through the scalar EXU instance:

- `scalar_mem_req_valid`
- `scalar_mem_req_store`
- `scalar_mem_req_addr`
- `scalar_mem_req_wdata`
- `scalar_mem_req_size`
- `scalar_mem_resp_valid`
- `scalar_mem_resp_rdata`

Important V1 semantic note:

- `scalar_mem_req_valid` currently means **the scalar EXU entry owns an active memory request**, not a new decoupled one-cycle launch handshake.
- `scalar_mem_resp_valid` means **the active scalar memory request has completed**.
- `scalar_mem_resp_valid` is still a visibility boundary, not a raw completion pulse: killed or stale scalar LSU completion must be absorbed before response visibility.

The current regression protection for that rule is a top-level directed check that:

- holds a scalar load response,
- injects a test-only scalar backend flush,
- observes the stale AXI completion drain,
- requires a later scalar response to remain visible and the program to finish.

This is intentional. The current step is to expose a clean boundary first, without rewriting LSU into a new protocol all at once.

Current A-3 preparation in `vsrc/cpu/top/hcpu.v` now makes one more boundary explicit:

- `scalar_mem_service_*`: scalar-side service-facing request/response view
- `cop_mem_service_*`: COP-side service-facing request/response view under the same V1 single-owner rule
- `mem_service_*`: top-level single-owner memory service view after scalar/COP ownership selection

This is still V1 single-owner behavior. The value is not more overlap yet; it is that later scalar LSU evolution can target a clearer service boundary without first untangling ownership naming.

### COP memory tomorrow

For the first COP memory prototype, the safest rule is:

- COP memory requests use the same global memory service as scalar LSU
- only one client may own the memory service at a time
- a COP memory operation keeps COP busy until `resp_valid`

This means V1 COP memory does **not** need full cache arbitration sophistication.

It only needs:

1. request ownership selection
2. clear completion routing
3. correct kill/flush semantics

### Vector memory later

Future vector memory will need more than V1 COP memory:

- multiple element accesses
- stride / gather / scatter
- queueing
- stronger exception semantics

But all of those should build on the same base idea:

> vector memory is another client of the memory service, not a special rewrite of scalar LSU semantics.

## Phased A-Line Plan

### Phase 1: semantic cleanup

Deliverables:

1. Document scalar LSU request/complete boundaries
2. Distinguish normal backend occupancy from true memory stall in counters
3. Keep current scalar LSU RTL stable

### Phase 2: top-level service boundary

Deliverables:

1. Define a minimal top-level memory client interface
2. Identify where scalar LSU plugs into it
3. Identify where future COP memory would plug into it

No queueing yet. No dual ownership yet.

### Phase 3: first reusable ownership model

Deliverables:

1. One memory service, multiple conceptual clients
2. Single-owner arbitration policy
3. Clear completion routing to scalar or COP/vector side

### Phase 4: structural expansion

Deliverables:

1. store buffer / request queue if needed
2. tagged requests if needed
3. vector memory scaling path

## Non-Goals Right Now

This document explicitly does **not** propose immediate implementation of:

- multi-request in-flight LSU
- non-blocking scalar memory
- vector memory overlap with scalar execution
- advanced cache arbitration
- full RVV memory support

Those belong to later phases.

## Immediate A-Line Task

The next A-line step is:

1. keep `accept / done / commit-visible` semantics aligned across scalar LSU and COP memory-facing backends
2. preserve `true stall` vs `normal backend occupancy` as the only performance-facing counter split
3. prepare for later scalar LSU service-model evolution without breaking the current single-owner V1 rule

## Summary

HelloCPU no longer needs LSU heroics for short-term CoreMark gain.

What it now needs is a cleaner memory model so that:

- scalar performance work remains stable
- COP memory can land without ad-hoc hacks
- future RVV/vector memory has a natural CPU-side attachment point

That is the A-line memory task from this point onward.
