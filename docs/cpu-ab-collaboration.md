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
2. `vsrc/cpu/top/hcpu.v`
3. `vsrc/cpu/exu/lsu.v`
4. `vsrc/cpu/exu/multiplier.v`
5. `vsrc/cpu/exu/divider.v`
6. `docs/cpu/coremark-results.md`
7. `docs/cpu/cpu-design-plan.md`
8. `docs/cpu/microarchitecture.md`

### B: Frontend Handshake And Vector Interface

B owns high-risk frontend/interface exploration.

Primary responsibilities:

1. Analyze IFU/IDU valid-ready, PC advance, ICache hit/data, redirect/refetch, and flush timing.
2. Propose the smallest safe IFU/IDU standardization plan before changing RTL.
3. Maintain CPU/vector interface notes around the `d8d578d` project layout and COP lane-operation baseline.
4. Keep COP/vector interface experiments isolated from A's performance mainline.
5. Record failed experiments with the first observed failure symptom.
6. Maintain B-line analysis documents and low-risk cleanup commits in `cpu-frontend-interface-lab` before asking A to review or cherry-pick.

Default B-owned files:

1. `vsrc/cpu/ifu/*`
2. `vsrc/cpu/idu/*`
3. `vsrc/vector/cop/*`
4. `docs/interface/cpu-vector-coproc-handoff.md`
5. `docs/vector/vector-coprocessor-microarchitecture.md`
6. `docs/cpu/ifu-idu-handshake-analysis.md`
7. CPU/COP interface notes under `docs/interface/*`

## Shared Files

The following files are shared integration points and should not be edited independently by both agents in long-lived WIP:

1. `vsrc/cpu/top/hcpu.v`
2. `docs/cpu/cpu-design-plan.md`
3. `docs/cpu/microarchitecture.md`
4. `docs/interface/cpu-vector-development-plan.md`
5. `docs/cpu/coremark-results.md`

If B needs changes in a shared file, B should write the requested semantic change in its analysis document first. A handles final integration into the mainline unless explicitly agreed otherwise.

For the current split, `vsrc/cpu/top/hcpu.v`, `docs/cpu/cpu-design-plan.md`, and `docs/cpu/coremark-results.md` are frozen for long-lived parallel edits outside A. B should not carry persistent WIP against these files.

## Branch And Patch Rules

1. A works on the stable CPU performance branch and keeps changes small and regression-backed.
2. B works in a separate frontend/interface experiment branch or isolated context.
3. Mainline entry is controlled by A. B outputs small diffs from `cpu-frontend-interface-lab` and does not land directly in `cpu-mainline-branch`.
4. A should publish a clear stable commit or tag at each integration point. B rebases only on that stable point, not on A's unverified WIP.
5. B should form complete small commits in `cpu-frontend-interface-lab`; A reviews or cherry-picks those commits instead of reorganizing B's patches for B.
6. B should not reintroduce `d1d7bad feat: add dedicated IDU to cop issue queue` or its frontend ready mux approach.
7. New COP/vector work should follow the `539bf41 fix: repair consecutive cop commit timing` baseline and avoid extending old `vsrc/exu` / `vsrc/idu` COP paths.
8. Failed B experiments should be reverted from RTL but recorded in docs with failure symptoms.
9. Default collaboration should use normal WSL-side branches. If an auxiliary worktree or clone is needed, create and operate it inside WSL; avoid Windows Git worktrees being consumed by WSL Git.
10. B-owned analysis docs such as `docs/cpu/ifu-idu-handshake-analysis.md` are maintained by B; A gives direction-level review and does not need to integrate them line by line.

Low-risk B RTL cleanup may be submitted to A review after the B-line gate when it is naming-only, signal splitting, read-only debug macro work, or default-off assertion/debug instrumentation that does not change behavior.

Behavior RTL changes must not enter through the low-risk path. Any change touching ready/valid, flush/refetch, COP response, EXU entry valid, or shared recovery semantics must first include a short design note plus the expected first failure mode and validation plan; A decides whether and how it enters mainline integration.

A remains the integrator for shared CPU mainline semantics and files such as `vsrc/cpu/top/hcpu.v`, performance counters, CoreMark documentation, LSU, MUL, and DIV.

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
4. `cop-vadd8`
5. `cop-vadd8-chain`
6. `cop-vadd8-after-add`
7. `cop-vxor8`
8. `cop-vand8`
9. `cop-mixed-lanes`

