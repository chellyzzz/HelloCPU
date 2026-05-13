# B-Line Status

Branch: `codex/b-line-predictor-rtl`
Baseline: WSL-native worktree from `/home/chelly/HelloCPU` at `323cd54 merge: integrate cop memory owner boundary`
Current mode: **Active frontend performance ownership**

## Current Mission

B 线当前主责：

1. IFU / IDU / IFU-IDU / IDU-EXU pipeline 边界
2. BTB / RAS / predictor 策略
3. redirect recovery 路径
4. frontend stall 根因对应的 behavioral RTL 改进

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

### Current Tournament-Loop RTL Prototype

Status: **ported to WSL-native worktree, initial validation passed**

Implementation summary:

- Implemented inside `vsrc/cpu/ifu/btb.v`; no IFU/IDU/IDU-EXU semantic change intended.
- Keeps the tagged BTB target path and current BTB/BHT direction predictor as one tournament arm.
- Adds local-history direction prediction (`1024` local histories, `8`-bit history, shared `256`-entry pattern table).
- Adds a `1024`-entry chooser between current direction prediction and local-history direction prediction.
- Adds a tagged loop table that only overrides likely loop exits to not-taken after a stable trip count.
- Adds branch trace support and `tools/predictor_sim/` for offline policy screening.

Previously measured result before WSL worktree migration (`CoreMark ITER=100`):

- `CoreMark/MHz: 2.862 -> 2.942`
- `Total cycles: 34,933,286 -> 33,986,109`
- `IPC: 0.876 -> 0.901`
- `Frontend/empty: 1,968,111 -> 1,686,099`
- `Control recovery: 771,457 -> 550,238`
- `BTB mispredicts: 756,531 -> 534,343`

WSL-native validation so far:

- `make sim`: pass
- `quick-sort`: pass, `4487` cycles, `75` BTB mispredicts
- `CoreMark ITER=30`: pass, `CoreMark/MHz = 2.932`, `160,982` BTB mispredicts

Remaining WSL-native validation before delivery:

- `CoreMark ITER=100`
- B-line gate: `sum`, `quick-sort`, `cop-chain`, `cop-vadd8`, `cop-vadd8-chain`, `cop-vadd8-after-add`, `cop-vxor8`, `cop-vand8`, `cop-mixed-lanes`

## Assigned Tasks

### B-Task-7: BTB miss / mispredict reduction

Current status: **tournament-loop RTL prototype ported**

Next work under the same ROI rule:

1. Validate the WSL-native worktree result before any commit or merge.
2. Review hardware cost and timing risk before freezing table sizes.
3. Only continue if mispredict / control recovery / frontend bubble keep moving down together.
4. Keep using `CoreMark ITER=30` branch traces for screening; reserve `ITER=100` for final delivery validation.

### B-Task-8: redirect recovery 3 -> 2 cycles

Current status: **analysis complete, RTL not started**

Constraint:

- `skip_pre_valid` is a failed path and should not be revived.
- Any new attempt must solve valid/payload timing alignment directly, not by masking control only.
- Preferred route is synchronous flush inputs for IFU/IDU and IDU/EXU, not raw async-reset fanout.

## B-Line Gate

Current B-line regression gate:

1. `sum`
2. `quick-sort`
3. `cop-chain`
4. `cop-vadd8`
5. `cop-vadd8-chain`
6. `cop-vadd8-after-add`
7. `cop-vxor8`
8. `cop-vand8`
9. `cop-mixed-lanes`

Any patch touching redirect/refetch/flush must also record either commit-trace evidence or the first failing committed PC.

## Coordination

- B is in active frontend performance mode, not maintenance.
- B currently carries a behavior-changing candidate for `B-Task-7`.
- B owns `vsrc/cpu/ifu/*`, `vsrc/cpu/idu/*`, `vsrc/vector/cop/*`, and related frontend analysis/status docs.
