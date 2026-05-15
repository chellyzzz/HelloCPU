# HelloCPU Partial RVV Subset Freeze

This document freezes the current partial RVV target. The goal is not full RVV compliance; unsupported features must not silently execute as approximate behavior.

## Final Target Scope

The final HelloCPU RVV target is benchmark-driven, not compliance-driven. It should support small integer vector kernels under `sw/benchmark/rvv-subset-benchmark/`, while avoiding full RVV features that do not help those kernels. The existing `sw/benchmark/rvv-benchmark/` path is an external benchmark submodule and is not used for local subset smoke sources.

- Configuration: `vsetvli`-style rs1 AVL path with `SEW=8/16/32`, `LMUL=m1` only. Some legacy internal names still say `vsetivli`, but the exercised helper/API now exposes `rvv_vsetvli_*`.
- Registers: standard `v0` through `v31`, no grouped register aliasing.
- Memory: unmasked unit-stride `vle8/vse8`, `vle16/vse16`, and `vle32/vse32`.
- Execute: current add/sub/bitwise/shift/move subset plus `vmul.vv` and `vmul.vx`.
- Mask: execute mask through `v0`, compare-to-mask, and `vmerge` for threshold/select kernels.
- Reduction: `vredsum.vs` only, for sum/checksum/dot-product tails.
- Coherency: scalar initialization, vector memory, and scalar result checking must have a documented memory contract before RVV benchmarks are considered architectural tests.

## Supported State

- `vsetvli` with `SEW=8/16/32`, `LMUL=m1`.
- `vl` saturates at the prototype `VLMAX=4`.
- `vtype` sets `vill=1` for unsupported `vtypei`.
- `vl`, `vtype`, and `vstart` are readable through CSR mirrors `0xc20`, `0xc21`, and `0x008`.
- `vstart` is fixed at 0; restart is not supported.

## Planned Target Additions

- Internal signal naming cleanup from legacy `vsetivli` labels to `vsetvli` labels.
- Compare mask operations: `vmseq`, `vmsne`, `vmslt`, and `vmsltu` in the forms needed by benchmark kernels.
- `vmerge` for masked select/threshold kernels.
- `vredsum.vs` as the only planned reduction.

These are target additions, not currently supported behavior.

## Supported Registers

- Standard RVV register fields address `v0` through `v31`.
- `LMUL=m1` only; no grouped register aliasing is supported.
- Current physical storage is one 32-bit word per vector register.
- Custom `rvv_debug_*` helpers are legacy/debug harness only.

## Supported Execute Instructions

- `vadd.vv`, `vadd.vx`, `vadd.vi`.
- `vsub.vv`, `vsub.vx`.
- `vand.vv`, `vand.vx`, `vand.vi`.
- `vor.vv`, `vor.vx`, `vor.vi`.
- `vxor.vv`, `vxor.vx`, `vxor.vi`.
- `vsll.vv`, `vsll.vx`.
- `vsrl.vv`, `vsrl.vx`.
- `vsra.vv`, `vsra.vx`.
- `vmv.v.v`, `vmv.v.x`.

## Supported Mask Behavior

- Execute-class `vm=0` is supported using `v0` as the mask source.
- Masked-off lanes are undisturbed and preserve the old `vd` lane.
- `SEW=8` uses mask bits `[3:0]`; `SEW=32` uses mask bit 0.
- Masked vector memory is not supported.

## Supported Memory Instructions

- `vle8.v`, `vse8.v` unit-stride, unmasked.
- `vle32.v`, `vse32.v` unit-stride, unmasked.
- `vle32.v` and `vse32.v` use byte-serial memory requests to reuse the current COP memory owner/strobe boundary.
- `vl=0` loads write zero; `vl=0` stores issue no memory request.

## Unsupported And Deferred

- Full RVV compliance.
- `vsetvl`.
- `LMUL` other than `m1`, fractional LMUL, and grouped register aliasing.
- `SEW=64`.
- `vstart` restart.
- Strided, indexed, fault-only-first, and masked memory operations.
- Mask load/store instructions.
- Reductions other than `vredsum.vs`.
- Precise vector exceptions and full illegal instruction trap integration.
- Scalar cache and COP memory-bypass coherency.

## Benchmark Acceptance Targets

The target subset should be sufficient for these small benchmarks:

- `vec_add_i32`: `vle32`, `vadd`, `vse32`.
- `vec_xor_u8`: `vle8`, `vxor`, `vse8`.
- `memcpy_vec`: `vle8`, `vse8`.
- `dot_i32_tiny`: `vle32`, `vmul`, scalar final check.
- `threshold_u8`: `vle8`, compare mask, `vmerge`, `vse8`.

The initial benchmark harness implements `vec_add_i32`, `vec_xor_u8`, `memcpy_vec`, and `dot_i32_tiny` using the current supported subset. These tests use static initialized backing memory and may use `rvv_debug_*` only as harness assistance; this is not the final architectural benchmark path. Scalar/vector coherency remains a separate contract item before benchmarks become final acceptance tests.

## Scalar/Vector Memory Contract

Until scalar cache and COP memory-bypass coherency is explicitly implemented, architectural RVV tests and benchmarks must use static initialized backing memory for vector loads and scalar-visible destinations for vector stores. They must not depend on a scalar store immediately feeding a vector load through coherent cache behavior. This keeps the current memory owner/kill contract testable while making the coherency gap explicit.

## Smoke Entry

Use `make rvv-subset-smoke EXTRA_VERILATOR_FLAGS='-j 1'` as the fixed partial RVV regression entry. It covers focused RVV tests, subset acceptance, backend contract checks, decode pair policy, top slot1 observability, and COP/scalar memory owner/kill checks.

## Validation Contract

The subset is considered stable when focused execute, mask, CSR, memory, acceptance, and memory owner/kill tests pass together, plus `git diff --check`.
