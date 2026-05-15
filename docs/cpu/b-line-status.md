# B-Line Status

Branch: `codex/b-line-predictor-rtl`
Baseline: `8cc7791 merge mainline before frontend widening follow-up`
Current mode: **2-wide preparation ownership**

## Current Mission

B 线当前主责：

1. IFU / IDU / IFU-IDU / IDU-EXU pipeline 边界
2. BTB / RAS / predictor 策略
3. redirect recovery 路径
4. frontend stall 根因对应的 behavioral RTL 改进

## Strategy Update

Current decision:

- B no longer treats branch hit-rate refinement as the main battlefield.
- The main effort now shifts to **2-wide preparation**: frontend boundary formalization, issue/flush contract cleanup, queue insertion points, and wider-issue validation planning.
- Predictor work remains allowed only as secondary, low-risk, quickly falsifiable optimization.

Tracking document: `docs/cpu/two-wide-preparation-checklist.md`.

当前交付标准：

- behavioral RTL patch
- B-line gate 全过
- `CoreMark ITER=100` 数据
- 中间指标下降证明
- 不破坏 future dual-issue / COP memory / vector memory 边界

## Since Mainline `8cc7791`

Current branch summary from the last mainline sync to the current frontend branch head:

- Base: `8cc7791`
- Current head: `231ffc2`
- Direction: keep the machine single-issue and non-committing for lane 1 while pushing the frontend-only `2-wide` skeleton one boundary at a time toward a future dispatch contract.

Work completed in this span:

1. decode entrance policy and directional slot-1 eligibility
   - landed the executable decode-entrance policy skeleton and narrowed the first future pairing candidate to `older ALU + younger branch`
   - made the blocked cases explicit with stable policy block reasons instead of leaving them as implicit timing behavior

2. packed slot-1 observability and truthful decode metadata
   - exposed the younger queue entry into a non-binding `slot0/slot1` packing surface
   - added a second decode path for the younger lane so visible-but-blocked pairs still preserve truthful lane-1 decode state
   - extended top-level observability to require `visible + fireable`, `visible + blocked`, and `visible + flushed`

3. lane-1 transport and endpoint closure
   - added a non-binding shadow transport register and an always-ready endpoint stub for slot 1
   - closed capture / hold / flush-clear behavior with top-level coverage before moving to dual-lane bundle transport

4. non-executing frontend pair bundle
   - captured the oldest and younger visible queue entries into a two-lane frontend bundle with predictor metadata, decode payload, and pair-policy snapshot
   - kept slot0 sourced from the live scalar decode path and slot1 sourced from an unconditional younger decode path so blocked pairs stay truthful

5. near-`idu_exu` pair handoff surface
   - added a registered `pair_handoff` sink above the frontend bundle, plus dedicated non-binding RF and CSR read taps for truthful lane-1 operand and CSR payload
   - moved slot0/slot1 `src1/src2` payload onto the same pre-`idu_exu` source-selection intent as the live scalar lane

6. dispatch-ready sink surface
   - added an always-ready, non-executing `pair_dispatch` sink above `pair_handoff`
   - trimmed that sink to dispatch-adjacent payload plus minimal pair classification, leaving detailed frontend block reasons at the handoff layer

What stayed intentionally unchanged:

- no decode queue
- no dual dispatch
- no dual execute allocation
- no dual writeback
- no dual commit
- no lane-1 backpressure into the real backend

Validated checkpoints in this span:

- `make top_slot1_observability`: PASS
- `make top_pc_update_flush`: PASS
- `make run ALL=sum`: PASS

## V1 Architecture Decision

Pass-through is the correct V1 frontend architecture.

### Ruled-out approaches

| Approach | Failure symptom | Verdict |
|----------|----------------|---------|
| Registered-valid (IFU/IDU `post_valid` hold) | `sum` misses commits at `0x30000000` and `0x30000b00`; instruction skipped after redirect | Rejected |
| Skid buffer | Not directly tested; inferred incompatible with current single-entry pipeline semantics | Rejected per analysis |

### Current validated baseline

- Current mainline baseline metrics:
  - `CoreMark/MHz = 2.853`
  - `IPC = 0.874`
  - `Frontend/empty = 2,005,006`
  - `Control recovery = 795,702`
  - `BTB mispredicts = 780,786`
- Redirect proof result on baseline:
  - branch `target bad = 0`
  - dominant problem is branch **direction**, not branch target coverage.

### Current winning B-Task-7 candidate

