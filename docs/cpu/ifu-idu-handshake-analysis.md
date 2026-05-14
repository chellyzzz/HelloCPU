# IFU IDU Handshake Analysis

## Purpose

This document formalizes the current single-issue frontend boundary contract for HelloCPU.

It serves two goals:

1. describe the currently validated behavior precisely enough to prevent regressions
2. provide a clean contract that can later be widened for `2-wide in-order`

This is a boundary document, not a performance note. When this document and RTL disagree, the mismatch should be treated as a bug or an undocumented contract change.

## Scope

This document covers the scalar frontend boundaries:

- `IFU -> IFU/IDU regs`
- `IFU/IDU regs -> IDU`
- `IDU -> IDU/EXU regs`
- `IDU/EXU regs -> EXU`
- redirect / flush interaction across those boundaries

It also covers predictor metadata carriage:

- `predict_taken`
- `predict_target`
- `predict_btb_hit`

## Current Structural Model

Current validated structure:

- IFU owns fetch PC and next-PC selection
- IFU/IDU is a single-entry registered boundary
- IDU is combinational decode
- IDU/EXU is a single-entry registered boundary
- EXU validates branch prediction and may generate immediate redirect

Important non-goal:

- This is not a skid-buffer contract
- This is not a speculative multi-entry queue contract

## Signal Roles

### IFU side

- `ifu_pc_next`: IFU current fetch PC register
- `icache_hit`: current fetch data is usable this cycle
- `ifu_predict_taken`: prediction valid for the fetched instruction
- `ifu_predict_target`: predicted target for the fetched instruction
- `ifu_predict_btb_hit`: whether branch prediction came from a BTB target hit path

### IFU/IDU boundary

- `ifu2idu_valid`: registered valid for the current IFU/IDU entry
- `idu2ifu_ready`: downstream ready seen by IFU and IFU/IDU regs
- `ifu2idu_pc`, `ifu2idu_ins`: registered payload
- `ifu2idu_predict_*`: registered predictor metadata attached to the same payload

### IDU/EXU boundary

- `idu2exu_valid`: registered valid for the current IDU/EXU entry
- `exu2idu_ready`: downstream ready seen by IDU/IDU-EXU regs
- `idu2exu_*`: registered decode payload and predictor metadata

### Redirect / flush side

- `exu_mispredict_flush`: immediate EXU-side control redirect request
- `pc_update_en`: architectural redirect from WBU, currently reserved for `ECALL/MRET`
- `frontend_flush`: top-level frontend boundary flush

## Protocol Specification

### 1. Accepted Payload Rule

Accepted payload is the fundamental contract.

- A frontend payload is considered accepted at `IFU/IDU` when `icache_hit && idu2ifu_ready` is true.
- The accepted payload is the tuple:
- `pc`
- `ins`
- `predict_taken`
- `predict_target`
- `predict_btb_hit`

Invariant:

- the payload and all attached predictor metadata must describe the same instruction
- no field in that tuple may come from an older or newer fetch once the tuple is accepted

### 2. IFU/IDU Valid Rule

`ifu2idu_valid` is a registered-valid boundary, not a pure combinational pass-through from `icache_hit`.

Rules:

- on reset: `ifu2idu_valid = 0`
- on `frontend_flush`: `ifu2idu_valid = 0`
- on accepted fetch (`icache_hit && idu2ifu_ready`): `ifu2idu_valid = 1` and payload registers capture the accepted tuple
- when `idu2ifu_ready = 0`: `ifu2idu_valid` and payload hold their previous value
- when `idu2ifu_ready = 1` and no new accepted fetch occurs: `ifu2idu_valid = 0`

Invariant:

- while `ifu2idu_valid && !idu2ifu_ready`, payload and predictor metadata must remain stable

### 3. IDU/EXU Valid Rule

`idu2exu_valid` is also a registered-valid boundary.

Rules:

