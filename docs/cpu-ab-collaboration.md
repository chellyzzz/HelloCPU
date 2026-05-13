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

The #1 performance bottleneck is now entirely in B's domain: frontend/empty (55%) + control recovery (22%) = **77% of all stalls**. Root cause: 772K redirects × 3 cycles each = 2.3M cycles, driven by 780K BTB mispredicts.

### B-Task-7: BTB Miss Rate Reduction (HIGH PRIORITY)

**Target:** Reduce BTB mispredict rate from 11.2% (780K events) to below 8%.

**Why this task:** 780K mispredicts × 3 cycles = 2.3M cycles = 65% of total stalls. Even a 3% absolute reduction in BTB miss rate saves ~200K cycles.

**Approaches to evaluate (B chooses and implements):**
- BTB capacity increase (current 128 entries)
- BTB associativity improvement (current direct-mapped within sets)
- Better replacement policy
- Static prediction heuristics (backward-taken was rejected for CoreMark but other heuristics may work)
- Two-level prediction (local/global history)

**B has full authority over** `vsrc/cpu/ifu/btb.v` and `vsrc/cpu/ifu/ifu.v`. B may also modify `ifu_idu_regs.v` and `idu_exu_regs.v` if pipeline timing changes are needed.

**Delivery:**
- RTL diff with behavioral change
- B-line gate: 10 tests PASS
- CoreMark ITER=100 data
- If no CoreMark improvement, document why and propose next approach

### B-Task-8: Redirect Recovery Latency Reduction (MEDIUM PRIORITY)

**Target:** Reduce redirect recovery from 3 cycles to 2 cycles.

**Why this task:** 772K redirects × 1 cycle saved = 772K cycles (~2% CoreMark/MHz).

**Previous attempt (B-Task-6) failed:** `skip_pre_valid` approach had zero effect because `ifu_idu_regs.o_pc` is registered — the payload is stale on the cycle `accel_fire` captures it. The fundamental issue is that correct instruction data arrives 1 cycle after `icache_hit` asserts.

**B must find a different approach.** Possible directions:
- Combinational bypass of `o_pc`/`o_ins` from IFU inputs when register is in reset state
- Earlier redirect signal (move flush from WBU to EXU)
- Overlap redirect recovery with last cycle of previous instruction

**Delivery:** Same standard as Task-7.

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
