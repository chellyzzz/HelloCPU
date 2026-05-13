# CPU A/B Collaboration

This document coordinates the two-agent CPU optimization split.

## Roles

### A: CPU Backend Performance And Integration

A owns the stable CPU mainline, backend execution, and performance integration.

Primary responsibilities:

1. Maintain the stable CPU baseline on `cpu-mainline-branch`.
2. Own EXU pipeline: LSU, MUL/DIV, ALU, performance counters.
3. Decide which patches enter the mainline.
4. Run CoreMark benchmarks and maintain performance documentation.
5. Integrate B-line behavioral patches after review.

A-owned files:

1. `vsrc/cpu/exu/*` (lsu, multiplier, divider, alu, exu)
2. `vsrc/cpu/wbu/*`
3. `vsrc/cpu/top/hcpu.v`
4. `sim/sim_main.cpp`
5. `docs/cpu/coremark-results.md`
6. `docs/cpu/cpu-evolution-roadmap.md`

### B: CPU Frontend Performance

B owns the frontend pipeline and is responsible for **delivering measurable performance improvements** through RTL changes.

Primary responsibilities:

1. Own IFU, IDU, pipeline registers (`ifu_idu_regs`, `idu_exu_regs`), BTB, RAS, ICache.
2. **Reduce frontend/empty stalls and redirect recovery cost** — currently the #1 bottleneck at 2M cycles (55% of all stalls).
3. Implement behavioral RTL changes that pass regression and show CoreMark improvement.
4. Record failed experiments with failure symptoms.

B-owned files (B has full authority to modify these files):

1. `vsrc/cpu/ifu/*` (ifu, btb, ras, icache, ifu_idu_regs)
2. `vsrc/cpu/idu/*` (idu, idu_exu_regs)
3. `vsrc/cpu/Registers/*` (if needed for frontend-related CSR)
4. `docs/cpu/ifu-idu-handshake-analysis.md`
5. `docs/cpu/frontend-stall-analysis.md`
6. `docs/cpu/b-line-status.md`

### Vector/COP (C line)

C owns vector coprocessor development on `vector-next`. Separate from A/B split. A integrates C's changes at stable points. COP interface files are C-owned:

1. `vsrc/vector/cop/*`
2. `docs/vector/*`

## Shared Files

Files that require coordination:

1. `vsrc/cpu/top/hcpu.v` — A integrates, B requests changes via analysis doc
2. `docs/cpu/coremark-results.md` — A maintains
3. `docs/cpu/cpu-evolution-roadmap.md` — A maintains
4. `docs/cpu-ab-collaboration.md` — A maintains

B may modify shared files only with A's explicit approval for each change.

## D-Line Architecture Coordination

When cross-line interface control becomes the bottleneck, use D-line as the architecture / integration owner rather than pushing that work back onto A.

The D-line role, authority, and freeze rules are defined in:

- `docs/cpu/d-line-architecture-integration.md`

In short:

1. A still controls CPU mainline entry.
2. D controls cross-line interface clarity and freeze points.
3. A/B/C should involve D before merging changes that alter shared issue / completion / flush / memory boundary semantics.

## Branch Rules

1. A works on `cpu-mainline-branch`.
2. B works on `cpu-frontend-interface-lab`.
3. A controls mainline entry. B does not push to `cpu-mainline-branch`.
4. A publishes stable commits. B rebases on A's stable points.
5. Failed experiments must be reverted from RTL but documented.

## Delivery Standard

**Both A and B are held to the same delivery standard:**

Every behavioral RTL change must include:

1. The RTL diff itself
2. Full regression pass (see gates below)
3. CoreMark ITER=100 data showing cycle count change
4. If no CoreMark change, explain why the change is still worthwhile

Analysis documents, debug macros, and assertions alone do **not** count as deliveries. They are tools to support RTL work, not end products.

## Regression Gates

### A-line Gate

1. `make sim` (Verilator build)
2. Full regression: 48 tests, 0 failures
3. `coremark.bin` PASS when performance claims are made

### B-line Gate

B must pass **at minimum** these tests before requesting A review:

1. `sum.bin`
2. `quick-sort.bin`
3. `load-store.bin`
4. `cop-chain.bin`
5. `cop-vadd8.bin`
6. `cop-vadd8-chain.bin`
7. `cop-vadd8-after-add.bin`
8. `cop-vxor8.bin`
9. `cop-vand8.bin`
10. `cop-mixed-lanes.bin`

Any patch touching redirect/refetch/flush must include trace evidence or the first failing committed PC if it fails.

B must also run CoreMark ITER=100 and report cycle count before submitting for A review.

## Current A Progress

Stable HEAD: `8f48295 perf: DIV fast paths (by-1, trivial-zero) + fix perf counter docs`

