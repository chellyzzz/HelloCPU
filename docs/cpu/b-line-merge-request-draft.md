# B-Line Merge Request Draft

## Title

`stage frontend 2-wide preparation from decode policy to dispatch-ready sink`

## Summary

- advances the frontend-only `2-wide` preparation path from the last mainline base `8cc7791` to the current branch head `231ffc2`
- keeps execution single-issue while progressively extending the non-binding lane-1 path through slot packing, decode observability, shadow transport, frontend pair bundle, pair handoff, and a dispatch-ready sink
- preserves truthful lane-1 payload by sourcing younger-lane decode, register, and CSR data without letting lane 1 allocate real backend resources

## Main Changes

- adds executable decode-entrance policy and directional `older ALU + younger branch` eligibility
- adds packed `slot0/slot1` observability with truthful younger decode metadata
- adds slot-1 shadow transport and endpoint sink coverage
- adds non-executing frontend pair bundle and policy snapshot surfaces
- adds near-`idu_exu` `pair_handoff` with dedicated non-binding RF/CSR taps for lane 1
- adds always-ready non-executing `pair_dispatch` sink with dispatch-adjacent payload and minimal pair classification

## Validation

- `make top_slot1_observability`
- `make top_pc_update_flush`
- `make run ALL=sum`

## Scope Notes

- no decode queue
- no dual dispatch
- no dual execute allocation
- no dual writeback
- no dual commit

## Follow-Up

- decide whether the next safe step is a real lane-1 `accept/kill` dispatch boundary or a further payload trim on `pair_dispatch`
- define the minimum future `idu_exu`-adjacent lane contract before any backend resource allocation is enabled
