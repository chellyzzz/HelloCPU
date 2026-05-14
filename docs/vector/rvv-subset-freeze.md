# HelloCPU Partial RVV Subset Freeze

This document freezes the current partial RVV target. The goal is not full RVV compliance; unsupported features must not silently execute as approximate behavior.

## Supported State

- `vsetivli` with `SEW=8` or `SEW=32`, `LMUL=m1`.
- `vl` saturates at the prototype `VLMAX=4`.
- `vtype` sets `vill=1` for unsupported `vtypei`.
- `vl`, `vtype`, and `vstart` are readable through CSR mirrors `0xc20`, `0xc21`, and `0x008`.
- `vstart` is fixed at 0; restart is not supported.

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
- `vsetvli`, `vsetvl`.
- `LMUL` other than `m1`, fractional LMUL, and grouped register aliasing.
- `SEW=16`, `SEW=64`.
- `vstart` restart.
- Strided, indexed, fault-only-first, and masked memory operations.
- Compare/set-mask and mask load/store instructions.
- Precise vector exceptions and full illegal instruction trap integration.
- Scalar cache and COP memory-bypass coherency.

## Validation Contract

The subset is considered stable when focused execute, mask, CSR, memory, acceptance, and memory owner/kill tests pass together, plus `git diff --check`.
