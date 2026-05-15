# RVV 支持子集矩阵

## 一、文档目标

本文档记录 HelloCPU 计划支持和当前已经支持的 RVV 子集。它是后续 RVV RTL 开发的范围边界：没有列为 supported 的指令、配置或语义，不应静默执行成近似行为。

状态定义：

- `prototype`：当前仅通过 `custom-0` COP 原型覆盖，不是标准 RVV 支持。
- `specified`：状态契约已冻结，但还没有 RTL prototype。
- `planned`：计划在部分 RVV 子集中实现。
- `supported`：已通过标准 RVV 编码和 directed test 验证。
- `unsupported`：当前不实现，遇到时应走明确 illegal/unsupported 路径。
- `deferred`：长期可能支持，但不属于第一批 RVV 子集。

## 二、当前结论

当前 HelloCPU 声明支持一个冻结的 partial RVV integer subset，而不是完整 RVV。冻结声明见 `rvv-subset-freeze.md`；其他 RVV 能力仍属于 unsupported/deferred，不应静默执行成近似行为。

标准 OP-V `vsetivli` 进入 RTL 前的 interface review 草案见 `rvv-standard-decode-p2-review.md`。

第一批 RVV 已形成一个小而明确的整数子集；最终目标仍不是完整 RVV，而是支撑 `sw/benchmark/rvv-subset-benchmark/` 下的小型整数 benchmark：

- `vsetivli` 和 `vsetvli`。
- `VLEN` 固定小宽度。
- `SEW=8/16/32`。
- `LMUL=m1`。
- 基础整数 ALU。
- 最小整数乘法。
- 最小 compare mask、`vmerge` 和 `vredsum.vs`。
- unit-stride load/store。
- `vm=1` 全使能和 execute-class `vm=0` 基础 mask。

## 三、架构状态

| 项目 | 当前状态 | 第一批 RVV 目标 | 备注 |
|------|----------|-----------------|------|
| `vl` | supported | planned | 标准 `vsetvli` rs1 AVL path 和 custom prototype 均按当前 SEW 饱和；CSR `0xc20` 可读 mirror |
| `vtype` | supported | planned | 标准 `vsetvli` 支持 `SEW=8/16/32, LMUL=m1`，unsupported `vtypei` 置 `vill=1`；CSR `0xc21` 可读 mirror |
| `vstart` | supported | planned | CSR `0x008` 可读，固定为 0；不支持 restart |
| `vxrm` | unsupported | deferred | 饱和/舍入类指令前不需要 |
| `vxsat` | unsupported | deferred | 饱和类指令前不需要 |
| vector CSR trap semantics | unsupported | deferred | 需要 CPU interface review |

## 四、配置范围

| 配置 | 当前状态 | 第一批 RVV 目标 | 备注 |
|------|----------|-----------------|------|
| `VLEN` | supported | planned | 固定小宽度，当前每个 vector register 存 32-bit 数据 |
| `ELEN=8` | prototype | planned | 当前 COP lane/memory 可作为验证基础 |
| `ELEN=16` | supported | planned | benchmark target；当前用于 `vle16/vse16` 和 `vmul` lane |
| `ELEN=32` | prototype | planned | 当前 GPR/VRF 32-bit 原型可复用 |
| `ELEN=64` | unsupported | deferred | RV32 基线下暂不做 |
| `LMUL=m1` | supported | planned | 只支持 `m1`，标准寄存器字段可寻址 `v0-v31` |
| fractional LMUL | unsupported | unsupported | 第一批明确不支持 |
| `LMUL>m1` | unsupported | deferred | 需要 VRF banking/alias 设计 |

## 五、配置指令

| 指令 | 当前状态 | 第一批 RVV 目标 | 备注 |
|------|----------|-----------------|------|
| `vsetvli` | supported | planned | benchmark target；rs1 AVL path，受限 `SEW=8/16/32, LMUL=m1` 语义 |
| `vsetivli` | unsupported | planned | internal legacy names remain, but immediate AVL encoding is not separately implemented |
| `vsetvl` | unsupported | deferred | 可等 `vsetvli` 稳定后做 |

## 六、整数 ALU 指令

| 指令 | 当前状态 | 第一批 RVV 目标 | 备注 |
|------|----------|-----------------|------|
| `vadd.vv` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vadd.vx` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF + scalar GPR rs1 |
| `vadd.vi` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vsub.vv` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vsub.vx` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF + scalar GPR rs1 |
| `vand.vv` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vor.vv` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vxor.vv` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vand.vx` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF + scalar GPR rs1 |
| `vor.vx` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF + scalar GPR rs1 |
| `vxor.vx` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF + scalar GPR rs1 |
| `vand.vi` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vor.vi` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vxor.vi` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vsll.vv` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vsll.vx` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF + scalar GPR rs1 |
| `vsrl.vv` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vsrl.vx` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF + scalar GPR rs1 |
| `vsra.vv` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vsra.vx` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF + scalar GPR rs1 |
| `vmul.vv` | supported | planned | benchmark target；用于 tiny dot/matrix kernel |
| `vmul.vx` | supported | planned | benchmark target；用于 scalar coefficient kernels |
| divide/remainder | unsupported | unsupported | 第一批不支持 |
| `vredsum.vs` | supported | planned | benchmark target；唯一计划 reduction |
| compare/set mask | supported | planned | benchmark target；当前支持 `vmseq/vmsne/vmslt/vmsltu` 的 `vv/vx` 形式 |