- on reset: `idu2exu_valid = 0`
- on `frontend_flush`: `idu2exu_valid = 0`
- when `exu2idu_ready = 1`: `idu2exu_valid` becomes the current `ifu2idu_valid`
- when `exu2idu_ready = 0`: `idu2exu_valid` holds its current value

Invariant:

- the decode result and the attached predictor metadata must always remain aligned to the same instruction while held

### 4. Ready Rule

Current single-entry rule:

- `IDU/EXU` exposes `o_pre_ready = i_post_ready`
- upstream is only allowed to overwrite a boundary register when downstream is ready

This means:

- no overwrite-on-stall behavior is allowed
- no partial payload update is allowed

### 5. Implicit Bubble Rule

An ICache miss is an implicit frontend bubble, not a held-valid condition.

Meaning:

- IFU may have no accepted payload this cycle even though fetch PC is live
- that situation must not be modeled as "valid held with missing data"
- it is simply "no accepted fetch this cycle"

This distinction matters because the failed `skip_pre_valid` path incorrectly treated missing usable payload as a control-only timing problem.

### 6. Flush Priority Rule

Flush has priority over keeping or accepting frontend entries.

Current top-level order of intent:

1. architectural reset
2. frontend flush (`pc_update_en`, `fence.i`, EXU-side redirect class)
3. accepted payload capture
4. normal hold / clear behavior

Effects:

- a flush clears `IFU/IDU` registered valid
- a flush clears `IDU/EXU` registered valid
- a flushed instruction must not survive in valid form at either boundary

### 7. Redirect Ownership Rule

Current validated ownership:

- branch and `JALR` mispredict recovery is owned by EXU redirect
- architectural redirect is owned by WBU `pc_update`

This rule is required to preserve the validated `2-cycle` redirect recovery behavior.

Forbidden pattern:

- the same control-flow error must not be redirected once by EXU and then again by WBU one cycle later

### 8. Predictor Metadata Rule

Predictor metadata is not advisory bookkeeping. It is part of the frontend payload contract.

Required properties:

- `predict_taken`, `predict_target`, and `predict_btb_hit` must travel with the same instruction payload
- on stall, metadata must hold with payload
- on flush, metadata must clear with payload
- EXU must validate prediction against the payload that actually reached EXU, not against a newer fetch

## Current Proven Failure Modes

These are already-known invalid approaches and should be treated as contract violations unless the contract itself is intentionally redesigned.

### Registered-valid hold without aligned payload semantics

Observed symptom:

- `sum` misses commits after redirect
- stale payload / stale metadata survives a control-flow event

Reason:

- valid lifetime was changed without a matching accepted-payload contract

### `skip_pre_valid`

Observed symptom:

- zero real recovery improvement
- stale instruction payload captured around redirect timing

Reason:

- the path tried to optimize control timing without fixing payload timing alignment

## 2-Wide Relevance

This document is the v1 contract that later `2-wide` work must either preserve or explicitly replace.

Before wider issue begins, the next document revision should answer:

- whether queue insertion happens between IFU and IDU, or between IDU and EXU
- whether predictor metadata binds before queue entry allocation or after dequeue
- whether accepted payload remains single-entry semantics or becomes queue-entry semantics
- how flush kills one or more queued frontend entries

## Invariant To RTL Owner Mapping

This section turns the contract into an executable ownership map.

