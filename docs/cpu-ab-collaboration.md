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

1. CPU mainline stable base is `b73e571 feat: expand BTB, add pc_update attribution, sync vector lane ops` on `cpu-mainline-branch`.
2. 128-entry BTB, WBU `pc_update` attribution counters, and vector `d8d578d` lane ops are all landed.
3. CoreMark `ITER=100` current reference is `2.381 CoreMark/MHz`, `IPC=0.729`, `25.2%` stall rate.
4. MUL/DIV stall counters are split; MUL fast path landed; DIV is the only remaining MUL/DIV cost.
5. LSU wait: `start = 6973290 (99.9% of LSU wait)`, load `5473096 (78.5%)`, store `1500194 (21.5%)`; refill/uncache/wb combined < 7000 cycles.

Latest A validation:

1. `make sim`: PASS.
2. Full CPU regression: `48 passed, 0 failed`.
3. `coremark.bin`: PASS, `CoreMark/MHz=2.381`.

Latest A conclusion:

1. LSU 1-cycle hit penalty (S_IDLE → S_CHECK) is the single largest bottleneck: 6.97M cycles = 16.6% of total execution time.
2. All AXI-level LSU optimizations (fast_done, RREADY, writeback burst) together save < 0.01% on CoreMark because cache misses are negligible.
3. A's next target is same-cycle LSU hit, but this requires IFU/IDU handshake cooperation — documented as needing B-line interface support first.
4. Branch recovery (7.5% of stalls, 1.9% of cycles) and frontend bubbles (18.6% of stalls, 4.7% of cycles) are the next-low-hanging-fruit after LSU.

Latest A accepted experiment:

1. 128-entry BTB: accepted. Cycles `42000681 → 41986504`, BTB miss reduced, small positive.
2. WBU `pc_update` attribution counters: accepted. CoreMark unchanged, diagnostics improved.

Latest A rejected experiments (unchanged):

1. Remove WBU branch/JAL/JALR `pc_update`: rejected, breaks `sum`/`cop-chain`/`quick-sort`.
2. Static backward-taken BTB miss heuristic: rejected, CoreMark regressed `2.381 → 2.373`.
3. LSU same-cycle load-hit: rejected, breaks `load-store`/`quick-sort`.
4. LSU same-cycle current-ready start: rejected, `sum` timeout / `quick-sort` timeout.
5. LSU refill same-cycle result: rejected, breaks `quick-sort`.

Latest A LSU micro-optimization (landed, negligible on CoreMark):

1. Added `fast_refill_done`, `fast_uncache_r_done`, `fast_uncache_b_done` combinational completion paths in `lsu.v`.
2. These eliminate the 1-cycle `done_reg` pulse after AXI completion for load miss, uncache read, and uncache store.
3. CoreMark impact: ~0% (cache miss rate too low for this to matter).
4. Combinational RREADY/BREADY attempt was also tested but abandoned: the AXI RAM simulation model uses a 2-phase FSM that requires registered RREADY, making combinational RREADY cause simulation hangs.

## Current B Progress

Current B context:

1. B has rebased to A stable point `d9e7702 refactor: sync vector coprocessor layout`.
2. B determined that **pass-through is the correct V1 frontend architecture** after ruling out registered-valid and skid buffer approaches.
3. `0001` behavior-equivalent IFU `fetch_fire` RTL naming is already integrated in `d9e7702`; B currently carries no behavior-changing RTL diff.
4. B's IFU/IDU analysis doc is at `docs/cpu/ifu-idu-handshake-analysis.md`; exported patch is `patches/0002-docs-ifu-idu-handshake-analysis.patch`.
5. IFU/IDU-only registered-valid failure is confirmed: `sum` misses commits at `0x30000000` and `0x30000b00`; B will not repeat that local patch.
6. COP interface is clean; debug/assert instrumentation is in place.
7. B has only low-risk instrumentation patches (0003~0005) remaining; no behavior changes.

B-line status document: `docs/cpu/b-line-status.md`.

B is now in **maintenance mode**. B will resume active work when A needs frontend/interface support for same-cycle LSU hit or other pipeline restructuring.

Current B assigned tasks (for A same-cycle LSU hit preparation):

1. **B-Task-1: IFU/IDU pass-through protocol specification document** — Formalize V1 correct architecture semantics: signal meanings, valid/ready lifecycle, payload hold rules, redirect/refetch semantics. Pure documentation, no RTL change. Deliverable: update `docs/cpu/ifu-idu-handshake-analysis.md` with a formal protocol section.

2. **B-Task-2: IFU/IDU/EXU protocol assertion coverage** — Add `ifdef`-protected SystemVerilog assertions in `vsrc/cpu/ifu/` and `vsrc/cpu/idu/` verifying pass-through invariants: `idu2exu_valid` stability while `!exu2idu_ready`, `idu2ifu_ready` derivation from `exu2idu_ready`, payload stability guarantees, etc. No behavior change. Deliverable: assertion patches in `cpu-frontend-interface-lab`.

3. **B-Task-3: same-cycle LSU result interface design memo** — Per A/B behavior-RTL rule, write a 5-line design note + failure plan describing what interface changes IFU/IDU must provide for A to implement same-cycle LSU hit: how EXU `pre_ready` should respond in the first cycle, whether IDU `valid` release conditions change, whether payload needs latching, etc. Deliverable: section in B status doc, referenced from `docs/cpu/ifu-idu-handshake-analysis.md`.

## Coordination Notes

1. A controls mainline entry.
2. B can experiment aggressively, but should not leave failed RTL in the shared branch.
3. Shared-file conflicts are resolved by semantic ownership, not by whichever agent sees the conflict first.
4. Documentation updates should state whether they describe current mainline behavior, a historical snapshot, or an experiment.
5. Stable points should be documented before they are suggested for vector-side synchronization.
