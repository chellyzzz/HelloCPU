# P2 标准 RVV Decode Interface Review 草案

## 一、目标

本文档定义 C-line 从 custom-0 COP prototype 进入第一条标准 RVV decode 前需要 D-line review 的边界。

当前已验证的基础是：

- `vl/vtype` prototype state。
- `vstate_add` state consumer。
- custom `vsetivli_p` vset-like prototype。
- killed/flush pending state write 不提交。

本轮自审批准并落地标准 OP-V `vsetivli` 最小 slice，不同时引入完整 `vsetvli`、`vsetvl`、vector ALU 或 vector memory 标准路径。

## 二、当前非目标

- 不声明标准 RVV supported。
- 不引入 vector CSR 可见路径。
- 不修改 exception/trap writeback 语义。
- 不扩展 COP/vector memory owner model。
- 不支持 `vstart != 0`、`vm=0`、fractional LMUL 或 `LMUL>m1`。

## 三、建议的第一条标准入口

第一条标准入口只做 `vsetivli` decode slice。

建议范围：

- 只识别 OP-V `vsetivli` 编码。
- `AVL` 来自 `rs1` GPR path。
- `vtypei` 只接受 prototype 支持范围：`SEW=8/32`、`LMUL=m1`。
- `vl` 按 `VLMAX=4` 饱和。
- unsupported `vtypei` 设置 `vill=1`。
- 返回新 `vl` 到 `rd`。
- other OP-V encodings fail closed，不进入 COP execute path。

建议继续沿用单发射、最多一个 COP 请求在飞、CPU/WBU 统一提交的 V1 contract。

## 四、必须冻结的共享语义

### 4.1 Decode ownership

需要 D-line 明确：

- OP-V `vsetivli` 由 IDU 直接分类为 COP/vector 指令，还是先由 CPU decode 标记为 RVV-class 再交给 COP backend。
- unsupported OP-V 是否进入 COP backend，还是在 CPU decode 阶段直接走 illegal/unsupported。
- custom-0 prototype 与 OP-V 标准路径是否共享同一 backend request interface。

### 4.2 Illegal/unsupported 行为

需要 D-line 明确：

- 当前无完整 trap path 时，unsupported RVV opcode 的阶段性行为是什么。
- illegal `vtypei` 是设置 `vill=1` 并完成，还是触发 illegal instruction。
- `vm=0`、unsupported SEW/LMUL、`vstart != 0` future CSR 写入是否必须 fail closed。

已采用策略：

- `vsetivli` with unsupported `vtypei`：设置 `vill=1` 并返回饱和 `vl`，与当前 prototype 保持一致。
- unsupported RVV execute-class opcode：不进入 COP，不映射到 custom lane op。

### 4.3 State visibility

需要 D-line 明确：

- `vl/vtype` 在第一条标准路径中是否仍为 COP-local state。
- CPU 是否需要读取 `vl/vtype` 以处理 CSR、trap 或 debug。
- `vl/vtype` 写入在哪个事件变为 architectural visible：COP done、WBU commit，还是已有 commit-visible control gate。

已采用策略：

- P2 标准 `vsetivli` 仍复用 COP-local state storage。
- 写入延迟到当前 COP completion/commit-visible 风格边界。
- flush/kill 取消 pending `vl/vtype` 写入。

### 4.4 Response and commit

标准 `vsetivli` 返回新 `vl` 到 `rd`，因此必须保持：

- killed work 不产生 GPR writeback。
- killed work 不提交 `vl/vtype` state。
- response visible 与 state visible 不可提前到 accept。
- backend busy/response contract 不允许多条 COP/RVV 指令重叠。

## 五、建议验证门槛

第一条标准 `vsetivli` decode 进入 mainline 前，至少需要：

| 测试 | 覆盖点 |
|------|--------|
| `rvv-vsetivli-basic` | supported `SEW=8/32, LMUL=m1` 配置和 `rd=vl` |
| `rvv-vsetivli-illegal` | unsupported `vtypei` 设置 `vill=1` |
| `rvv-unsupported-opv` | 未支持 OP-V fail closed，不进入 COP execute path |

回归要求：

- custom `cop-vsetivli-proto` 继续通过。
- `cop-vstate-add*` 继续通过。
- P0 COP memory directed tests 继续通过。
- scalar `scalar_mem_pending_kill` 继续通过。

## 六、推荐落地顺序

1. C-line 自审批准最小 OP-V `vsetivli` decode classifier，不接 vector ALU。
2. 标准 `vsetivli` path 复用当前 `vsetivli_p` 的 state update helper/语义。
3. 新增标准 directed tests 和 unsupported fail-closed tests。
4. 通过 focused + P0 smoke 后，再讨论 `vadd.vv` 标准 execute path。

## 七、当前结论

