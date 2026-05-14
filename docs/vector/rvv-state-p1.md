# P1A 最小 RVV 状态契约

## 一、目标

P1A 冻结 HelloCPU 第一版 RVV 状态模型的边界。这个阶段只定义状态、限制、unsupported 行为和验证要求，不引入标准 RVV decode，不声明支持 RVV。

P1A 的直接目标：

- 把现有 custom COP `vlen` 原型状态收敛为未来 `vl` 的验证平台。
- 定义最小 `vtype` 语义，先支持固定小范围配置。
- 明确 `vstart`、mask/tail policy、非法配置和 unsupported 指令的阶段性行为。
- 给 P1B RTL 留出可验证、低风险、COP-local 的实现切片。

非目标：

- 不实现标准 `vsetvli`、`vsetivli` 或 `vsetvl` decode。
- 不修改 CPU decode、trap、CSR 或 exception path。
- 不扩大 COP memory side effect 语义。
- 不声明标准 RVV supported。

## 二、当前前提

当前主线 checkpoint 已显式化 backend contract：

- accept、done、commit-visible 是不同阶段。
- COP result 仍通过 CPU/WBU 统一提交。
- killed COP work 不得产生 GPR、VRF 或 memory 错误 side effect。
- COP memory owner path 已有 pending-kill、store owner 和 pre-accept store-kill directed coverage。

P1A/P1B 必须沿用这个 contract。任何新状态写入都必须满足：接受请求不等于状态可见，functional done 不等于架构提交，kill/flush 必须取消未提交状态。

## 三、最小状态集合

### 3.1 `vl`

第一版 `vl` 是软件可见的向量长度配置状态，但在 P1B 中仍通过 custom COP 原型路径验证。

建议约束：

- 宽度：32-bit storage。
- 有效范围：`0 <= vl <= VLMAX`。
- `VLMAX` 第一版固定为 4 elements。
- 写入值大于 `VLMAX` 时饱和到 `VLMAX`。
- `vl=0` 合法，用于验证 no-element 执行路径。
- reset 后 `vl=0`。
- kill/flush 取消未完成的 `vl` 写入。

当前 custom COP `funct3=5/6` 的 `vlen write/read` 可作为 P1B 的验证入口。P1B 可以先把文档名义上的 `vl` 映射到当前 `vlen` storage，但不应继续扩展旧 `vlen` 语义。

### 3.2 `vtype`

第一版 `vtype` 只记录未来 RVV 子集需要的最小配置，不追求完整 bit-compatible RVV CSR。

建议字段：

| 字段 | P1A 固定范围 | 说明 |
|------|--------------|------|
| `vill` | 0/1 | 非法配置 sticky 标记 |
| `sew` | 8 或 32 | 第一批只允许 `SEW=8`、`SEW=32` |
| `lmul` | m1 | 第一批只允许 `LMUL=m1` |
| `vta` | agnostic | 第一批固定 tail agnostic |
| `vma` | agnostic | 第一批固定 mask agnostic，mask 本身 deferred |

非法配置规则：

- 不支持的 `SEW` 置 `vill=1`。
- 不支持的 `LMUL` 置 `vill=1`。
- `vill=1` 时后续 RVV 执行类操作必须走 unsupported/illegal 路径，不能执行近似语义。
- reset 后 `vtype.vill=1`，直到软件显式配置一个受支持的 `vtype`。

P1B 可以先用 custom COP 子操作写入/读取 P1 prototype `vtype`，不需要实现标准 CSR 编码。

### 3.3 `vstart`

第一批不支持 precise vector restart。

约束：

- storage 可暂不实现，语义固定为 0。
- 任何试图写非 0 `vstart` 的未来标准路径应 unsupported。
- 所有 directed tests 默认从 element 0 开始。

## 四、执行 policy

### 4.1 Element 范围

所有未来 P1/P2 vector prototype 操作只处理 `0 <= element_index < vl`。

当 `vl=0`：

- ALU 类操作不更新任何 element。
- load/store 类操作不应发起 element memory request。
- 指令仍可完成，但不产生 element side effect。

### 4.2 Tail policy

第一版固定 tail agnostic。

含义：

