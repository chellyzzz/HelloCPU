# RVV Mainline Merge Summary

This document summarizes the work on `vector-next-rvv-state-p1` since the `f40f67d` CPU mainline merge baseline. The branch closes the first partial RVV implementation slice; it does not attempt full RVV compliance.

## Branch Scope

- Introduce standard RVV decode paths for the selected OP-V and vector memory subset.
- Reuse the existing CPU/COP single-issue, single-request-in-flight, WBU-visible commit and kill contract.
- Keep unsupported RVV features fail-closed or explicitly deferred rather than approximating full RVV behavior.
- Preserve custom COP helpers as legacy/debug harnesses, not as the architectural RVV programming model.

## Implemented RVV Subset

- Configuration and state: `vsetvli` rs1 AVL path, `vl`, `vtype`, `vstart` CSR mirrors, `vill` for unsupported `vtypei`.
- Registers: standard `v0-v31` register fields with `LMUL=m1` only.
- Execute: `vadd`, `vsub`, `vand`, `vor`, `vxor`, `vsll`, `vsrl`, `vsra`, `vmul`, `vmv.v.v`, and `vmv.v.x` for the supported forms.
- Mask/select: execute-class `vm=0` using `v0`, compare-to-mask `vmseq/vmsne/vmsltu/vmslt`, and `vmerge.vvm/vxm`; masked-off lanes are undisturbed.
- Memory: unmasked unit-stride `vle8.v`, `vse8.v`, `vle16.v`, `vse16.v`, `vle32.v`, and `vse32.v` through the existing COP memory owner boundary.

## Key Boundaries

- `SEW=8/16/32` are supported for the current benchmark-driven subset.
- `LMUL>m1`, fractional LMUL, grouped register aliasing, `vstart` restart, precise vector exceptions, and full illegal trap integration remain out of scope.
- Masked memory, strided/indexed/segment/fault-only-first memory, FP, widening/narrowing, saturating, divide/remainder, and full RVV compliance remain out of scope.
- Scalar cache and COP memory-bypass coherency uses the staged contract documented in `rvv-subset-freeze.md`: static backing vector loads plus vector stores to scalar-visible destinations are covered; scalar-store-to-vector-load coherence remains out of scope.

## Validation

- Focused RVV tests cover `vsetvli`, ALU, bitwise, move, shift, multiply, compare/merge, mask, CSR mirror, vector memory, unsupported OP-V, and subset acceptance.
- Directed owner/kill tests cover scalar pending memory kill, COP pending memory kill, COP store owner path, and pre-accept killed COP store behavior.
- `make rvv-subset-smoke EXTRA_VERILATOR_FLAGS='-j 1'` is the fixed partial RVV smoke entry.
- `make rvv-bench-run EXTRA_VERILATOR_FLAGS='-j 1'` runs the local RVV benchmark harness.
- `make rvv-final-acceptance EXTRA_VERILATOR_FLAGS='-j 1'` is the final benchmark-driven gate and includes `git diff --check`, smoke, and benchmarks.

## Next Development Plan

- Treat the benchmark-driven partial RVV subset as complete for this branch.
- Keep true scalar-cache/COP-bypass coherency explicitly deferred unless a later phase updates the CPU/COP memory boundary.
- Keep full RVV compliance, `LMUL>m1`, `vstart` restart, masked memory, and precise vector exceptions out of this merge.

## Merge Notes

- Main touched RTL area: `vsrc/vector/cop/dummy_coprocessor.v` and existing CPU/COP/CSR wiring from the earlier phases.
- Main touched software area: `sw/tests/vector-tests/` focused RVV tests and helpers.
- Main touched docs area: `docs/vector/rvv-supported-subset.md`, `docs/vector/rvv-subset-freeze.md`, and `docs/vector/rvv-long-term-roadmap.md`.
- Final gate: `make rvv-final-acceptance EXTRA_VERILATOR_FLAGS='-j 1'`.