## 七、Move 与 Merge

| 指令 | 当前状态 | 第一批 RVV 目标 | 备注 |
|------|----------|-----------------|------|
| `vmv.v.v` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF |
| `vmv.v.x` | supported | planned | 只支持 unmasked `vm=1`、`SEW=8/32`、`LMUL=m1`、COP-local VRF + scalar GPR rs1 |
| `vmv.v.i` | unsupported | deferred | immediate path 后置 |
| `vmerge.vvm` | supported | planned | benchmark target；用于 threshold/select kernels |
| `vmerge.vxm` | supported | planned | benchmark target；用于 threshold/select kernels |

## 八、Load/Store 指令

| 指令 | 当前状态 | 第一批 RVV 目标 | 备注 |
|------|----------|-----------------|------|
| `vle8.v` | supported | planned | 只支持 unit-stride、unmasked `vm=1`、`SEW=8`、`LMUL=m1`、COP-local VRF |
| `vse8.v` | supported | planned | 只支持 unit-stride、unmasked `vm=1`、`SEW=8`、`LMUL=m1`、COP-local VRF |
| `vle16.v` | supported | planned | benchmark target；unit-stride、unmasked、`SEW=16` |
| `vse16.v` | supported | planned | benchmark target；unit-stride、unmasked、`SEW=16` |
| `vle32.v` | supported | planned | 只支持 unit-stride、unmasked `vm=1`、`SEW=32`、`LMUL=m1`、COP-local VRF，byte-serial memory requests |
| `vse32.v` | supported | planned | 只支持 unit-stride、unmasked `vm=1`、`SEW=32`、`LMUL=m1`、COP-local VRF，byte-serial memory requests |
| strided load/store | unsupported | deferred | 不属于第一批 |
| indexed gather/scatter | unsupported | unsupported | 不属于近期目标 |
| fault-only-first load | unsupported | unsupported | 不属于近期目标 |

## 九、Mask 与 Tail Policy

| 项目 | 当前状态 | 第一批 RVV 目标 | 备注 |
|------|----------|-----------------|------|
| `vm=1` 全使能 | prototype | planned | 第一批默认路径 |
| `vm=0` masked execution | supported | planned | Phase 7 支持 execute-class，masked-off lanes 保持旧 `vd` |
| `v0` mask register | supported | planned | 当前使用 COP-local `v0` 作为 execute-class mask source |
| mask load/store skip | unsupported | deferred | 必须保证 inactive address 不访问 |
| tail agnostic | unsupported | planned | 可固定一种 policy，但必须文档化 |
| tail undisturbed | unsupported | deferred | 需要读改写或保持旧值 |
| mask agnostic/undisturbed | supported | planned | 当前 masked-off lanes 采用 undisturbed 策略 |

## 十、异常与 Illegal 行为

| 项目 | 当前状态 | 第一批 RVV 目标 | 备注 |
|------|----------|-----------------|------|
| unsupported RVV opcode | unsupported | planned | 当前 fail closed，不进入 COP execute path |
| illegal `vtype` | supported | planned | 标准 `vsetivli` 和 custom prototype 均置 `vill=1` |
| misaligned vector memory | unsupported | unsupported | 第一批可要求测试使用支持的地址 |
| vector memory fault | unsupported | deferred | 需要 CPU exception/tval review |
| precise vector exception | unsupported | deferred | 需要 `vstart` 语义 |

Phase 3 阶段性边界：`vl/vtype` 继续 COP-local，`vstart` 固定等价为 0，unsupported OP-V fail closed 且不新增 trap-visible side effect。标准 vector memory 进入前必须沿用 CPU-owned memory service/owner/kill 语义。

## 十一、验证矩阵