- `element_index >= vl` 的结果不保证保持旧值。
- directed tests 不检查 tail element 的具体值。
- 后续若改成 tail undisturbed，必须先更新本文档和 subset matrix。

### 4.3 Mask policy

第一版只支持 `vm=1` 全使能。

约束：

- `vm=0` masked execution deferred。
- `v0` mask register 语义 deferred。
- masked load/store skip 语义 deferred。
- 如果标准 decode 阶段遇到 `vm=0`，应明确 unsupported，不应当成全使能执行。

## 五、P1B RTL 切片建议

P1B 应保持 COP-local，不碰 CPU shared boundary。

建议最小 RTL 切片：

1. 在 `dummy_coprocessor.v` 中新增 prototype `vtype` storage。
2. 保留现有 `vlen` storage 作为 `vl` prototype，或重命名前先只在文档中映射。
3. 新增 custom COP state 子操作，用于写/读 prototype `vtype`。
4. 对非法 `vtype` 设置 `vill=1`，并通过 readback 验证。
5. 保持所有写入延迟到 completion，与现有 scratch/vlen 语义一致。
6. kill/flush 必须取消 pending `vl/vtype` 写入。

建议 custom encoding 暂定：

| funct3 | funct7 | 操作 | 说明 |
|--------|--------|------|------|
| 0 | 16 | `vtype_write` | 写入 P1 prototype `vtype`，返回旧值 |
| 0 | 17 | `vtype_read` | 读取 P1 prototype `vtype` |

这两个编码仍属于 custom COP prototype，不是标准 RVV。

## 六、验证要求

P1B RTL 合入前至少需要以下 directed software tests：

| 测试 | 覆盖点 |
|------|--------|
| `cop-vtype` | supported `vtype` 写入/读回 |
| `cop-vtype-illegal` | unsupported `SEW/LMUL` 置 `vill=1` |
| `cop-vtype-cross` | `vl` 与 `vtype` 状态互不污染 |
| `cop_vtype_kill` | backend flush 取消 pending `vtype` 写入，后续 `vtype` 写入恢复 |

回归要求：

- P0 scalar smoke 不回退。
- COP lane/state/VRF 不回退。
- COP memory smoke 和 directed coverage 不回退。

## 七、P1C/P2 prototype extension

P1C 在不修改 CPU shared boundary 的前提下，新增 custom COP `vstate_add` 作为第一条 `vl/vtype` consumer：

| funct3 | funct7 | 操作 | 说明 |
|--------|--------|------|------|
| 0 | 18 | `vstate_add` | 按 prototype `vl/vtype` 执行加法，`vill=1` 返回 unsupported sentinel |

P2 的第一步仍保持 COP-local，新增 custom COP `vsetivli_p` 作为标准 `vsetivli` 前的低风险状态配置原型：

| funct3 | funct7 | 操作 | 说明 |
|--------|--------|------|------|
| 0 | 19 | `vsetivli_p` | `rs1=AVL`、`rs2=prototype vtype immediate`，同时写入 `vl/vtype`，返回新 `vl` |

这两个编码仍属于 custom COP prototype。标准 OP-V decode、trap/illegal path、CSR 可见状态都留给后续 CPU interface review。

## 八、进入标准 RVV decode 的条件

只有满足以下条件，才进入标准 RVV decode 或 `vset*` path：

- `vl` prototype 行为稳定，并有 kill/flush coverage。
- `vtype` prototype 行为稳定，并有 illegal config coverage。
- subset matrix 已把 `vl/vtype` 从 `planned` 更新为 `prototype`。
- custom `vstate_add` 已证明 `vl/vtype/vill` gating 可用。
- custom `vsetivli_p` 已证明 AVL 饱和和 `vtype` 配置路径可用。
- 标准 RVV unsupported 行为已有设计文档，避免 silent wrong execution。
- CPU decode/trap/CSR interface review 完成。

标准 decode review 草案见 `rvv-standard-decode-p2-review.md`。

## 九、当前结论

P1A/P1B/P1C/P2 prototype 的策略是：先把状态语义、state consumer 和 vset-like 配置路径做稳，再接标准编码。当前仍不改 CPU decode，不扩大 memory side effects，不声明标准 RVV supported。