Any patch touching redirect/refetch/flush should also record either commit-trace evidence or the first failing committed PC if it fails.

`cop-vadd8`, `cop-vadd8-chain`, `cop-vadd8-after-add`, `cop-vxor8`, `cop-vand8`, and `cop-mixed-lanes` are now present in the CPU-side regression build after syncing the vector layout.

## Current A Progress

Current A stable context:

1. CPU mainline stable base is `d9e7702 refactor: sync vector coprocessor layout`; current A WIP has also integrated vector COP lane ops through `d8d578d`.
2. LSU fast paths and start-pulse optimization are already reflected in the current CoreMark reference.
3. CoreMark `ITER=100` current reference is `2.381 CoreMark/MHz`, `IPC=0.729`, and `25.2%` stall rate after the low `MUL` fast path.
4. MUL/DIV stall counters are now split into MUL and DIV sub-classes in both total stall and IFU-held-valid views.
5. LSU wait is now further split by request-start load/store contribution: CoreMark `start = 6973588`, load start `5473195`, store start `1500393`.

Latest A validation:

1. `make sim`: PASS.
2. `sum.bin`: PASS, `cycles=919`.
3. `quick-sort.bin`: PASS, `cycles=5059`.
4. `cop-chain.bin`: PASS, `cycles=139`.
5. `coremark.bin`: PASS, `CoreMark/MHz=2.381`, `MUL=0`, `DIV=3762` in `MUL/DIV wait`.
6. Full CPU regression: `42 passed, 0 failed`.

Current A conclusion:

1. Low `MUL` backpressure has been removed from the CoreMark bottleneck list.
2. DIV remains important for division-heavy tests such as `wanshu`, but it is not the CoreMark-first target.
3. A's next CPU optimization target remains LSU/load-use/internal coupling, but the latest counter split shows it is specifically LSU request-start coupling: CoreMark `LSU wait = 6980532`, `start = 6973588`, with load start `5473195` and store start `1500393`.
4. Branch recovery remains the next explicit non-LSU class.

Latest A rejected experiment:

1. Experiment: remove `mul_busy` from `vsrc/cpu/exu/multiplier.v` so `mul_done` follows `mul_valid` after one pipeline register stage.
2. Intended effect: reduce MUL global ready backpressure without changing front-end handshakes.
3. Result: rejected. `mul-longlong.bin` failed with exit code `1` after committing only 4 multiply instructions.
4. First observation: MUL wait dropped from `34` to `3` cycles, but architectural result was wrong, so the current EXU/multiplier result and valid timing cannot be shortened by simply deleting `mul_busy`.
5. Status: RTL experiment reverted; keep the current 2-cycle multiplier behavior until result/valid alignment is redesigned more carefully.

Latest A accepted experiment:

1. Experiment: add a low `MUL` fast path in `vsrc/cpu/exu/exu.v` for `func3 == 3'b000` while keeping `MULH/MULHSU/MULHU` and DIV on the original multi-cycle paths.
2. Result: accepted after targeted, full CPU, and CoreMark regressions.
3. `mul-longlong.bin`: PASS, cycles `693 -> 681`, `MUL/DIV wait` `34 -> 20`.
4. `matrix-mul.bin`: PASS, `MUL/DIV wait = 0`.
5. `coremark.bin`: PASS, `CoreMark/MHz 2.279 -> 2.381`, `IPC 0.698 -> 0.729`, stall rate `28.4% -> 25.2%`.
6. Full CPU regression: `42 passed, 0 failed`.

Latest A rejected LSU experiments:

1. Experiment: drive LSU transaction start from EXU current `ready` / current `valid` instead of the existing delayed start detection.
2. Result: rejected. Direct current-`ready` start caused `sum`, `load-store`, `mem`, and `quick-sort` to timeout before real LSU traffic; current-`valid` start passed simple cases but made `quick-sort` timeout.
3. Experiment: add an `S_IDLE` same-cycle cacheable load-hit fast path while leaving store hit on the old path.
4. Result: rejected. It improved `sum` locally but broke `load-store` and `quick-sort`; suppressing duplicate start then caused `load-store` to hang in LSU start.
5. Conclusion: the remaining LSU start/load-use cost cannot be fixed by local LSU same-cycle completion alone; it needs EXU/IDU valid lifetime or request/response boundary cleanup.

