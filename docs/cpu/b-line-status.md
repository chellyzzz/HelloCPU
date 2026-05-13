# B-Line Status

Branch: `cpu-mainline-branch`
Baseline: `8837032 docs: consolidate CPU planning into evolution roadmap and add ROI guardrails for redirect work`
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

当前交付标准：

- behavioral RTL patch
- B-line gate 全过
- `CoreMark ITER=100` 数据
- 中间指标下降证明
- 不破坏 future dual-issue / COP memory / vector memory 边界

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

## Assigned Tasks

### B-Task-7: BTB miss / mispredict reduction

Current status: **merged into mainline**

Next work under the same ROI rule:

1. Keep measuring branch miss subtype counts before larger predictor changes.
2. Prefer direction-side improvements before BTB capacity or associativity expansion.
3. Only continue if mispredict / control recovery / frontend bubble keep moving down together.

### B-Task-8: redirect recovery 3 -> 2 cycles

Current status: **implemented and validated on frontend branch**

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