C-line 当前分支已经证明 state model、consumer、custom vset-like prototype、标准 OP-V `vsetivli`、unmasked add/bitwise/move 最小 execute slice 可工作。下一步风险转移到更广的标准 execute-class OP-V、masked ops、illegal/trap、CSR 可见性和标准 vector memory 边界。

## 八、`vadd.vv` 自审决策

`vadd.vv` 最小 slice 采用以下边界：

- 只识别 OP-V `vadd.vv`，`funct6=0`、`funct3=000`、`vm=1`。
- `vd/vs1/vs2` 使用标准字段，但当前只映射到 COP-local 4-entry VRF 的低两位。
- `SEW=8` 按 byte lanes 加法，`SEW=32` 按 32-bit lane 加法。
- `vl=0` 写入 0；`vl<VLMAX` 时 inactive byte lanes 写 0。
- `vill=1` 时不写 VRF，并返回 `0x80000000` 到 COP response。
- `vadd.vv` 不写 scalar GPR；`rd` 字段仅作为 vector `vd`。
- 不支持 masked `vm=0`、`vstart!=0`、`LMUL!=m1` 或超过当前 VRF prototype 的 register file 行为。

## 十一、Phase 1 ALU/move 自审决策

Phase 1 在已支持的 `vadd.vv/vx` 和 bitwise VV 上补齐以下最小标准路径：

- `vadd.vi`：`funct6=0`、`funct3=011`、`vm=1`，immediate 来自 `imm[4:0]`。
- `vand.vx/vor.vx/vxor.vx`：复用 scalar GPR `rs1` path。
- `vmv.v.v/vmv.v.x`：作为基础 move/broadcast，用于后续减少 custom VRF init 依赖。
- 所有 Phase 1 op 均不写 scalar GPR，`vd` 仅作为 vector destination。
- `vd/vs1/vs2` 标准字段当前仍映射到 COP-local 4-entry VRF 的低两位。
- `SEW=8/32`、`LMUL=m1`、`vstart=0`、`vm=1` 是唯一支持组合。
- `vill=1` 时不写 VRF；unsupported OP-V 继续 fail closed。

## 十二、Phase 2 测试与 custom prototype 收敛

Phase 2 不扩大 RTL scope，只收敛测试和文档边界：

- 新增 shared RVV test helper，把标准 helper 和 custom debug helper 分开命名。
- Phase 1 directed tests 使用标准 `vmv.v.x` 初始化 `v0/v2`，不再用 custom write 作为默认 setup path。
- custom VRF read/write 保留为 legacy/debug harness：用于结果读回、`vill` 不写回验证，以及尚未迁移的旧 directed tests。
- custom memory prototype 仍只用于现有 memory owner/kill coverage，不声明为 standard vector memory。
- 后续新增标准 RVV tests 需要先尝试标准 `vsetivli` + move init；只有不可观测或不可初始化时才使用 `rvv_debug_*` helper。

## 十、bitwise VV 自审决策

`vand.vv`、`vor.vv`、`vxor.vv` 作为一个稳定 execute-class 点一起落地：

- 只识别 OP-V `vand.vv/vor.vv/vxor.vv`，`funct3=000`、`vm=1`。
- `vd/vs1/vs2` 使用标准字段，但当前只映射到 COP-local 4-entry VRF 的低两位。
- `SEW=8` 按 byte lanes 应用 `vl` gating，`SEW=32` 按 32-bit lane 执行。
- `vl=0` 写入 0；`vl<VLMAX` 时 inactive byte lanes 写 0。
- `vill=1` 时不写 VRF，并返回 `0x80000000` 到 COP response。
- bitwise VV 不写 scalar GPR；`rd` 字段仅作为 vector `vd`。
- 不支持 masked `vm=0`、`vstart!=0`、`LMUL!=m1` 或超过当前 VRF prototype 的 register file 行为。

## 九、`vadd.vx` 自审决策

`vadd.vx` 最小 slice 采用以下边界：

- 只识别 OP-V `vadd.vx`，`funct6=0`、`funct3=100`、`vm=1`。
- `vd/vs2` 使用标准字段，但当前只映射到 COP-local 4-entry VRF 的低两位。
- `rs1` 来自 scalar GPR；`vadd.vx` 不写 scalar GPR，`rd` 字段仅作为 vector `vd`。
- `SEW=8` 使用 scalar `rs1[7:0]` 广播到 byte lanes，`SEW=32` 使用完整 `rs1`。
- `vl=0` 写入 0；`vl<VLMAX` 时 inactive byte lanes 写 0。
- `vill=1` 时不写 VRF，并返回 `0x80000000` 到 COP response。
- 不支持 masked `vm=0`、`vstart!=0`、`LMUL!=m1` 或超过当前 VRF prototype 的 register file 行为。