Status: **validated and worth keeping**

Implementation summary:

- Keep tagged BTB target cache for hit cases.
- Add independent BHT direction fallback only when BTB lookup misses.
- Do not change IFU/IDU/IDU-EXU boundary semantics.

Measured result vs baseline:

- `CoreMark/MHz: 2.853 -> 2.861`
- `IPC: 0.874 -> 0.876`
- `Frontend/empty: 2,005,006 -> 1,971,153`
- `Control recovery: 795,702 -> 775,077`
- `BTB mispredicts: 780,786 -> 760,013`

ROI verdict:

- **Pass**. This work satisfied the new ROI rule because it first proved the dominant loss was direction miss, then reduced the relevant intermediate metrics, while preserving future structural boundaries.

### Post-merge CoreMark ITER=100 validation

Validation point: `41b0734 fix: wire legacy cop instance to new exu interface`, after `4cda60b merge: integrate b-line predictor recovery`.

Command:

```bash
make bench_only ITER=100
```

Result:

- Status: **PASS**
- `CoreMark/MHz = 2.940`
- CoreMark-reported `Total cycles = 34,005,979`
- Simulator `Total cycles = 34,010,300`
- `Total instructions = 30,617,983`
- `IPC = 0.900`
- `True stall cycles = 3,392,318` (`10.0%`)
- `Frontend/empty = 2,339,440`
- `IFU held valid = 9,509`
- `Control recovery = 1,043,090`
- `BTB hits = 5,779,930` (`86.3%`)
- `BTB misses = 914,458` (`13.7%`)
- `BTB mispredicts = 521,545` (`7.8%`)
- Mispredict subtype split:
  - `pred NT,taken = 286,597` (`279,551` BTB hit / `7,046` BTB miss)
  - `pred T,NT = 202,862` (`198,625` BTB hit / `4,237` BTB miss)
  - `target bad = 0`
- `RAS hits = 194,363`, `RAS misses = 3`
- `WBU pcupdate = 521,545` (`489,459` branch / `32,086` JALR)
- Redirect cost: `3 avg cycles` (`514,396` events), branch `3 avg`, JALR `3 avg`

Analysis vs the original ROI baseline:

- Throughput improved from `2.853` to `2.940` CoreMark/MHz, about `+3.0%`.
- BTB mispredicts dropped from `780,786` to `521,545`, about `-33.2%`, confirming the predictor-side direction work is carrying the score gain.
- `target bad` remains `0`, so target coverage is still not the limiting branch issue.
- `RAS` behavior is effectively saturated (`194,363 / 194,366` hits), so return prediction is not a current bottleneck.
- `Control recovery` and `Frontend/empty` are higher than the old baseline counters despite fewer mispredicts. Treat these as a follow-up audit item: after the predictor/recovery merge and IFU/IDU valid repair, the intermediate counter semantics may no longer be directly comparable to the pre-merge baseline, and the redirect-cost summary still reports `3 avg cycles` rather than a proven sustained `2-cycle` recovery.

## Assigned Tasks

### B-Task-7: BTB miss / mispredict reduction

Current status: **merged into mainline**

Next work under the same ROI rule:

1. Keep measuring branch miss subtype counts before larger predictor changes.
2. Prefer direction-side improvements before BTB capacity or associativity expansion.
3. Only continue if mispredict / control recovery / frontend bubble keep moving down together.

### B-Task-8: redirect recovery 3 -> 2 cycles

Current status: **implemented and validated on mainline**

Validated branch point: `codex/b-line-predictor-rtl` fast-forwarded to `41b0734`, then patched to remove redundant WBU redirect on branch/JALR mispredicts.

Root cause:

- The same control mispredict was being handled twice: first by EXU immediate redirect, then again one cycle later by WBU `pc_update`.
- That second redirect re-flushed the frontend and kept measured recovery at `3 avg cycles` even though predictor-side event count had already dropped.

Behavioral fix:

- Keep WBU `pc_update` only for architectural redirects (`ECALL/MRET`).
- Let branch/JALR mispredict recovery complete entirely on the EXU redirect path.
- Keep redirect-gap attribution aligned with the real EXU redirect cause.

Validation:

- `make sim`: PASS
- `make ifu_idu_backpressure`: PASS
- `make run ALL=sum`: PASS
- `make run ALL=quick-sort`: PASS
- `make run ALL=cop-chain`: PASS
- `make run ALL=cop-vadd8-chain`: PASS
- `make bench_only ITER=30`: PASS, `CoreMark/MHz = 3.021`, `Redirect cost = 2 avg cycles`
- `make bench_only ITER=100`: PASS, `CoreMark/MHz = 3.031`, simulator `32990370` cycles, `Redirect cost = 2 avg cycles (514395 events)`

Constraint:

- `skip_pre_valid` is a failed path and should not be revived.
- Any new attempt must solve valid/payload timing alignment directly, not by masking control only.

### Current 2-wide preparation checkpoint: fetch queue + flush-owner coverage

Current status: **implemented and validated on frontend branch**

Behavioral slice:

- Insert a `2-entry` fetch queue between IFU and IDU.
- Keep single dequeue / single issue semantics while validating queue-era boundary rules.
- On frontend flush, prefer full queue invalidation over selective kill.

Current validation:

- `make ifu_fetch_queue`: PASS
- `make top_fetch_queue_flush`: PASS
- `make top_pc_update_flush`: PASS
- `make run ALL=pc-update-ecall`: PASS
- `make run ALL=btb-collision`: PASS
- `make run ALL=sum`: PASS
- `make ifu_idu_backpressure EXTRA_VERILATOR_FLAGS="+define+PROTOCOL_ASSERT"`: PASS
- `make ifu_fetch_queue EXTRA_VERILATOR_FLAGS="+define+PROTOCOL_ASSERT"`: PASS
- `make top_fetch_queue_flush EXTRA_VERILATOR_FLAGS="+define+PROTOCOL_ASSERT"`: PASS
- `make top_pc_update_flush EXTRA_VERILATOR_FLAGS="+define+PROTOCOL_ASSERT"`: PASS
- `make run EXTRA_VERILATOR_FLAGS="+define+PROTOCOL_ASSERT"`: PASS, `55 passed, 0 failed`
- `make bench_only ITER=100 EXTRA_VERILATOR_FLAGS="+define+PROTOCOL_ASSERT"`: PASS, `CoreMark/MHz = 3.032`, simulator `32982676` cycles, `IPC = 0.928`
- `make bench_only ITER=100`: PASS, `CoreMark/MHz = 3.032`, simulator `32982676` cycles, `IPC = 0.928`

Redirect-owner coverage proof:

- EXU redirect path: top-level flush test observed `16` redirect flushes, `15` with non-empty fetch queue.
- WBU `pc_update` path: top-level flush test observed `16` architectural flushes, `15` with non-empty fetch queue.
- In both cases, queue state was verified to clear immediately: count to zero, both valid bits cleared, head/tail reset, and no stale entry surviving one cycle later.

Checkpoint verdict:

- This is the current recommended mainline candidate checkpoint for `2-wide` preparation.
- It improves verification confidence rather than throughput: no new performance uplift is claimed beyond the already landed `2-cycle` redirect recovery.
- The queue-aware boundary now also has a default-off `PROTOCOL_ASSERT` closure in mainline-owned boundary files, so future handshake changes can be checked without changing default performance paths.

Assertion closure in this checkpoint:

- `vsrc/cpu/ifu/ifu.v`: blocked fetch keeps `pc_next` stable until redirect, `pc_update`, or a real dequeue event.
- `vsrc/cpu/ifu/ifu_fetch_queue.v`: dequeue stall keeps `pc/ins/predict_*` stable until `ready` or `flush`.
- `vsrc/cpu/idu/idu_exu_regs.v`: `o_pre_ready` remains pure pass-through from `i_post_ready`, and stalled downstream keeps the full payload stable.

Next B-line contract target:

- Define the first decode/predecode bundle before any real dual-decode RTL starts.
- Keep `ins` as the canonical truth source.
- Limit predecode fields to instruction-local decode outputs only.
- Keep operand reads, CSR data selection, and issue/arbitration state out of the first predecode contract.

Current landed RTL slice:

- `vsrc/cpu/ifu/ifu_fetch_queue.v` now stores a minimal hazard-oriented predecode sidecar with each fetch entry.
- Current stored fields are instruction-local only: `rd`, `rs1_addr`, `rs2_addr`, `wen`, `csr_wen`, `load`, `store`, `brch`, `jal`, `jalr`, `fence_i`, `muldiv`, `is_cop_insn`, `ecall`, `mret`, `ebreak`.
- The sidecar does not change execution semantics yet; dequeue still feeds the existing single-issue decode / register-read path.
- Queue-level directed validation and top-level smoke regressions now cover this structure.

