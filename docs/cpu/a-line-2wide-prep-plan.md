# A-Line 2-Wide Preparation Plan

This document records the A-line backend preparation plan after frontend redirect recovery reached the validated `2-cycle` state on top of `ccd369c`.

## Current Context

- Frontend branch state: `codex/b-line-predictor-rtl`
- Frontend validation point: `ccd369c`
- Current reference result:
  - `CoreMark/MHz = 3.031`
  - `Redirect cost = 2 avg cycles`
  - `ITER=100` PASS

At this point, further branch hit-rate tuning has entered a smaller-yield zone. The main cross-line preparation target is no longer another local predictor patch, but reducing risk for a future minimal `2-wide in-order` path.

## Plan Table

| Priority | Task | Goal | Main Files | Exit Criteria |
|----------|------|------|------------|---------------|
| P0 | Audit `accept/done/commit` semantics | Make backend receive / complete / commit boundaries explicit | `vsrc/cpu/exu/exu.v`, `vsrc/cpu/top/hcpu.v`, `vsrc/cpu/wbu/wbu.v` | Each backend path clearly identifies accept, functional completion, and architectural commit. First audit pass complete in `docs/cpu/a-line-backend-contract-audit.md`. |
| P0 | Normalize `kill/flush/completion` handling | Prevent stale completion from re-entering post-redirect control flow | `vsrc/cpu/exu/exu.v`, `vsrc/cpu/top/hcpu.v` | Killed or stale completions are absorbed consistently and cannot fire redirect or commit-visible side effects. First cleanup pass landed in `exu_wbu_regs.v`, `wbu.v`, and `exu.v`. |
| P0 | Freeze scalar/COP owner contract | Preserve V1 memory-owner boundary while preparing for wider frontend behavior | `vsrc/cpu/top/hcpu.v`, `docs/interface/cpu-memory-service-model.md` | Scalar and COP request/response/kill responsibility is explicit and stable |
| P0 | Add directed stale-completion regressions | Cover the most fragile redirect/completion edge cases | `sim/*`, directed regression entry points | Key stale-completion and flush corner cases are reproducible and pass reliably |
| P1 | Map backend constraints for `2-wide` prep | Tell B-line exactly which backend assumptions must remain true | `docs/cpu/*` | Single-result, single-commit, and inflight ownership assumptions are documented |
| P1 | Defer low-yield datapath tuning | Keep effort focused on structure, not small local benchmark gains | Planning / coordination only | LSU/DIV/predictor micro-tuning is explicitly out of current A-line scope |

## Directed Regression Targets

The first directed validation wave should cover:

1. `flush during scalar memory response`
2. `flush during COP response`
3. `redirect around completion edge`
4. `request accepted, then killed before response visible`

These tests are more valuable than another local benchmark tweak because they protect the new frontend recovery baseline from backend semantic regressions.

Current progress on this validation wave:

- `EXU/WBU` flush payload clearing: covered by `make exu_wbu_flush`
- scalar completion visibility filtering: covered by `make exu_result_visibility`
- COP pending/visible response flush: covered by `make cop_backend_flush`
- COP inflight ownership across `kill`, `dequeue`, and same-cycle replacement: covered by `make idu_cop_regs`
- combined focused suite: `make backend_contract_checks`

## Early Decoupling Guidance

Some decoupling should happen now, but only where it lowers future `2-wide` integration risk without forcing a premature backend rewrite.

### Recommended Early Decoupling

1. **`accept` from `commit`**

   The backend should not rely on “instruction accepted” meaning “soon architecturally committed.” This distinction is important before any queue insertion or wider issue preparation.

2. **Request ownership from response visibility**

   V1 memory owner semantics can stay single-owner, but the code should clearly separate:
   - who owns the inflight request,
   - who absorbs the completion,
   - who is allowed to expose the completion architecturally.

3. **`flush/kill` from `result valid`**

   A returning result should not automatically become architecturally visible. It must first pass kill/flush filtering.

4. **Frontend redirect cause from backend completion cause**

   Redirect ownership should stay unique. The system should not regress into duplicated redirect handling across EXU and WBU.

### Decoupling To Avoid For Now

1. Do not convert LSU/COP into a fully decoupled multi-queue backend yet.
2. Do not implement true dual-issue backend machinery yet.
3. Do not introduce scoreboard- or reorder-style complexity before the current single-result semantics are fully clarified.

## Practical A-Line Rule

The current goal is not to redesign the backend into a wide machine now.

The current goal is to make the existing single-issue backend clean enough that a future wider frontend can drive it safely without hidden assumptions around completion, kill, or commit ordering.

## Recommended Execution Order

1. Audit `accept/done/commit` and `kill/flush` semantics.
2. Add the first directed stale-completion regression set.
3. Publish a backend constraint note for `2-wide` preparation.
4. Only after that, consider any behavior changes in support of wider issue or queue insertion.
