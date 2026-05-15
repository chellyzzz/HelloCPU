# A-Line Backend Contract Audit

This document records the first audit pass over A-line backend control semantics on top of the `2-cycle` frontend redirect baseline.

Frontend reference for this audit:

- Branch state aligned to `ccd369c`
- `CoreMark/MHz = 3.031`
- `Redirect cost = 2 avg cycles`

The goal of this pass is not to redesign the backend yet. The goal is to identify the current effective contracts around `accept`, `done`, `commit`, and `kill/flush`, and to mark which parts are safe enough for future `2-wide` preparation and which parts still depend on hidden single-issue assumptions.

## Current Effective Contracts

### 1. Accept

Current effective backend accept points are:

- Scalar path: `scalar_issue = idu2exu_valid && !idu2exu_is_cop_insn && !cop_pipeline_active`
- COP path: `cop_issue = i_issue_valid && o_issue_ready`

This means A-line is still structurally single-issue at the backend boundary:

- scalar issue is blocked while any COP pipeline activity exists,
- COP issue is blocked while an older COP instruction is inflight or backend-busy.

### 2. Done

Current effective functional completion points are:

- Scalar EXU done: `scalar_exu2wbu_valid`
- COP done: `cop_exu2wbu_valid`
- COP memory completion becomes architecturally visible only through `cop_mem_done_r && !cop_mem_killed_r`

For scalar EXU, the done definition is operation-local:

- ALU: immediate
- MUL low: immediate
- MUL/DIV: on multiplier/divider done
- LSU: on `lsu_done`

### 3. Commit

Current effective architectural commit point is **not** EXU done. It is the presence of valid data already latched in `exu_wbu_regs`:

- `exu_wbu_valid` is the current architectural commit-valid signal
- `exu2wbu_commit_wen = exu_wbu_valid && exu2wbu_wen`
- perf commit tracing also keys off `exu_wbu_valid`

So the current backend already has an implicit three-layer model:

1. issue accepted,
2. functionally complete,
3. latched for architectural commit.

That is good for future decoupling, but today it is only partially explicit in the codebase.

## Current Kill / Flush Semantics

### Scalar path

Scalar EXU receives `i_flush = exu_mispredict_flush_r`.

Observed behavior:

- branch redirect flush kills the scalar EXU-side valid path,
- `pc_update_en` resets `exu_wbu_regs`,
- frontend flush combines `pc_update_en`, `fence.i`, and mispredict flush.

This is enough for the current single-issue machine, but the scalar path still relies heavily on structural serialization rather than on an explicit stale-completion absorb contract.

### COP path

COP has a stronger explicit kill model than scalar LSU today:

- inflight COP issue state is tracked in `hcpu_idu_cop_regs`
- backend-local response visibility is held in `resp_valid`
- memory-side completion is filtered by `cop_mem_killed_r`

This is the cleanest existing example of request / response / visibility separation in the current backend.

## Main Findings

### Finding 1: `accept`, `done`, and `commit` are already distinct, but only implicitly

This is the most important structural result from the audit.

The backend is no longer a pure “accept means commit” design. It already behaves as:

- accept at issue boundary,
- done at EXU/COP result boundary,
- commit at EXU-WBU registered boundary.

That is good news for future `2-wide` preparation, because the code does not need a conceptual rewrite to support these distinctions. It does need those distinctions to be made explicit and consistently named.

### Finding 2: WBU currently provides no real backpressure, and several contracts quietly depend on that

`hcpu_WBU` keeps `o_pre_ready` effectively constant-high.

Today that is safe enough, but it means multiple flush/commit behaviors are validated only under the hidden assumption that:

- WBU always accepts,
- EXU-WBU never truly stalls,
- clearing commit-visible state can be done with simple one-cycle register actions.

This is acceptable for the current single-issue machine, but unsafe as an unstated assumption for future queue insertion or wider frontend behavior.

### Finding 3: COP has a better explicit stale-completion model than scalar memory

The COP memory path already separates:

- request in flight,
- completion arrival,
- killed completion filtering,
- architectural visibility.

The scalar LSU path is still mostly safe because the machine is structurally serialized, not because the stale-completion contract is equally explicit.

For future decoupling, scalar memory should move closer to the COP semantic model even if the implementation remains single-owner.

### Finding 4: Current safety still depends on single-issue serialization in several places

The design is safe today partly because these situations are prevented structurally:

- no independent scalar issue while COP pipeline activity exists,
- no architectural redirect arriving “through” an unrelated younger backend operation,
- no true WBU backpressure case.

That means the current implementation is stable, but not yet fully expressed as a robust contract that can survive more frontend decoupling.

## Recommended Next Cleanup Targets

### Priority 1: Make the three-layer contract explicit

Document and then standardize these terms:

- **accept**: instruction ownership transferred from frontend-side boundary into backend execution ownership
- **done**: functional result is produced
- **commit-visible**: result is latched and eligible for architectural side effects

This should be reflected first in documentation and signal naming before any wider behavior change.