| Invariant | Primary RTL owner | Supporting RTL owner | Notes |
|-----------|-------------------|----------------------|-------|
| IFU owns fetch PC and next-PC selection priority | `vsrc/cpu/ifu/ifu.v` | `vsrc/cpu/top/hcpu.v` | IFU selects between EXU redirect, WBU architectural redirect, predictor, and `pc + 4`. |
| Accepted fetch is `icache_hit && idu2ifu_ready` | `vsrc/cpu/ifu/ifu.v` | `vsrc/cpu/ifu/ifu_idu_regs.v` | `fetch_fire` in IFU and IFU/IDU regs must stay consistent. |
| IFU/IDU valid clears on flush | `vsrc/cpu/ifu/ifu_idu_regs.v` | `vsrc/cpu/top/hcpu.v` | `frontend_flush` meaning must remain aligned with this rule. |
| IFU/IDU payload and predictor metadata capture as one tuple | `vsrc/cpu/ifu/ifu_idu_regs.v` | `vsrc/cpu/ifu/ifu.v` | Payload and `predict_*` fields must be captured on the same accepted fetch. |
| IFU/IDU payload holds stable under backpressure | `vsrc/cpu/ifu/ifu_idu_regs.v` | `vsrc/cpu/top/hcpu.v` | No overwrite while downstream is not ready. |
| IDU decode is combinational over IFU/IDU payload | `vsrc/cpu/idu/idu.v` | `vsrc/cpu/top/hcpu.v` | Any future queue insertion must explicitly redefine this assumption. |
| IDU/EXU valid follows downstream ready semantics | `vsrc/cpu/idu/idu_exu_regs.v` | `vsrc/cpu/top/hcpu.v` | `o_pre_ready = i_post_ready` is the current single-entry contract. |
| IDU/EXU payload and predictor metadata stay aligned | `vsrc/cpu/idu/idu_exu_regs.v` | `vsrc/cpu/exu/exu.v` | EXU correctness depends on this exact alignment. |
| Flush clears IDU/EXU state before stale execution survives | `vsrc/cpu/idu/idu_exu_regs.v` | `vsrc/cpu/top/hcpu.v` | This is one of the contract lines protecting redirect correctness. |
| Branch/JALR mispredict recovery is owned by EXU redirect | `vsrc/cpu/exu/exu.v` | `vsrc/cpu/top/hcpu.v`, `vsrc/cpu/wbu/wbu.v` | WBU must not redundantly re-redirect the same control error. |
| Architectural redirect is owned by WBU `pc_update` | `vsrc/cpu/wbu/wbu.v` | `vsrc/cpu/top/hcpu.v` | Current scope is `ECALL/MRET`. |
| Predictor metadata is validated only against the instruction that reached EXU | `vsrc/cpu/exu/exu.v` | `vsrc/cpu/idu/idu_exu_regs.v` | Any metadata drift is a contract violation. |

## What May Change For 2-Wide

These areas may be redesigned during wider-issue preparation, but only with an explicit contract update.

- `IFU/IDU` may stop being a single-entry boundary and become a queue-entry boundary
- `IDU/EXU` may stop being a single-entry boundary and become an issue-queue or dispatch-queue boundary
- predictor metadata may bind to queue entries rather than directly to one pipeline register hop
- `o_pre_ready = i_post_ready` may stop being sufficient once issue width exceeds one

## What Must Not Change Silently

These properties must stay true unless the document is deliberately revised.

- payload and predictor metadata must remain aligned
- flush must kill stale frontend entries rather than merely hiding control bits
- one control-flow error must have one clear redirect owner
- implicit ICache bubbles must not be reinterpreted as held-valid payloads

## Queue-Aware Extension Draft

This section defines the first recommended extension of the current single-entry contract into a queue-aware contract for `2-wide` preparation.

This is not yet a commitment to specific RTL, but it is the recommended semantic direction.

### Recommended Queue Placement

Current recommendation:

1. add a small fetch queue between IFU and IDU first
2. keep decode combinational in the first extension
3. postpone a true dispatch / issue queue until after fetch-queue semantics are stable

Reasoning:

- a fetch queue gives immediate decoupling value without forcing full issue logic redesign
- it preserves the current IFU predictor ownership model more naturally than inserting the first queue after decode
- it creates a cleaner bridge from single-entry accepted payload semantics to queue-entry accepted payload semantics

### Queue Entry Definition

The minimum fetch-queue entry should be defined as one indivisible tuple:

- `pc`
- `ins`
- `predict_taken`
- `predict_target`
- `predict_btb_hit`

Optional future fields, but not required in the first extension:

- redirect epoch / generation tag
- fetch exception / fault metadata
- lightweight predecode bits

Invariant:

- queue entries are the new unit of accepted payload
- no field in an entry may be updated independently after enqueue

### Enqueue Rule

In the queue-aware extension, enqueue replaces the current IFU/IDU register-capture event.

Recommended rule:

- enqueue occurs when IFU has a usable fetch tuple and the fetch queue has space

That is the queue-era replacement for the current single-entry accepted-fetch rule.

### Dequeue Rule

Recommended rule:

- dequeue occurs when IDU accepts the oldest valid fetch-queue entry
- predictor metadata must leave the queue attached to the same entry payload
- no younger entry may bypass an older entry in the first implementation

This keeps the first queue-aware extension strictly in-order.

### Flush Rule For Queues

Recommended first rule:

- any frontend flush kills all younger and currently visible frontend queue entries
- the first queue-aware implementation should prefer full queue invalidation over partial selective kill

Reasoning:

- full invalidation is simpler to prove correct
- partial queue kill may be revisited later if performance data shows it matters

Invariant:

- after a redirect-generating flush, no stale queue entry may later reach decode or EXU
- the same rule applies to both redirect owners now used in RTL: EXU-side mispredict redirect and WBU architectural `pc_update`
- the first queue-era implementation is validated against both owners with top-level directed tests

### Predictor Metadata Binding Rule

Recommended first rule:

- predictor metadata binds at enqueue time, not dequeue time

Meaning:

- the queue stores the predictor decision that was live when the instruction entered the queue
- decode and EXU must see that stored decision, not a recomputed one from a newer predictor state

This preserves the current "prediction belongs to the accepted payload" contract.

### Backpressure Rule With Queue Present

Recommended first rule:

- IFU backpressure is driven by queue space, not directly by decode readiness
- IDU backpressure is driven by downstream execution readiness, not directly by IFU

This is the semantic shift from single-entry chaining to queue-based decoupling.

### First Extension Non-Goals

The first queue-aware extension should explicitly avoid these features:

- out-of-order dequeue
- selective per-entry branch recovery within the queue
- queue-aware multi-branch speculative epochs
- dual dequeue before single dequeue semantics are stable
- predictor recomputation at dequeue time

### Recommended First RTL Slice

The smallest recommended first slice is:

1. single-dequeue fetch queue
2. queue entry carries predictor metadata unchanged
3. full queue flush on redirect
4. IDU remains effectively single-issue while queue semantics are validated

This gives a safer path to later `2-wide fetch/predecode` than jumping directly to dual-decode or dual-dispatch RTL.

### Current Validation Checkpoint

The current queue-era checkpoint is now backed by both module-level and top-level directed validation.

Validated checks:

1. module-level queue FIFO / backpressure / replace-on-drain / flush dominance
2. top-level EXU redirect flush clears the full fetch queue
3. top-level WBU `pc_update` flush clears the full fetch queue
4. no stale queue entry survives one cycle after either redirect-owner flush

This means the current fetch queue is no longer just a structural insertion point; it is a verified frontend flush boundary candidate for future wider-issue preparation.

### Assertion-Oriented Boundary Closure

The current mainline checkpoint now also carries a minimal default-off assertion set for the first queue-aware boundary contract:

1. `vsrc/cpu/ifu/ifu.v`: if IFU remains blocked after a cache hit, `pc_next` must not drift unless a redirect, `pc_update`, or accepted dequeue occurs.
2. `vsrc/cpu/ifu/ifu_fetch_queue.v`: if dequeue remains stalled, the visible queue head tuple (`pc`, `ins`, `predict_taken`, `predict_target`, `predict_btb_hit`) must remain stable until `flush` or acceptance.
3. `vsrc/cpu/idu/idu_exu_regs.v`: `o_pre_ready` must equal `i_post_ready`, and an accepted decode bundle must remain stable while EXU keeps backpressure asserted.

