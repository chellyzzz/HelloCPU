# Single-Owner Handoff

## Purpose

This handoff is for moving the current `2-wide preparation` work from split frontend/backend ownership into one owner who can change the frontend contract, the top-level integration, and the future backend-adjacent lane boundary together.

The key reason for the ownership change is simple:

- the next steps are no longer isolated frontend observability work
- they are boundary-definition steps that need one person to control payload shape, flush/kill timing, and the future lane-1 backend contract together

## Current Branch State

- mainline base: `8cc7791`
- current branch: `codex/b-line-predictor-rtl`
- current branch head: `231ffc2`

Current unmerged branch checkpoints after `8cc7791`:

1. `56246ec` stage decode entrance policy before wider issue
2. `d0dd16c` refine slot1 policy for ordered ALU-branch pairing
3. `3b3a209` stage slot packing and slot1 decode observability
4. `a218adc` refine slot1 observability without enabling dual fire
5. `b021a8d` extend slot1 metadata observability surface
6. `18b73b7` stabilize top-level slot1 observability coverage
7. `fa377db` stabilize slot1 shadow transport contract
8. `d9dbe6e` stage slot1 endpoint and queue truth contract
9. `fd60edb` stage frontend pair bundle and policy snapshot
10. `aeb403a` stage pair handoff register surface before dispatch widening
11. `231ffc2` stage dispatch sink surface before lane-1 boundary

## What Exists Today

The current branch has a staged, frontend-owned lane-1 path with these layers:

1. pair-screen truth in `ifu_fetch_queue`
2. decode entrance policy in `decode_pair_policy`
3. packed visible `slot0/slot1` observability in `hcpu`
4. unconditional younger decode surface for truthful lane-1 metadata
5. slot1 shadow transport register
6. slot1 endpoint sink
7. two-lane frontend pair bundle
8. near-`idu_exu` `pair_handoff`
9. dispatch-shaped `pair_dispatch` sink

The intent of that stack is:

- each step moves one boundary closer to a future real lane-1 dispatch path
- each step remains non-executing and non-committing
- each step is covered by top-level capture / hold / flush-clear checks before the next step is added

## Current Contract Shape

### What lane 1 is allowed to do now

- be visible when the oldest two fetch entries form a candidate pair
- preserve truthful decode metadata even when blocked
- preserve truthful RF/CSR-derived operand payload in the handoff and dispatch sink stages
- clear on `frontend_flush`
- hold state across idle cycles

### What lane 1 is not allowed to do now

- allocate a real backend slot
- backpressure the live scalar lane
- enter the real `idu_exu` pipe
- participate in execute, writeback, or commit
- widen issue width in any architectural sense

### Current narrow pairing candidate

- only `older ALU + younger branch` is the intended future narrow candidate
- `older branch + younger ALU` remains structurally visible but is blocked

## Validation That Must Stay Green

Minimum safety gate for this branch:

- `make top_slot1_observability`
- `make top_pc_update_flush`
- `make run ALL=sum`

These are not sufficient for final merge confidence, but they are the minimum branch-shape gate that has been used for the current staged work.

## Known Good Design Decisions

These should be treated as current design constraints unless the owner intentionally rewrites the contract.

1. keep `ins` as the canonical decode truth source
2. keep fetch-side predecode restricted to instruction-local fields
3. keep blocked visible pairs observable instead of hiding them behind `allow_second`
4. keep every new lane-1 boundary flush-cleared before widening behavior
5. preserve truthful operand/CSR payload once the work moves beyond pure decode metadata
6. only move one boundary forward at a time

## Known Bad Paths

These have already been falsified or are intentionally out of scope for the current branch direction.

1. `skip_pre_valid`
   - do not revive this path
   - it tried to improve control timing without fixing payload timing alignment

2. hidden timing-only observability
   - do not rely on same-cycle live decode mirrors for future boundary work
   - registered surfaces plus truth-source closure have worked better

3. premature backend enable
   - do not let lane 1 enter real execute/commit before the accept/kill/flush boundary is defined explicitly

4. broad early pairing matrix
   - do not expand beyond the narrow `older ALU + younger branch` candidate until lane-1 boundary semantics are owned end-to-end

## The Real Next Decision

The next owner should decide one of these two directions before writing much more RTL:

### Option A: real lane-1 `accept/kill` boundary

Do this if the goal is to move from sink-only observability to a true dispatch contract.

Required outcomes:

- define lane-1 accept semantics
- define lane-1 kill / flush semantics
- define whether lane 1 gets its own valid bit or shares a pair-valid contract
- define how lane 1 dies when slot0 is flushed, replayed, or blocked
- keep lane 1 out of real backend resource allocation until that boundary is proven stable

### Option B: trim `pair_dispatch` into the minimum future lane contract

Do this if the goal is to reduce ambiguity before introducing a real valid/kill boundary.

Required outcomes:

- separate dispatch-required payload from frontend-only observability
- decide which fields must survive into the future lane-1 contract
- leave classification and block-reason detail behind if it is not needed beyond the handoff layer

## Recommended Work Order For One Owner

1. freeze the current contract and keep the branch green
2. decide between `accept/kill` boundary vs payload-trim first
3. write the boundary rules in docs before enabling any backend allocation
4. add assertions for the new boundary only after the semantic rule is written
5. only then consider a real lane-1 backend-adjacent register or dispatch stub
6. only after that revisit scoreboard / writeback / resource ownership implications

## File Map

Primary files for the next owner:

- `vsrc/cpu/ifu/ifu_fetch_queue.v`
- `vsrc/cpu/idu/decode_pair_policy.v`
- `vsrc/cpu/top/hcpu.v`
- `vsrc/cpu/Registers/RegisterFile.v`
- `vsrc/cpu/Registers/Csrs.v`
- `sim/top_slot1_observability_tb.cpp`
- `docs/cpu/b-line-status.md`
- `docs/cpu/ifu-idu-handshake-analysis.md`
- `docs/cpu/two-wide-preparation-checklist.md`

## Short Verbal Handoff

The branch is no longer doing local frontend polish; it is building a staged second-lane contract from fetch truth toward a future dispatch boundary without changing architectural issue width. The current stack reaches `pair_dispatch`, which is the first dispatch-shaped but still non-executing sink. The next owner should stop thinking in terms of “more observability” and instead choose whether to define a real lane-1 `accept/kill` boundary next, or first trim the dispatch payload to the minimum future lane contract. The main risk is not raw RTL complexity; it is letting lane 1 creep into backend allocation before valid/kill/flush ownership is explicit.