### Priority 2: Isolate stale-completion filtering as a first-class rule

Current rule should become explicit:

- completion arrival does not imply architectural visibility,
- kill/flush filtering happens before commit-visible side effects.

The COP path already approximates this. Scalar memory should be described using the same rule, even if the current implementation remains simpler.

### Priority 3: Document the hidden “WBU never backpressures” assumption

This assumption is currently relied on in several places and should be written down as a present-day contract, not left implicit.

That way, if future `2-wide` preparation adds queueing or delayed commit behavior, the team will know exactly which old assumptions must be reworked.

## Immediate Conclusion

The backend does **not** need a large rewrite before `2-wide` preparation.

But it does need one cleanup pass that turns today’s implicit single-issue safety assumptions into explicit contracts around:

- accept,
- done,
- commit-visible,
- kill/flush filtering,
- request/response ownership.

That is the right A-line contribution before any wider frontend decoupling becomes real RTL work.

## Cleanup Pass 1

The first RTL cleanup pass on this audit does two small but important things:

1. `exu_wbu_regs` now clears its full latched payload on `i_flush`, not just the valid bit.
2. `hcpu_WBU` now expresses the current contract directly by driving `o_pre_ready` high every cycle instead of depending on self-hold behavior.

These changes do not widen the machine or add queueing. They only make the current single-issue contract more explicit:

- flush kills commit-visible state even if future code later changes ready timing,
- WBU backpressure is still unsupported, but that limitation is now represented more honestly in the RTL.

## Cleanup Pass 2

The second RTL cleanup pass makes scalar completion visibility follow the same rule already used more explicitly in the COP path:

1. scalar `o_post_valid` is now derived from `result_done && !i_flush`
2. scalar `o_mem_resp_valid` is now filtered by `!i_flush`

This does not add a new queue or owner state. It only makes the existing contract explicit:

- scalar completion arrival does not automatically imply architectural visibility,
- flush beats result visibility,
- stale scalar completion is filtered at the EXU visibility boundary instead of being hidden only by downstream structural serialization.

## Validation Snapshot

After cleanup pass 1 and pass 2:

- `make clean && make sim`: PASS
- `make run ALL=sum`: PASS
- `make run ALL=quick-sort`: PASS
- `make run ALL=cop-chain`: PASS
- `make exu_wbu_flush`: PASS
- `make exu_result_visibility`: PASS
- `make cop_backend_flush`: PASS
- `make commit_visible_ctrl`: PASS
- `make backend_contract_checks`: PASS

Observed result:

- scalar control and COP smoke paths remain stable,
- current frontend baseline behavior remains intact,
- no new WBU redirect events were introduced.

## Larger Stable Point

This audit now has a larger stable point than the initial documentation-only pass.

The backend contract is now protected by both RTL cleanup and focused module checks:

- `EXU/WBU` flush clears commit-visible payload even without downstream ready,
- scalar EXU distinguishes `result_done` from `result_visible`,
- COP backend flush clears both pending and already visible response state,
- COP issue ownership now explicitly allows same-cycle `dequeue + issue` replacement in `idu_cop_regs`,
- top-level commit-visible redirect and system-side-effect control is now isolated in `commit_visible_ctrl`,
- frontend boundary hold behavior remains covered by the existing IFU/IDU directed test.

Current focused regression entry points:

- `make exu_wbu_flush`
- `make exu_result_visibility`
- `make cop_backend_flush`
- `make idu_cop_regs`
- `make commit_visible_ctrl`
- `make backend_contract_checks`

That is enough to move the backend from “implicitly safe under single-issue assumptions” to “partially explicit and regression-checked,” which is a reasonable A-line stabilization point before adding new behavior.

## Cleanup Pass 3

The next cleanup pass stays deliberately small and focuses on semantic alignment instead of a structural rewrite:

1. scalar EXU now expresses its local completion boundary as `backend_done` and `backend_commit_visible`
2. COP backend now uses the same internal `accept -> done -> commit-visible` naming pattern
3. scalar LSU stale completion filtering is extended with pending-kill state so delayed memory completion can be absorbed before becoming commit-visible
4. a system-level scalar directed check now drives a test-only flush around a real scalar load response and verifies stale completion is drained but never becomes visible

This still does not add queueing or multi-request overlap. It only makes the backend contract easier to read and reuse:

- `accept`, `done`, and `commit-visible` now mean the same thing on both scalar and COP result paths
- delayed scalar LSU completion is treated like a killed response, not an automatically visible one
- performance reporting now keeps `Other blocked backend` aligned with true residual blocked cycles instead of the broader historical bucket name
- multiply reporting now separates `MUL-low` and `MUL-high`, so `mul-high` no longer hides inside `Other backend` interpretation
- top-level memory-owner routing is now checked at the service boundary, not only at downstream architectural side effects

Current focused regression entry points now additionally include:

- `make scalar_mem_pending_kill`
- `make cop_mem_pending_kill`
- `make cop_mem_store_directed`
- `make cop_mem_store_kill`
- `make backend_contract_checks`