These checks are intentionally small:

1. they only guard queue-aware boundary semantics already relied on by the current RTL
2. they are gated under `` `ifdef PROTOCOL_ASSERT ``
3. they do not redefine flush ownership or introduce selective-kill behavior

## Remaining Follow-Up

The next useful follow-up items are:

1. add queue occupancy and flush-owner observability only if future wider frontend work needs more debug resolution
2. define the first decode/predecode bundle contract before any real dual-decode RTL starts
3. add broader assertion coverage only when a new boundary semantic is introduced, not preemptively

### First Decode/Predecode Bundle Contract

Current structural fact:

1. `hcpu_IDU` is still pure combinational decode over `ifu2idu_ins`
2. no standalone predecode storage exists in current RTL
3. `idu_exu_regs` still captures the post-register-read execution bundle, not a predecode-only bundle

For future wider frontend work, the first predecode contract should therefore stay deliberately small.

#### Canonical Source Of Truth

The canonical frontend instruction identity remains the fetch tuple:

1. `pc`
2. `ins`
3. `predict_taken`
4. `predict_target`
5. `predict_btb_hit`

If predecode bits are later stored, they are a cached interpretation of that tuple, not an independent truth source.

Invariant:

1. raw `ins` remains authoritative
2. predecode bits must match what `hcpu_IDU` would decode from that same `ins`
3. a mismatch between stored predecode bits and raw `ins` is a contract bug, not a tie-break case

#### Minimum Predecode Bundle

The first queue-safe predecode bundle may include only instruction-local fields:

1. `imm`
2. `rd`
3. `rs1_addr`
4. `rs2_addr`
5. `csr_addr`
6. `exu_opt`
7. `alu_opt`
8. `src_sel1`
9. `src_sel2`
10. `wen`
11. `csr_wen`
12. `mret`
13. `ecall`
14. `load`
15. `store`
16. `brch`
17. `jal`
18. `jalr`
19. `ebreak`
20. `fence_i`
21. `muldiv`
22. `is_cop_insn`

These are allowed because they are functions of `ins` only and do not require register-file or CSR read side effects.

Current landed RTL subset:

1. the fetch queue now stores a hazard-oriented subset of this bundle
2. current stored fields are `rd`, `rs1_addr`, `rs2_addr`, `wen`, `csr_wen`, `load`, `store`, `brch`, `jal`, `jalr`, `fence_i`, `muldiv`, `is_cop_insn`, `ecall`, `mret`, `ebreak`
3. `imm`, `csr_addr`, `exu_opt`, `alu_opt`, and source-select fields are not stored yet

#### Fields Explicitly Not In Predecode

The first predecode contract must not store or virtualize operand-read results:

1. `src1`
2. `src2`
3. `csr_rs2`
4. `mepc`
5. `mtvec`
6. scoreboard state
7. execution-ready / issue-grant state

Reasoning:

1. these values depend on architectural state outside the fetched instruction bits
2. letting them leak into a queue/predecode contract would mix frontend structure work with issue/operand-consistency work
3. that would make the first `2-wide` slice much harder to reason about

#### Bundle Lifetime Rule

If predecode storage is introduced later, the predecode bundle lives and dies with the same fetch identity:

1. it is created from one accepted fetch / queue entry
2. it may not be partially overwritten while that entry remains valid
3. it must stall as one bundle under decode backpressure
4. it must flush as one bundle with its source fetch entry

This is the decode-side equivalent of the already-defined fetch-tuple indivisibility rule.

#### First Recommended Placement

Current recommendation:

1. keep the existing fetch queue as the only real queue before wider decode work
2. allow optional predecode bits to be attached to each fetch entry later
3. keep register reads and `idu_exu_regs` capture after dequeue
4. do not add a decode queue before the first pairing / hazard matrix is written down

This means the first wider frontend slice stays closer to `2-wide fetch/predecode` than to `2-wide decode/dispatch`.

#### First Recommended Invariants

When predecode storage becomes real RTL, the first assertion set should check only these rules:

1. stored predecode bits match raw `ins`
2. dequeue stall keeps the full predecode bundle stable
3. flush removes both fetch identity and attached predecode bits together
4. no younger entry's predecode bits may bypass an older valid entry in the first implementation

Current landed validation hook:

1. `hcpu` simulation now checks the stored fetch-queue predecode sidecar against the current combinational `hcpu_IDU` decode whenever `ifu2idu_valid` is high
2. this keeps the sidecar tied to current decode truth without changing execution behavior

### First Pairing-Screen Skeleton

The next landed step after predecode sidecar storage is still intentionally non-binding.

Current RTL now computes a draft pair screen over the two visible fetch-queue entries:

1. `pair_valid`
2. `pair_candidate_alu_branch`
3. `pair_has_raw`
4. `pair_has_waw`
5. `pair_has_dual_writeback`
6. `pair_has_exclusive_backend`
7. `pair_has_redirect_control`

Current meaning:

1. this is observability only, not issue control
2. it evaluates the oldest visible pair in queue order
3. it keeps the current conservative policy executable without claiming that dual issue exists yet

This is the first RTL bridge between the written pairing matrix and future real pairing logic.

### Decode Entrance Policy Skeleton

The next landed step is to map pair-screen observability into a decode-entrance policy result without enabling dual issue.

Current RTL uses `vsrc/cpu/idu/decode_pair_policy.v` for that mapping.

Inputs:

1. queue pair-screen observability from the oldest visible pair
2. downstream readiness at the current decode/issue entrance
3. current `cop_pipeline_active`
4. current `frontend_flush`

Outputs:

1. `pair_visible`
2. `allow_second`
3. block-reason observability for dependency, resource, control, and pipeline-state causes

Current rule:

1. only a clean `ALU + branch` candidate may reach `allow_second = 1`
2. any `RAW`, `WAW`, dual-writeback pressure, exclusive backend claim, or redirect/control class blocks slot 1
3. even a clean candidate is blocked if downstream is not ready, COP pipeline ownership is active, or frontend flush is active

Current directional refinement:

1. only `older ALU + younger branch` may reach `allow_second = 1`
2. `older branch + younger ALU` is an explicit observable block case
3. this preserves age order and keeps redirect-sensitive behavior on the younger side of the first executable slot-1 candidate

Current slot packing refinement:

1. the fetch queue now exposes the younger queued entry so packing can be driven from real queue state rather than re-decoding outside the queue
2. the top-level skeleton now derives `slot0 = older` and `slot1 = younger` only when the directional slot1 policy selects that younger branch
3. slot 1 remains non-binding and does not feed the live single-issue decode-to-execute path

Current slot1 decode refinement:

1. the packed slot-1 instruction now passes through a second `hcpu_IDU` instance at top level
2. this decode surface is used only for observability and assertion coverage, not for execution or queue dequeue side effects
3. the current assertions require that any visible slot-1 decode still behaves like a non-writing younger branch

Current slot1 observability refinement:

1. slot-1 packing visibility is now allowed to stay high for a clean directional pair even when downstream readiness, COP ownership, or frontend flush block `allow_second`
2. this separates `what the machine can currently observe` from `what the machine may eventually fire`
3. top-level regression coverage now checks both cases: slot 1 visible-and-fireable, and slot 1 visible-but-blocked

Current slot1 metadata refinement:

1. the younger fetch-queue sidecar now exports `rd`, `rs1`, `rs2`, and `wen` for the packed slot-1 candidate
2. the top-level slot-1 decode surface now exports `imm`, `rd`, `rs1`, `rs2`, and `exu_opt` for observability
3. non-synthesis assertions now lock the slot-1 decode metadata to the younger sidecar so this surface stays executable but non-binding

Current top-level coverage refinement:

1. top-level regression now requires `slot1 visible + fireable`, `slot1 visible + blocked`, and `slot1 visible + flushed` to all occur on a stable scalar workload
2. the regression also checks that blocked accounting decomposes cleanly into flush and non-flush cases
3. this turns slot-1 observability from a one-cycle spot check into a repeatable coverage contract over control-flow and backpressure transitions

Current slot1 shadow transport refinement:

1. visible slot-1 metadata is now captured into a shadow register surface that accepts every non-flushed visible candidate without adding backpressure
2. that shadow surface is cleared by `frontend_flush`, holds its payload when no new visible slot arrives, and never feeds the live execute path
3. top-level regression now checks shadow capture, hold, and flush-clear behavior, making this the first non-binding transport checkpoint for lane 1
4. the younger sidecar and shadow lane now preserve the remaining branch-only class bits as explicit negatives, so lane-1 transport cannot silently drift into `load/store`, `jump`, `system`, `muldiv`, or `COP` classes

Current slot1 shadow endpoint refinement:

1. the top level now includes an always-ready, non-executing endpoint stub that accepts every visible lane-1 transport event
2. this endpoint captures the same payload as the shadow transport source, holds it when no new event arrives, and clears on `frontend_flush`
3. top-level regression now checks endpoint capture, hold, and flush-clear behavior, so the non-binding lane-1 path has both a source-side and sink-side executable contract

Current fetch-queue contract refinement:

1. dequeue-stall assertions still lock the visible dequeue payload and predictor metadata
2. full-queue stall assertions now also lock the pair-screen result, younger predict metadata, and younger predecode bundle
3. this makes the fetch queue a more explicit frontend truth source for future lane packing and lane-1 transport work

Current frontend pair-bundle refinement:

1. the top level now captures a non-executing two-lane frontend bundle whenever both queue lanes are visible at once
2. this bundle now keeps slot0 live decode metadata and unconditional younger-lane decode metadata alongside payload, predictor metadata, and the current pair-policy snapshot in one flush-cleared, hold-stable surface
3. the younger decode source is no longer tied only to the directional branch-only slot1 path, so blocked visible pairs such as `older branch + younger ALU` still preserve truthful lane-1 decode state without reaching execute/commit
4. top-level regression now checks bundle capture, hold, flush-clear, and `fireable` vs `blocked` accounting against those decode sources, which closes the frontend-only contract path through policy, packing, transport, and non-executing decode handoff

Current pair-handoff refinement:

1. the top level now captures that frontend pair bundle into a second registered handoff surface that behaves like a sink-side `frontend bundle -> near-idu_exu` checkpoint
2. this handoff is still strictly non-executing: it clears on `frontend_flush`, holds its payload when no new bundle arrives, and never allocates a real execute, commit, or writeback resource
3. slot0 and slot1 operand payload now follow the same pre-`idu_exu` source selection intent as the live scalar lane: `ecall/mret` remap `src1`, CSR-source selection remaps `src2`, and the younger lane uses dedicated non-binding RF/CSR read taps to keep the handoff truthful without driving execution
4. top-level regression now checks handoff capture, hold, flush-clear, and self-consistent `fireable` vs `blocked` accounting, extending the executable frontend contract one stage closer to a future dispatch boundary

This keeps the policy executable while preserving the current single-issue machine behavior.

## Immediate Follow-Up

The next useful follow-up items are:

1. define the first dispatch-ready contract for the current pair handoff without letting lane 1 enter the real backend
2. decide which handoff fields are mandatory for a future `idu_exu`-adjacent sink and which can remain frontend-only observability
3. keep broader assertion growth tied to real new boundary semantics rather than adding speculative checks early