Latest A branch-recovery observations:

1. Experiment: remove WBU branch/JAL/JALR `pc_update` and rely only on EXU redirect while keeping ECALL/MRET redirects.
2. Result: rejected. `sum` and `cop-chain` timeout; `quick-sort`, `btb-basic`, and `btb-jal` fail.
3. Conclusion: EXU redirect and WBU architectural redirect are still both part of the current frontend recovery semantics; branch recovery must be shortened by redesigning redirect/flush ownership, not by deleting the WBU pulse.
4. New counters split WBU `pc_update`: CoreMark has `805218` total, with branch `763699` (`94.8%`), JAL `4918` (`0.6%`), JALR `36601` (`4.5%`), ECALL/MRET `0`.
5. Experiment: predict backward branches taken on BTB miss using a static fallback target.
6. Result: rejected. Functional smoke tests passed, but CoreMark regressed from `2.381` to `2.373 CoreMark/MHz` and BTB mispredicts increased from `790496` to `813296`.
7. Experiment: increase BTB from 64 to 128 entries.
8. Result: accepted. CoreMark simulator cycles improved `42000681 -> 41986504`, BTB miss `1082991 -> 1025584`, BTB mispredict `790496 -> 780786`, WBU `pc_update` `805218 -> 795702`; rounded `CoreMark/MHz` remains `2.381`.

## Current B Progress

Current B context:

1. B has rebased to A stable point `d9e7702 refactor: sync vector coprocessor layout`.
2. B will no longer work from old `vsrc/exu` or `vsrc/idu` COP paths; new work uses `vsrc/cpu/*` and `vsrc/vector/cop/*`.
3. `0001` behavior-equivalent IFU `fetch_fire` RTL naming is already integrated in `d9e7702`; B currently carries no RTL diff.
4. B's IFU/IDU analysis doc has moved to `docs/cpu/ifu-idu-handshake-analysis.md`; exported patch is `patches/0002-docs-ifu-idu-handshake-analysis.patch`.
5. The B doc now describes the new layout and the post-`d9e7702` COP refetch rule: `cop_refetch_flush = cop_resp_fire`.
6. B validation passed: `make sim sw`, `sum`, `quick-sort`, `cop-chain`, `cop-vadd8`, `cop-vadd8-chain`, and `cop-vadd8-after-add`.
7. IFU/IDU-only registered-valid failure is confirmed: `sum` misses commits at `0x30000000` and `0x30000b00`; B will not repeat that local patch.
8. B's current judgment is that true standardization must handle implicit pre-valid bubbles and may involve IDU/EXU, EXU entry valid, or `vsrc/cpu/top/hcpu.v`, so A must participate in the integration plan.

Current B expected deliverables:

1. Keep `docs/cpu/ifu-idu-handshake-analysis.md` current from the B branch.
2. Prefer macro-control debug/assertion or design-plan convergence before changing frontend ready/valid behavior.
3. A minimal IFU/IDU standardization proposal covering PC advance, ICache hit/data, boundary payload, redirect/refetch, implicit bubbles, and flush same-cycle behavior.
4. A small behavior patch only after the timing analysis explains why it avoids the known `sum` failure mode.

Current B first patch scope:

1. Touch only `vsrc/cpu/ifu/ifu.v`, `vsrc/cpu/ifu/ifu_idu_regs.v`, and the frontend analysis document.
2. Start with behavior-equivalent naming such as `fetch_fire`.
3. Do not perform IFU/IDU standardization refactor in the first patch.
4. For any redirect/refetch/flush change, write a short semantic note and record the first failing symptom before asking A to integrate.

## Coordination Notes

1. A controls mainline entry.
2. B can experiment aggressively, but should not leave failed RTL in the shared branch.
3. Shared-file conflicts are resolved by semantic ownership, not by whichever agent sees the conflict first.
4. Documentation updates should state whether they describe current mainline behavior, a historical snapshot, or an experiment.
5. Stable points should be documented before they are suggested for vector-side synchronization.
