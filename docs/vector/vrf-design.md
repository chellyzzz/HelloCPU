# VRF（向量寄存器文件）设计草案

## 一、目标

在现有 COP 框架上引入最小向量寄存器文件（VRF），为真实向量运算打下基础。

约束：
- 不引入独立向量访存
- 不修改 CPU 侧 GPR/CSR/PC/内存
- 保持单发射、最多一个 COP 请求在飞
- flush 语义与现有 COP 一致

---

## 二、VRF 架构

### 2.1 寄存器规格

| 参数 | 值 | 说明 |
|------|-----|------|
| 寄存器数量 | 4 | v0-v3 |
| 每寄存器元素数 | 4 | 4x8-bit lane |
| 每元素宽度 | 8-bit | 与现有 lane ops 对齐 |
| 总宽度 | 32-bit | 4 元素打包为 1 个 32-bit 字 |

设计理由：
- 4 寄存器足够覆盖基本向量运算（源 2 个 + 目的 1 个 + 临时 1 个）
- 4x8-bit lane 与现有 vadd8/vxor8/vand8 一致
- 32-bit 打包与 GPR 宽度一致，简化 load/store

### 2.2 寄存器用途约定

| 寄存器 | 建议用途 |
|--------|----------|
| v0 | 向量累加器 / 目的操作数 |
| v1 | 向量源操作数 |
| v2 | 向量临时寄存器 |
| v3 | 向量掩码 / 配置 |

---

## 三、编码方案

### 3.1 编码策略

由于 funct3 已用完（0-7），VRF 操作复用 funct3=0 的 funct7 扩展空间。

当前 funct3=0 的 funct7 使用情况：
- funct7=0: scalar add
- funct7=1: scalar sub
- funct7=2: scalar mul
- funct7=3-127: **可用**

### 3.2 VRF 操作编码

| funct3 | funct7 | 操作 | 语义 |
|--------|--------|------|------|
| 0 | 3 | vload | v[rd_field] = rs1（加载 GPR 到 VRF） |
| 0 | 4 | vstore | rd = v[rs1_field]（存储 VRF 到 GPR） |
| 0 | 5 | vadd8 | v0 = v0 + v1（4x8-bit lane add） |
| 0 | 6 | vxor8 | v0 = v0 ^ v1 |
| 0 | 7 | vand8 | v0 = v0 & v1 |
| 0 | 8 | vsub8 | v0 = v0 - v1（4x8-bit lane sub） |

字段复用说明：
- `vload`/`vstore`：使用 `rd`/`rs1` 的低 2 位选择 VRF 寄存器（v0-v3）
- `vadd8/vxor8/vand8/vsub8`：固定操作 v0 和 v1，结果写回 v0

### 3.3 编码示例

```asm
# 加载 GPR a0 到 v0
.insn r 0x0b, 0, 3, x0, a0, x0    # funct3=0, funct7=3, rd=0(select v0)

# 存储 v0 到 GPR a0
.insn r 0x0b, 0, 4, a0, x0, x0    # funct3=0, funct7=4, rs1=0(select v0)

# v0 = v0 + v1
.insn r 0x0b, 0, 5, x0, x0, x0    # funct3=0, funct7=5

# v0 = v0 ^ v1
.insn r 0x0b, 0, 6, x0, x0, x0    # funct3=0, funct7=6
```

---

## 四、实现方案

### 4.1 RTL 结构

```
dummy_coprocessor.v
├── scalar_op (funct7=0-2)
├── lane_ops (funct3=1-3)
├── state_ops (funct3=4-7)
└── vrf_ops (funct7=3-8)  ← 新增
    ├── vrf[0..3] (4x32-bit 寄存器)
    ├── vrf_write_ctrl
    └── vrf_read_mux
```

### 4.2 VRF 写入时序

与现有 scratch/vlen 一致：写入延迟到完成拍。

