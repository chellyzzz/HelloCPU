# RVV Work Summary

## Goal

This branch closes a benchmark-driven partial RVV integer subset for HelloCPU. The target is not full RVV compliance; it is a small, explicit subset that can run local integer vector kernels while keeping unsupported RVV behavior fail-closed or clearly deferred.

## Completed Scope

- Standard RVV-style configuration through `vsetvli` rs1 AVL path for `SEW=8/16/32` and `LMUL=m1`.
- Standard vector register fields for `v0` through `v31`, with no grouped register aliasing.
- CSR-readable mirrors for `vl`, `vtype`, and fixed-zero `vstart`.
- Integer execute subset covering add, sub, bitwise, shift, move, multiply, compare-to-mask, `vmerge`, and `vredsum.vs`.
- Execute-class masking through `v0`, with masked-off lanes preserved.
- Unmasked unit-stride `vle8/vse8`, `vle16/vse16`, and `vle32/vse32` through the existing COP memory owner boundary.
- Local benchmark harness under `sw/benchmark/rvv-subset-benchmark/` with `vec_add_i32`, `vec_xor_u8`, `memcpy_vec`, `dot_i32_tiny`, and `threshold_u8`.
- Benchmark functional paths use standard RVV load/compute/store instructions instead of `rvv_debug_*` helpers.
- Focused staged memory-contract test for static backing vector loads and vector stores to scalar-visible memory.
- One-command final gate through `make rvv-final-acceptance EXTRA_VERILATOR_FLAGS='-j 1'`.

## Acceptance

The final branch gate is:

```sh
make rvv-final-acceptance EXTRA_VERILATOR_FLAGS='-j 1'
```

This gate runs `git diff --check`, the fixed partial RVV smoke suite, backend contract checks, decode/slot1 checks, and the local RVV benchmark harness.

## Memory Contract

The accepted memory model is staged and intentionally narrow. RVV tests and benchmarks may load vector data from static initialized backing memory and may store vector results to scalar-visible destinations for scalar verification. They must not rely on scalar stores immediately feeding vector loads through coherent cache behavior.

True scalar cache and COP memory-bypass coherency is explicitly deferred to a later phase.

## Deferred Work

- Full RVV compliance.
- `LMUL>m1`, fractional LMUL, and grouped register aliasing.
- `SEW=64`.
- `vstart` restart and precise vector exceptions.
- Full illegal instruction trap integration for all unsupported RVV forms.
- Masked, strided, indexed, segmented, and fault-only-first vector memory.
- FP, widening/narrowing, saturating, divide/remainder, and additional reductions.
- True scalar cache and COP memory-bypass coherency.

## Merge Guidance

- Treat this as a bounded partial RVV merge, not as a claim of complete RVV support.
- Keep CPU/COP single-owner memory, kill, and commit-visible boundaries unchanged unless a later interface review explicitly updates them.
- New RVV features should update `rvv-subset-freeze.md` and `rvv-supported-subset.md` before RTL changes land.
- Run the final gate before merging or rebasing this branch onto a newer CPU baseline.
