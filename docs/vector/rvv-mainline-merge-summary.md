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
- Execute: `vadd`, `vsub`, `vand`, `vor`, `vxor`, `vsll`, `vsrl`, `vsra`, `vmv.v.v`, and `vmv.v.x` for the supported forms.
- Mask: execute-class `vm=0` using `v0`; masked-off lanes are undisturbed.
- Memory: unmasked unit-stride `vle8.v`, `vse8.v`, `vle32.v`, and `vse32.v` through the existing COP memory owner boundary.

## Key Boundaries

- `SEW=8/32` are supported today; `SEW=16` is planned for benchmark coverage.
- `LMUL>m1`, fractional LMUL, grouped register aliasing, `vstart` restart, precise vector exceptions, and full illegal trap integration remain out of scope.
- Masked memory, strided/indexed/segment/fault-only-first memory, FP, widening/narrowing, saturating, divide/remainder, and full RVV compliance remain out of scope.
- Scalar cache and COP memory-bypass coherency must be documented before RVV benchmarks become architectural acceptance tests.

## Validation

- Focused RVV tests cover `vsetivli`, ALU, bitwise, move, shift, mask, CSR mirror, vector memory, unsupported OP-V, and subset acceptance.
- Directed owner/kill tests cover scalar pending memory kill, COP pending memory kill, COP store owner path, and pre-accept killed COP store behavior.
- `make rvv-subset-smoke EXTRA_VERILATOR_FLAGS='-j 1'` is the fixed partial RVV smoke entry.
- `make rvv-bench-run EXTRA_VERILATOR_FLAGS='-j 1'` runs the initial RVV benchmark harness.
- `git diff --check` is clean for the branch changes.

## Next Development Plan

- Extend `sw/benchmark/rvv-subset-benchmark/` beyond the initial `vec_add_i32`, `vec_xor_u8`, and `memcpy_vec` smoke kernels.
- Freeze a one-command RVV smoke target covering focused tests, acceptance, benchmarks, and memory owner/kill tests.
- Next remaining subset work: compare mask, `vmerge`, and `vredsum.vs`.
- Add benchmark-driven execute extensions: `vmul.vv/vx`, compare mask, `vmerge`, and `vredsum.vs`.
- Document and test scalar/vector memory coherency before treating benchmarks as architectural tests.

## Merge Notes

- Main touched RTL area: `vsrc/vector/cop/dummy_coprocessor.v` and existing CPU/COP/CSR wiring from the earlier phases.
- Main touched software area: `sw/tests/vector-tests/` focused RVV tests and helpers.
- Main touched docs area: `docs/vector/rvv-supported-subset.md`, `docs/vector/rvv-subset-freeze.md`, and `docs/vector/rvv-long-term-roadmap.md`.