Current pairing-screen RTL slice:

- The fetch queue now also computes a non-binding pair screen over the two visible queue entries.
- Current observability is draft-only: `pair_valid`, `pair_candidate_alu_branch`, `pair_has_raw`, `pair_has_waw`, `pair_has_dual_writeback`, `pair_has_exclusive_backend`, `pair_has_redirect_control`.
- These signals do not affect issue behavior yet; they are only the first executable skeleton for future pairing policy.

Current decode-policy RTL slice:

- `vsrc/cpu/idu/decode_pair_policy.v` now turns queue pair-screen observability plus decode/backend entrance state into a non-binding slot-1 policy result.
- Current outputs are `pair_visible`, `allow_second`, and explicit block reasons for `raw`, `waw`, `dual_writeback`, `exclusive_backend`, `redirect_control`, `downstream_busy`, `cop_pipeline`, and `frontend_flush`.
- This still does not change issue width; it only makes the decode entrance policy executable and testable.

Current directional slot1 step:

- The executable policy now treats only `older ALU + younger branch` as slot-1 eligible.
- `older branch + younger ALU` remains observable but is blocked by policy.
- If slot 1 were ever enabled by later RTL, the current skeleton would select the younger entry as slot 1 and classify it as the branch side.

Current slot packing skeleton:

- The fetch queue now exposes the younger queued entry as a non-binding observable input to future slot packing.
- `hcpu` now derives an internal `slot0 = older`, `slot1 = younger branch` packing surface when the directional slot1 policy allows it.
- This still does not change issue width or let slot 1 reach `idu_exu_regs`.

Current slot1 decode surface:

- `hcpu` now runs a non-binding second `hcpu_IDU` decode over the packed slot-1 instruction.
- The slot-1 decode surface is assertion-checked to remain a non-writing branch decode.
- The live single-issue path still uses only the original `idu1 -> idu_exu_regs` flow.

Current slot1 observability refinement:

- `slot1` packing visibility is now decoupled from `allow_second` so the surface stays observable even when downstream backpressure blocks any real second-lane fire.
- `allow_second` remains the stricter execution gate for any future real dual-lane enable.
- A new top-level regression now watches the live packed slot-1 surface on `if-else.bin` and confirms that it remains branch-only and non-binding.

Current slot1 decode metadata surface:

- The younger fetch-queue sidecar now exposes `rd`, `rs1`, `rs2`, and `wen` for the packed slot-1 candidate.
- The non-binding slot-1 decode surface now exposes `imm`, `rd`, `rs1`, `rs2`, and `exu_opt` in addition to `pc`, `ins`, `brch`, and `wen`.
- Top-level assertions and regression coverage now check that slot-1 decode metadata matches the younger queue sidecar while remaining non-binding.

Current top-level coverage stable point:

- `top_slot1_observability` now requires three live categories on `if-else.bin`: `visible + fireable`, `visible + blocked`, and `visible + flushed`.
- The coverage test also checks that blocked accounting is self-consistent and that flush-time visibility still never upgrades into a real second-lane fire.
- This is the first top-level regression point that exercises slot-1 observability as a state machine surface rather than only as a structural decode snapshot.

Current slot1 shadow transport surface:

- `hcpu` now captures visible slot-1 metadata into a non-binding shadow register surface that is cleared by `frontend_flush` and never participates in execute or commit.
- The shadow surface now carries `pc`, `ins`, `imm`, `rd`, `rs1`, `rs2`, `exu_opt`, `alu_opt`, `src_sel1`, `src_sel2`, `wen`, `brch`, and younger branch prediction metadata.
- The younger sidecar and the shadow lane now also keep the remaining branch-only class bits explicit: `csr_wen`, `load`, `store`, `jal`, `jalr`, `fence_i`, `muldiv`, `is_cop_insn`, `ecall`, `mret`, `ebreak`, and zero `csr_addr`.
- Top-level coverage now requires shadow capture, shadow hold, and shadow flush-clear events in addition to the visible/fireable/blocked/flushed observability states.

Current slot1 shadow endpoint surface:

- `hcpu` now also exposes an always-ready, non-executing slot-1 endpoint stub that accepts every visible shadow-transport event without adding backpressure.
- The endpoint captures the same branch-only payload as the shadow lane, holds it across idle cycles, and clears on `frontend_flush`.
- Top-level coverage now requires endpoint capture, endpoint hold, and endpoint flush-clear behavior, so lane 1 has both a source-side shadow surface and a sink-side endpoint surface.