```
Cycle 0: vload issue → latched_res = old_v[rd_field], pending_vrf_write = 1
Cycle 1: countdown
Cycle 2: o_done fires → v[rd_field] <= rs1
```

### 4.3 flush 语义

- flush 取消未提交的 VRF 写入（pending_vrf_write 清零）
- 已提交的 VRF 值不受 flush 影响
- 与 scratch/vlen 语义一致

### 4.4 reset 语义

- reset 清零所有 VRF 寄存器
- 与 scratch/vlen 语义一致

---

## 五、验证计划

### 5.1 基础测试

| 测试名 | 覆盖操作 | 验证重点 |
|--------|----------|----------|
| cop-vrf-load-store | vload, vstore | VRF 读写基本功能 |
| cop-vrf-vadd8 | vload, vadd8, vstore | VRF lane add 完整流程 |
| cop-vrf-vxor8 | vload, vxor8, vstore | VRF lane xor |
| cop-vrf-vand8 | vload, vand8, vstore | VRF lane and |

### 5.2 状态测试

| 测试名 | 覆盖操作 | 验证重点 |
|--------|----------|----------|
| cop-vrf-persist | vload, scalar ops, vstore | VRF 跨标量操作持久性 |
| cop-vrf-flush | vload, branch, vstore | VRF 跨控制流持久性 |
| cop-vrf-indep | vload v0, vload v1, vstore | 多 VRF 寄存器独立性 |

### 5.3 混合测试

| 测试名 | 覆盖操作 | 验证重点 |
|--------|----------|----------|
| cop-vrf-mixed | vrf ops + lane ops + state ops | VRF 与现有操作互不干扰 |
| cop-vrf-chain | vload, vadd8, vxor8, vand8, vstore | VRF 操作链 |

---

## 六、开发步骤

### Phase 1：VRF 寄存器（1-2 天）

1. 在 `dummy_coprocessor.v` 中添加 `reg [31:0] vrf[0:3]`
2. 添加 `pending_vrf_write` 和 `pending_vrf_value` 控制逻辑
3. 添加 reset 和 flush 处理
4. 更新 cop_result mux

### Phase 2：VRF 读写操作（1 天）

1. 实现 `vload`（funct7=3）：GPR → VRF
2. 实现 `vstore`（funct7=4）：VRF → GPR
3. 添加测试：`cop-vrf-load-store`

### Phase 3：VRF 运算操作（1-2 天）

1. 实现 `vadd8`（funct7=5）：v0 = v0 + v1
2. 实现 `vxor8`（funct7=6）：v0 = v0 ^ v1
3. 实现 `vand8`（funct7=7）：v0 = v0 & v1
4. 实现 `vsub8`（funct7=8）：v0 = v0 - v1
5. 添加测试：`cop-vrf-vadd8`, `cop-vrf-vxor8`, `cop-vrf-vand8`

### Phase 4：集成验证（1 天）

1. 混合测试：VRF + lane ops + state ops
2. 全量回归：确保不破坏现有 58 个测试
3. 更新文档

---

## 七、风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| VRF 写入与 flush 竞争 | 状态污染 | 延迟到完成拍写入，与 scratch/vlen 一致 |
| funct7 空间不足 | 无法扩展更多操作 | 当前 3-8 只用 6 个，还有 119 个可用 |
| VRF 寄存器数量不够 | 无法覆盖复杂运算 | 4 个足够 V1；后续可扩展到 8/16 |
| 与现有操作冲突 | 回归失败 | funct7 扩展不改变 funct3=0 的默认行为 |

---

## 八、与后续阶段的关系

VRF 完成后，下一步可考虑：

1. **向量访存**：通过 VRF load/store 扩展到内存访问
2. **更多 VRF 运算**：vmul8, vsll8, vsrl8 等
3. **VRF 配置**：通过 vlen 控制活跃 lane 数量
4. **多 VRF 操作**：v0 = v1 + v2 等三操作数格式

这些都建立在 VRF 基础设施之上，不需要修改 CPU 侧接口。
