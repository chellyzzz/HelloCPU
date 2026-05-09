# B-Line Status

Branch: `cpu-frontend-interface-lab`
Baseline: `d9e7702 refactor: sync vector coprocessor layout`
Current mode: **Maintenance**

## V1 Architecture Decision

Pass-through is the correct V1 frontend architecture.

### Ruled-out approaches

| Approach | Failure symptom | Verdict |
|----------|----------------|---------|
| Registered-valid (IFU/IDU `post_valid` hold) | `sum` misses commits at `0x30000000` and `0x30000b00`; instruction skipped after redirect | Rejected |
| Skid buffer | Not directly tested; inferred incompatible with current single-entry pipeline semantics | Rejected per analysis |

### Current baseline

- `0001` behavior-equivalent IFU `fetch_fire` naming is in mainline at `d9e7702`.
- `0002` IFU/IDU handshake analysis document is at `docs/cpu/ifu-idu-handshake-analysis.md`, patch at `patches/0002-docs-ifu-idu-handshake-analysis.patch`.
- Low-risk instrumentation patches `0003`~`0005` are pending; no behavior changes.
- COP interface is clean; debug/assert instrumentation in place.

## Assigned Tasks

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

- B enters maintenance mode after completing B-Task-1 through B-Task-3.
- B will resume active work when A needs frontend/interface support for same-cycle LSU hit or other pipeline restructuring.
- B carries no behavior-changing RTL diff on the current baseline.
- B owns `vsrc/cpu/ifu/*`, `vsrc/cpu/idu/*`, `vsrc/vector/cop/*`, `docs/interface/*`, and analysis docs.