Current fetch-queue contract refinement:

- Under `PROTOCOL_ASSERT`, a full stalled fetch queue must now keep the full pair-screen result, younger predict metadata, and younger predecode bundle stable until dequeue or flush.
- The directed fetch-queue regression now checks that a blocked overwrite attempt leaves the younger truth source unchanged.

Current frontend pair-bundle surface:

- `hcpu` now captures a non-executing two-lane frontend bundle whenever the oldest and younger queue entries are both visible.
- This bundle now carries slot0/slot1 `pc`, `ins`, predictor metadata, decoded control payload (`imm`, `csr_addr`, `exu_opt`, `alu_opt`, `src_sel1`, `src_sel2`, class bits), and the current pair-policy snapshot.
- The bundle is cleared by `frontend_flush`, holds across idle cycles, and remains entirely outside execute/commit.
- Slot0 decode metadata is sourced from the live scalar IDU path, while slot1 bundle metadata is sourced from a new unconditional younger-entry decode surface so even blocked visible pairs retain truthful lane-1 decode state.

Current frontend policy-snapshot refinement:

- The pair bundle now preserves `candidate_alu_branch`, `allow_second`, directional order, and all current block reasons in one stable frontend-owned surface.
- Top-level coverage now checks bundle capture, hold, flush-clear, and self-consistent `fireable` vs `blocked` accounting.

Current pair-handoff surface:

- `hcpu` now captures the frontend pair bundle into a second non-executing register surface that behaves like a sink-side `frontend bundle -> near-idu_exu handoff` checkpoint.
- This handoff keeps the two-lane `pc`, `ins`, predictor metadata, decode payload, and policy snapshot stable across idle cycles, clears on `frontend_flush`, and still never reaches execute or commit.
- Slot0 and slot1 `src1/src2` payload are now sourced from truthful pre-`idu_exu` selection rules rather than a fragile same-cycle decode mirror: `ecall/mret` redirect sources are folded into `src1`, CSR source override is folded into `src2`, and lane 1 uses dedicated non-binding RF/CSR read taps.
- Top-level validation now requires handoff capture, hold, flush-clear, and self-consistent `fireable` vs `blocked` accounting, so the frontend-only path now closes through policy, packing, decode, bundle, and a registered handoff sink surface.
- Current validation for this checkpoint: `make top_slot1_observability`, `make top_pc_update_flush`, and `make run ALL=sum` all PASS.

Current dispatch-ready sink surface:

- `hcpu` now captures `pair_handoff` into an always-ready, still non-executing `pair_dispatch` sink surface that is narrower than the handoff contract: it keeps dispatch-adjacent per-lane payload plus minimal pair classification, but leaves detailed frontend block reasons behind.
- This sink still never allocates a real backend slot, adds no backpressure, clears on `frontend_flush`, and holds its payload across idle cycles, making it the first explicit dispatch-shaped contract above the current handoff stage.
- The preserved classification is limited to `candidate_alu_branch`, `allow_second`, and directional order, which is enough to keep the future `older ALU + younger branch` path structurally visible without claiming any real dual-dispatch semantics.
- Top-level coverage now requires dispatch capture, hold, flush-clear, and self-consistent `fireable` vs `blocked` accounting against `pair_handoff` truth.
- Current validation for this checkpoint remains: `make top_slot1_observability`, `make top_pc_update_flush`, and `make run ALL=sum` all PASS.

Current pairing/hazard draft direction:

- Near-term real slice stays `2-wide fetch/predecode` with single issue preserved.
- First issue-capable prototype rejects `RAW`, `WAW`, and shared exclusive-backend pairs by default.
- Until writeback bandwidth changes, treat two normal writers in one cycle as out of scope.
- The only future pairing candidate worth studying first is `simple ALU + branch`.
- The next narrow structural target after the current dispatch-ready sink checkpoint is to decide whether lane 1 needs a real `accept/kill` dispatch boundary or whether the next safe step should stay at sink-only observability while trimming the payload further toward a future `idu_exu` lane contract.

### B-Task-1: IFU/IDU pass-through protocol specification document

**Priority**: High
**Risk**: None (documentation only)
**Owner**: B

Formalize V1 correct architecture semantics in `docs/cpu/ifu-idu-handshake-analysis.md`:

- Signal meanings for `ifu2idu_valid`, `idu2ifu_ready`, `idu2exu_valid`, `exu2idu_ready` and all payload fields.
- Valid/ready lifecycle: when `valid` can deassert, when `ready` can deassert, what holds payload stable.
- Redirect/refetch semantics: what happens to in-flight `valid`/payload on `pc_update_en`, `exu_mispredict_flush_r`, COP flush.
- Implicit pre-valid bubbles: IFU can present `valid=0` on ICache miss; this is not a registered-hold semantic.

Deliverable: updated `docs/cpu/ifu-idu-handshake-analysis.md` with a formal "Protocol Specification" section.

### B-Task-2: IFU/IDU/EXU protocol assertion coverage

**Priority**: Medium
**Risk**: Low (`ifdef`-protected, no behavior change)
**Owner**: B

Add `ifdef`-protected SystemVerilog assertions in B-owned files:

- `vsrc/cpu/ifu/ifu.v`: assert `ifu2idu_valid` does not deassert while `!idu2ifu_ready` (pass-through hold).
- `vsrc/cpu/idu/idu.v`: assert `idu2exu_valid` does not deassert while `!exu2idu_ready` (pass-through hold).
- `vsrc/cpu/idu/idu_exu_regs.v`: assert `o_pre_ready` follows `i_post_ready` (pass-through).
- `vsrc/cpu/ifu/ifu_idu_regs.v`: assert `o_post_valid` tracks `icache_hit` (pass-through from ICache).
- Redirect assertion: after `pc_update_en` or `exu_mispredict_flush_r`, verify `idu2exu_valid` drops within N cycles.

These assertions protect against future regressions when A or B modify handshake semantics.

Deliverable: assertion patches in `cpu-frontend-interface-lab`, gated on `` `ifdef PROTOCOL_ASSERT ``.

### B-Task-3: same-cycle LSU result interface design memo

**Priority**: High (blocking A-line maximum-yield optimization)
**Risk**: None (design memo, no RTL)
**Owner**: B (per A/B behavior-RTL rule: 5-line design note + failure plan before A reviews)

Document what IFU/IDU must provide for A to safely implement same-cycle LSU hit:

1. **EXU first-cycle response**: When LSU detects cache hit in S_IDLE (same cycle as instruction enters EXU), how should `exu2idu_ready` / `scalar_exu2idu_ready` behave? Current: `o_pre_ready = lsu_done` only after S_CHECK. Proposal: `o_pre_ready` combinational from `fast_load_hit_done` (already exists) but IDU/EXU valid lifetime must tolerate this.

2. **IDU `valid` release condition**: Currently `idu2exu_valid` held while `!exu2idu_ready` and drops when `exu2idu_ready && !idu_insn_valid`. If EXU reports `ready=1` in the same cycle the instruction is presented, does the IDU payload need to be latched or can it be consumed in zero cycles?

3. **Payload stability**: If `idu2exu_valid` can be consumed in the same cycle it is presented, the IDU->EXU pipeline register must accept the payload on `i_pre_valid && i_post_ready` (which it already does). But the *next* instruction's IDU decode must be available in the very next cycle.

4. **Failure mode**: A's previous same-cycle LSU hit attempts failed because `sum` skipped commits after redirect and `load-store`/`quick-sort` hung or produced wrong results. The design memo must explain exactly which handshake invariant was violated.

5. **Integration plan**: A will modify `lsu.v` (A-owned) and `exu.v`/`hcpu.v` (shared); B must confirm that IFU/IDU pass-through semantics remain satisfied and provide assertion activation.

Deliverable: section in this document under "Design Memos", referenced from `docs/cpu/ifu-idu-handshake-analysis.md`.

## Design Memos

*(B-Task-3 deliverable will be added here once written.)*

## B-Line Gate

Current B-line regression gate:

1. `sum.bin`
2. `quick-sort.bin`
3. `cop-chain.bin`
4. `cop-vadd8`
5. `cop-vadd8-chain`
6. `cop-vadd8-after-add`
7. `cop-vxor8`
8. `cop-vand8`
9. `cop-mixed-lanes`

Any patch touching redirect/refetch/flush must also record either commit-trace evidence or the first failing committed PC.

## Coordination

- B is now in active **2-wide preparation mode**, not pure frontend scoring mode.
- B keeps ownership of frontend behavioral RTL, but the main target has shifted from local predictor tuning to wider-issue readiness.
- B owns `vsrc/cpu/ifu/*`, `vsrc/cpu/idu/*`, `vsrc/vector/cop/*`, and related frontend analysis/status docs.