| 测试类别 | 当前覆盖 | 第一批 RVV 目标 |
|----------|----------|-----------------|
| custom COP scalar/lane | supported by prototype tests | 保留回归 |
| custom COP VRF | supported by prototype tests | 保留回归 |
| custom COP memory | supported by prototype tests | 保留回归 |
| pending-kill load | supported by directed test | RVV memory path 也需要覆盖 |
| RVV decode illegal | unsupported | planned |
| custom COP `vtype` prototype | supported by prototype tests | 保留到标准 `vset*` path 稳定 |
| custom COP state consumer | supported by prototype tests | `vstate_add` 覆盖 `vl/vtype/vill` gating |
| custom COP `vsetivli_p` | supported by prototype tests | 标准 `vsetivli` 前的低风险 prototype |
| RVV `vsetivli` | supported by focused tests | 当前只支持最小 OP-V `vsetivli` |
| other RVV `vset*` | unsupported | planned |
| RVV `vadd.vv` directed | supported by focused tests | 当前只支持 unmasked `vadd.vv` |
| RVV `vadd.vx` directed | supported by focused tests | 当前只支持 unmasked `vadd.vx` |
| RVV bitwise VV directed | supported by focused tests | 当前支持 unmasked `vand.vv/vor.vv/vxor.vv` |
| RVV Phase 1 ALU/move | supported by focused tests | `vadd.vi`、bitwise VX、`vmv.v.v/vmv.v.x` |
| RVV Phase 4 memory | supported by focused tests | `vle8.v/vse8.v` unit-stride through CPU memory owner boundary |
| RVV Phase 5 execute | supported by focused tests | `vsub.vv/vx`、`vsll/vsrl/vsra.vv/vx`、bitwise VI |
| RVV Phase 6 memory | supported by focused tests | `vle32.v/vse32.v` unit-stride byte-serial memory requests |
| RVV Phase 7 mask | supported by focused tests | execute-class `vm=0`，`v0` mask，masked-off lane undisturbed |
| RVV Phase 8 CSR mirror | supported by focused tests | `vl/vtype/vstart` CSR-visible readback；illegal trap deferred |
| RVV Phase 9/11 acceptance | supported by focused tests | `v0-v31` register addressing and frozen subset smoke |
| RVV Phase 13 compare/merge | supported by focused tests | `vmseq/vmsne/vmslt/vmsltu` 和 `vmerge.vvm/vxm` |
| RVV Phase 14 reduction | supported by focused tests | `vredsum.vs` |
| other RVV ALU directed | unsupported | planned |
| RVV load/store directed | unsupported | planned |
| RVV load/compute/store program | unsupported | planned |
| RVV benchmark smoke | supported | planned | 当前 `vec_add_i32`、`vec_xor_u8`、`memcpy_vec`、`dot_i32_tiny`、`threshold_u8` |

标准 RVV directed tests 应优先使用标准 `vsetivli` 和 `vmv.v.x` 做配置/初始化。`custom-0` VRF read/write 只作为 legacy/debug harness，用于结果读回、unsupported state guard 和尚无标准 init path 的旧测试。

## 十二、第一批支持声明草案

第一批 RVV 支持完成后，支持声明应接近以下范围：

- RV32 base CPU with partial RVV integer subset。
- `VLEN` 固定小宽度。
- 标准 RVV register fields 可寻址 `v0-v31`，但 `LMUL` 只支持 `m1`。
- `SEW=8/16/32`。
- `LMUL=m1`。
- `vsetvli` 最小 slice。
- `vadd.vv`、`vadd.vx`、`vadd.vi`、`vsub.vv/vx`、`vand/vor/vxor.vv/vx/vi`、`vsll/vsrl/vsra.vv/vx`、`vmv.v.v`、`vmv.v.x`。
- `vmseq/vmsne/vmslt/vmsltu` 的 `vv/vx` 形式。
- `vmerge.vvm` 和 `vmerge.vxm`。
- `vredsum.vs`。
- `vle8.v`/`vse8.v`、`vle16.v`/`vse16.v` 和 `vle32.v`/`vse32.v` unit-stride memory slice。
- execute-class `vm=0` masked execution，mask bits 来自 COP-local `v0`，masked-off lanes 保持旧 `vd`。
- CSR-readable `vl`/`vtype`/`vstart` mirror，更新点为 COP commit-visible fire；`vstart` 固定为 0。
- `vm=1` 全使能。
- unsupported 指令和配置不执行近似语义。
- 标准测试短期只把 custom VRF read/write 当 legacy/debug harness；新测试优先用标准 move 初始化，直到标准 load/store 或更完整 VRF observable path 可用。

任何超出以上范围的 RVV 功能，在 RTL 合入前都应先更新本文档。

## 十三、Benchmark 驱动最终子集

最终 partial RVV 子集以小型整数 benchmark 为验收目标，不以完整 RVV compliance 为目标。

目标 benchmark：

- `vec_add_i32`：覆盖 `vle32.v`、`vadd.vv/vx/vi`、`vse32.v`。
- `vec_xor_u8`：覆盖 `vle8.v`、`vxor.vv/vx/vi`、`vse8.v`。
- `memcpy_vec`：覆盖 unit-stride byte load/store 和 `vl` loop。
- `dot_i32_tiny`：覆盖 `vle32.v`、`vmul.vv/vx`、`vadd` 或 `vredsum.vs`。
- `threshold_u8`：覆盖 `vle8.v`、compare mask、`vmerge`、`vse8.v`。

对应最终 ISA 范围：

- 配置：`vsetvli`，仅 `SEW=8/16/32`、`LMUL=m1`；`vsetivli` 仍 planned。
- 寄存器：`v0-v31`，不支持 `LMUL>m1` 或 fractional LMUL alias。
- Memory：unmasked unit-stride `vle8/vse8/vle16/vse16/vle32/vse32`。
- Execute：当前 add/sub/bitwise/shift/move，加 `vmul.vv/vx`。
- Mask：execute mask、`vmseq/vmsne/vmslt/vmsltu`、`vmerge`。
- Reduction：`vredsum.vs`。
- Contract：benchmark 成为架构测试前，必须先明确 scalar cache 与 COP memory bypass coherency。