CoreMark ITER=100 reference:

| Metric | Value |
|--------|-------|
| CoreMark/MHz | 2.853 |
| Total cycles | 35,047,662 |
| IPC | 0.874 |
| Stall rate | 10.4% |

Stall breakdown:

| Source | Cycles | % of stalls |
|--------|--------|-------------|
| Frontend/empty | 2,005,006 | 54.9% |
| Control recovery | 795,702 | 21.8% |
| Other backend | 837,926 | 23.0% |
| LSU wait | 7,107 | 0.2% |
| DIV wait | 2,962 | 0.1% |

A-line completed optimizations:

1. Same-cycle LSU load hit (+14.9% CoreMark/MHz): `442bff8`
2. Same-cycle LSU store hit (+4.2%): `9e92c22`
3. DIV fast paths (by-1, trivial-zero): `8f48295`
4. Redirect recovery cost measurement: `27d0e4f`
5. 128-entry BTB: `b73e571`
6. MUL low fast path: `2ce4777`

A-line EXU optimization is substantially complete. Remaining stall is dominated by frontend.

## Current B Assignment

**B is in active development mode, not maintenance.**

The previous frontend priorities already delivered two real gains: predictor-side redirect reduction and validated `redirect recovery 3 -> 2`. From this point on, B's main effort shifts from chasing the last small CoreMark branch-prediction gains to **2-wide preparation**.

### B-Task-10: 2-Wide Frontend Preparation (HIGH PRIORITY)

**Target:** Prepare the frontend and issue boundary so HelloCPU can move toward minimal `2-wide in-order` without ambiguous valid/ready/flush semantics.

**Why this task:** After the current frontend branch reached `CoreMark/MHz = 3.031` and validated `2 avg cycles` redirect recovery, further predictor-only gains are likely small and increasingly benchmark-specific. The better use of engineering time is to reduce integration risk for wider issue.

**Approaches to evaluate (B chooses and implements):**
- Formalize `IFU/IDU/IDU-EXU` contract for wider issue preparation
- Define fetch/decode queue insertion points and flush semantics
- Define predictor metadata carriage rules under queued / wider issue frontend
- Identify minimum frontend changes required before actual `2-wide` RTL begins

**B has full authority over** `vsrc/cpu/ifu/*`, `vsrc/cpu/idu/*`, and frontend-side coordination docs. Shared boundary changes still require A review.

**Delivery:**
- Boundary/design document updates
- If RTL is touched, B-line gate PASS
- A concise wider-issue preparation summary: what is already ready, what is still blocking

### B-Task-11: Predictor Refinement (SECONDARY)

**Target:** Only pursue low-risk predictor refinements that are easy to validate and easy to abandon.

**Why this task:** Remaining gains are still possible, but they are no longer the main strategic focus.

**Constraint:** Do not let predictor micro-tuning delay wider-issue preparation work.

**Possible directions:**
- Remaining `BTB-hit` direction errors
- Low-risk alias reduction
- Trace-driven hotspot analysis before any structural predictor change

**Delivery:** Same validation standard as before, but only when the change is small and clearly justified.

### B-Task-9: Pipeline Integration and Testing (ONGOING)

For every behavioral change, B must:
1. Activate `PROTOCOL_ASSERT` and `FRONTEND_ASSERT` builds and verify zero triggers
2. Run full B-line gate (10 tests)
3. Report CoreMark data

## Historical Record

### Completed B Tasks

| Task | Deliverable | Outcome |
|------|-------------|---------|
| B-Task-1 | Protocol spec doc | Completed. Analysis document only. |
| B-Task-2 | PROTOCOL_ASSERT hooks | Completed. Default-off, no behavioral change. |
| B-Task-3 | Same-cycle LSU design memo | Completed. Analysis confirmed correct; A implemented independently. |
| B-Task-4 | Frontend stall analysis | Completed. Identified 96% = redirect bubble. |
| B-Task-5 | PROTOCOL_ASSERT extension | Completed. Default-off, no behavioral change. |
| B-Task-6 | Redirect -1 cycle | **Failed.** Zero CoreMark impact. `skip_pre_valid` captures stale payload. |

### A-Line Rejected Experiments

1. Remove WBU branch/JAL/JALR `pc_update`: breaks `sum`/`cop-chain`/`quick-sort`
2. Static backward-taken BTB miss heuristic: CoreMark regressed 2.381 → 2.373
3. Combinational RREADY/BREADY: simulation hang, AXI RAM model incompatible

## Coordination Notes

1. A controls mainline entry.
2. B can modify any B-owned file without pre-approval. Shared files need A's explicit approval.
3. Documentation should state whether it describes current mainline behavior, a historical snapshot, or an experiment.
4. Stable points are documented before suggesting vector-side synchronization.
