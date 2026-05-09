# CPU A/B Collaboration

This document coordinates the two-agent CPU optimization split.

## Roles

### A: CPU Mainline Performance And Integration

A owns the stable CPU mainline and short-cycle performance work.

Primary responsibilities:

1. Maintain the stable CPU baseline on `cpu-mainline-branch`.
2. Own LSU, MUL/DIV, performance counters, CoreMark data, and regression summaries.
3. Decide which patches are safe to enter the mainline.
4. Keep CPU performance documentation current.
5. Integrate B-line patches only after their risk and regression status are clear.

Default A-owned files:

1. `sim/sim_main.cpp`
2. `vsrc/top/hcpu.v`
3. `vsrc/exu/lsu.v`
4. `vsrc/exu/multiplier.v`
5. `vsrc/exu/divider.v`
6. `docs/coremark-results.md`
7. `docs/cpu-design-plan.md`
8. `docs/microarchitecture.md`

### B: Frontend Handshake And Vector Interface

B owns high-risk frontend/interface exploration.

Primary responsibilities:

1. Analyze IFU/IDU valid-ready, PC advance, ICache hit/data, redirect/refetch, and flush timing.
2. Propose the smallest safe IFU/IDU standardization plan before changing RTL.
3. Maintain CPU/vector interface notes around the `409575a` project layout.
4. Keep COP/vector interface experiments isolated from A's performance mainline.
5. Record failed experiments with the first observed failure symptom.

Default B-owned files:

1. `vsrc/ifu/*`
2. `vsrc/idu/*`
3. `vsrc/vector/cop/*`
4. `docs/cpu-vector-coproc-handoff.md`
5. `docs/vector-coprocessor-microarchitecture.md`
6. B-line analysis docs such as `docs/ifu-idu-handshake-analysis.md`

## Shared Files

The following files are shared integration points and should not be edited independently by both agents in long-lived WIP:

1. `vsrc/top/hcpu.v`
2. `docs/cpu-design-plan.md`
3. `docs/microarchitecture.md`
4. `docs/cpu-vector-development-plan.md`
5. `docs/coremark-results.md`

If B needs changes in a shared file, B should write the requested semantic change in its analysis document first. A handles final integration into the mainline unless explicitly agreed otherwise.

For the current split, `vsrc/top/hcpu.v`, `docs/cpu-design-plan.md`, and `docs/coremark-results.md` are frozen for long-lived parallel edits outside A. B should not carry persistent WIP against these files.

## Branch And Patch Rules

1. A works on the stable CPU performance branch and keeps changes small and regression-backed.
2. B works in a separate frontend/interface experiment branch or isolated context.
3. Mainline entry is controlled by A. B outputs small diffs from `cpu-frontend-interface-lab` and does not land directly in `cpu-mainline-branch`.
4. A should publish a clear stable commit or tag at each integration point. B rebases only on that stable point, not on A's unverified WIP.
5. If A cherry-picks from B, prefer taking the small RTL patch first. Large B-line documents can be merged separately.
6. B should not reintroduce `d1d7bad feat: add dedicated IDU to cop issue queue` or its frontend ready mux approach.
7. New COP/vector work should follow the `409575a refactor: organize cpu vector project layout` direction and avoid extending old `vsrc/exu` / `vsrc/idu` COP paths.
8. Failed B experiments should be reverted from RTL but recorded in docs with failure symptoms.
9. Default collaboration should use normal WSL-side branches. If an auxiliary worktree or clone is needed, create and operate it inside WSL; avoid Windows Git worktrees being consumed by WSL Git.

## Regression Gates

### A-line Gate

A patches should run the most specific relevant tests first, then broader protection tests when behavior changes.

Current minimum for performance-counter-only patches:

1. `make sim`
2. `mul-longlong.bin`
3. `wanshu.bin`
4. `sum.bin`
5. `cop-chain.bin`
6. `quick-sort.bin`
7. `coremark.bin` when CoreMark-facing numbers or conclusions are updated

### B-line Gate

B frontend/interface patches should at least run:

1. `sum.bin`
2. `quick-sort.bin`
3. `cop-chain.bin`
4. `cop-vadd8` when available in the current build/layout

Any patch touching redirect/refetch/flush should also record either commit-trace evidence or the first failing committed PC if it fails.

`cop-vadd8` is not currently present in this CPU worktree's built test set. A and the vector side need to confirm whether that test is provided by the vector branch/layout or should be added to the CPU-side regression build.

## Current A Progress

Current A stable context:

1. CPU mainline includes `5a5caa9 fix: preserve consecutive cop issue flow`.
2. LSU fast paths and start-pulse optimization are already reflected in the current CoreMark reference.
3. CoreMark `ITER=100` current reference is `2.381 CoreMark/MHz`, `IPC=0.729`, and `25.2%` stall rate after the low `MUL` fast path.
4. MUL/DIV stall counters are now split into MUL and DIV sub-classes in both total stall and IFU-held-valid views.

Latest A validation:

1. `make sim`: no rebuild needed.
2. `mul-longlong.bin`: PASS, `MUL=34`, `DIV=0`.
3. `wanshu.bin`: PASS, `MUL=0`, `DIV=13398`.
4. `sum.bin`: PASS, `cycles=919`.
5. `cop-chain.bin`: PASS, `cycles=139`.
6. `quick-sort.bin`: PASS, `cycles=5059`.
7. `coremark.bin`: PASS, `CoreMark/MHz=2.381`, `MUL=0`, `DIV=3762` in `MUL/DIV wait`.

Current A conclusion:

1. Low `MUL` backpressure has been removed from the CoreMark bottleneck list.
2. DIV remains important for division-heavy tests such as `wanshu`, but it is not the CoreMark-first target.
3. A's next likely CPU optimization target returns to LSU/load-use/internal coupling, with branch recovery as the next explicit non-LSU class.

Latest A rejected experiment:

1. Experiment: remove `mul_busy` from `vsrc/exu/multiplier.v` so `mul_done` follows `mul_valid` after one pipeline register stage.
2. Intended effect: reduce MUL global ready backpressure without changing front-end handshakes.
3. Result: rejected. `mul-longlong.bin` failed with exit code `1` after committing only 4 multiply instructions.
4. First observation: MUL wait dropped from `34` to `3` cycles, but architectural result was wrong, so the current EXU/multiplier result and valid timing cannot be shortened by simply deleting `mul_busy`.
5. Status: RTL experiment reverted; keep the current 2-cycle multiplier behavior until result/valid alignment is redesigned more carefully.

Latest A accepted experiment:

1. Experiment: add a low `MUL` fast path in `vsrc/exu/exu.v` for `func3 == 3'b000` while keeping `MULH/MULHSU/MULHU` and DIV on the original multi-cycle paths.
2. Result: accepted after targeted, full CPU, and CoreMark regressions.
3. `mul-longlong.bin`: PASS, cycles `693 -> 681`, `MUL/DIV wait` `34 -> 20`.
4. `matrix-mul.bin`: PASS, `MUL/DIV wait = 0`.
5. `coremark.bin`: PASS, `CoreMark/MHz 2.279 -> 2.381`, `IPC 0.698 -> 0.729`, stall rate `28.4% -> 25.2%`.
6. Full CPU regression: `42 passed, 0 failed`.

## Current B Progress

Current B context:

1. B has not yet delivered a mainline patch in this branch.
2. Previous local IFU/IDU standardization experiment failed and was reverted from RTL.
3. The failure symptom was `sum` skipping the first instruction after reset/redirect; commit trace missed `0x30000000` and `0x30000b00`.
4. COP response currently conservatively triggers `cop_refetch_flush` to avoid duplicate commit or skipped following instructions before IFU/IDU semantics are standardized.
5. Vector-side layout synchronization point is `409575a refactor: organize cpu vector project layout`.

Current B expected deliverables:

1. `docs/ifu-idu-handshake-analysis.md` or equivalent timing analysis.
2. A minimal IFU/IDU standardization proposal covering PC advance, ICache hit/data, boundary payload, redirect/refetch, and flush same-cycle behavior.
3. A small patch only after the timing analysis explains why it avoids the known `sum` failure mode.

Current B first patch scope:

1. Touch only `vsrc/ifu/ifu.v`, `vsrc/ifu/ifu_idu_regs.v`, and the frontend analysis document.
2. Start with behavior-equivalent naming such as `fetch_fire`.
3. Do not perform IFU/IDU standardization refactor in the first patch.
4. For any redirect/refetch/flush change, write a short semantic note and record the first failing symptom before asking A to integrate.

## Coordination Notes

1. A controls mainline entry.
2. B can experiment aggressively, but should not leave failed RTL in the shared branch.
3. Shared-file conflicts are resolved by semantic ownership, not by whichever agent sees the conflict first.
4. Documentation updates should state whether they describe current mainline behavior, a historical snapshot, or an experiment.
5. Stable points should be documented before they are suggested for vector-side synchronization.
