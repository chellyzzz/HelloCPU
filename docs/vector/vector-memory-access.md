# 最小向量访存设计草案

## 一、目标

在现有 COP 框架上引入最小向量 load/store，让 VRF 能与内存交互，为后续 RVV 向量访存打下基础。

### 最终目标（RVV 兼容）

- 支持标准 RVV 向量 load/store 指令（`vle8.v`、`vse8.v` 等）
- 支持多种元素宽度（8/16/32/64-bit）
- 支持多种寻址模式（unit-stride、stride、gather/scatter）
- 支持可配置向量长度（VL）
- 支持向量掩码（vm=0/1）

### 当前阶段目标（V1 最小实现）

- 通过 CPU 侧已有 LSU 路径访问内存（共享路径，低风险）
- 仅支持 unit-stride（连续地址）
- 仅支持 8-bit 元素宽度
- 固定 4 元素向量长度
- 不支持掩码

---

## 二、设计方案

### 2.1 方案选择：CPU 侧 LSU 共享路径

**选项 A：共享 CPU 侧 LSU（推荐）**
- COP 通过 CPU 侧已有的 LSU 路径访问内存
- 优点：复用已有 AXI 接口、cache、仲裁逻辑，低风险
- 缺点：COP 访存与标量访存共享带宽，可能有性能瓶颈

**选项 B：独立 COP 内存端口**
- COP 有独立的内存请求/响应端口
- 优点：可并行访问，高吞吐
- 缺点：需要修改 AXI 仲裁、增加复杂度、高风险

**选择理由**：V1 阶段优先正确性，选择方案 A。后续阶段可升级到方案 B。

### 2.2 编码方案

使用 `funct3=0` 的 `funct7` 扩展空间，新增向量 load/store 操作：

| funct3 | funct7 | 操作 | 语义 |
|--------|--------|------|------|
| 0 | 14 | vload_mem | 从内存加载 4 字节到 v0（unit-stride） |
| 0 | 15 | vstore_mem | 从 v0 存储 4 字节到内存（unit-stride） |

**编码说明**：
- `rs1`：基地址（GPR）
- `rs2`：未使用（保留）
- `rd`：未使用（保留）
- `funct7=14`：向量 load
- `funct7=15`：向量 store

**内存布局**：
- v0 的 4 个字节按小端序存储
- 地址 `base` 存储 `v0[7:0]`
- 地址 `base+1` 存储 `v0[15:8]`
- 地址 `base+2` 存储 `v0[23:16]`
- 地址 `base+3` 存储 `v0[31:24]`

### 2.3 时序设计

**向量 load（vload_mem）**：
```
Cycle 0: issue → 发送 4 个内存读请求（连续地址）
Cycle 1-N: 等待内存响应
Cycle N+1: 合并 4 个字节到 v0，o_done 置 1
```

**向量 store（vstore_mem）**：
```
Cycle 0: issue → 发送 4 个内存写请求（连续地址）
Cycle 1-N: 等待内存响应
Cycle N+1: o_done 置 1
```

**关键点**：
- 4 个内存请求可以并行发出（如果 LSU 支持）
- 或者串行发出（更简单，V1 先用串行）
- flush 时取消未完成的内存请求

### 2.4 flush 语义

- flush 时取消所有未完成的内存请求
- 已完成的内存写入不可撤销（内存是架构状态）
- 已完成的内存读取结果丢弃（不写入 VRF）
- 与现有 COP flush 语义一致

### 2.5 异常处理

- 内存访问异常（地址错误、权限错误等）需要上报给 CPU
- 异常时 COP 不写入 VRF（保持原子性）
- 异常通过 COP 接口的 `o_exception` 信号上报（需要新增）

---

## 三、实现方案

### 3.1 RTL 结构

```
dummy_coprocessor.v
├── 现有逻辑（scalar_op, lane_ops, state_ops, vrf_ops）
└── mem_ops（新增）
    ├── mem_req_valid
    ├── mem_req_addr
    ├── mem_req_wdata
    ├── mem_req_wen
    ├── mem_resp_valid
    ├── mem_resp_rdata
    └── mem_state（idle, req0, req1, req2, req3, wait）
```

### 3.2 COP 接口扩展

需要新增内存请求/响应端口：

```verilog
// 新增端口
output reg          o_mem_req_valid,
output reg [31:0]   o_mem_req_addr,
output reg [31:0]   o_mem_req_wdata,
output reg          o_mem_req_wen,
input               i_mem_resp_valid,
input      [31:0]   i_mem_resp_rdata,
output reg          o_exception
```

**注意**：这些端口需要连接到 CPU 侧的 LSU，需要修改 `cop_backend.v` 和 `hcpu.v`。

### 3.3 状态机设计

```
IDLE: 等待向量 load/store 指令
REQ0: 发送第 0 个字节的内存请求
REQ1: 发送第 1 个字节的内存请求
REQ2: 发送第 2 个字节的内存请求
REQ3: 发送第 3 个字节的内存请求
WAIT: 等待所有内存响应
DONE: 合并结果，写入 VRF，o_done 置 1
```

**串行 vs 并行**：
- V1 先实现串行（REQ0 → REQ1 → REQ2 → REQ3 → WAIT）
- 后续可优化为并行（同时发出 4 个请求）

### 3.4 地址计算

- 基地址：`i_src1`（rs1 的值）
- 第 0 个字节：`base + 0`
- 第 1 个字节：`base + 1`
- 第 2 个字节：`base + 2`
- 第 3 个字节：`base + 3`

---

## 四、验证计划

### 4.1 基础测试

| 测试名 | 覆盖操作 | 验证重点 |
|--------|----------|----------|
| cop-vload-mem | vload_mem | 从内存加载到 VRF |
| cop-vstore-mem | vstore_mem | 从 VRF 存储到内存 |
| cop-vload-store-mem | vload_mem + vstore_mem | 加载-存储往返 |

### 4.2 边界测试

| 测试名 | 覆盖操作 | 验证重点 |
|--------|----------|----------|
| cop-vload-mem-align | vload_mem | 对齐地址 |
| cop-vload-mem-misalign | vload_mem | 未对齐地址（如果支持） |
| cop-vload-mem-zero | vload_mem | 零地址（异常） |

### 4.3 混合测试

| 测试名 | 覆盖操作 | 验证重点 |
|--------|----------|----------|
| cop-vload-mem-lane | vload_mem + vrf lane ops | 内存加载后接向量计算 |
| cop-vstore-mem-lane | vrf lane ops + vstore_mem | 向量计算后存储到内存 |

---

## 五、开发步骤

### Phase 1：设计评审（当前）

1. 评审本设计草案
2. 确认编码方案、时序设计、flush 语义
3. 确认是否需要修改 CPU 侧接口

### Phase 2：COP 接口扩展（1-2 天）

1. 在 `dummy_coprocessor.v` 中新增内存请求/响应端口
2. 在 `cop_backend.v` 中透传内存端口
3. 在 `hcpu.v` 中连接内存端口到 LSU

### Phase 3：向量 load 实现（2-3 天）

1. 实现 `vload_mem`（funct7=14）状态机
2. 实现串行内存请求逻辑
3. 实现内存响应合并逻辑
4. 添加测试：`cop-vload-mem`

### Phase 4：向量 store 实现（1-2 天）

1. 实现 `vstore_mem`（funct7=15）状态机
2. 实现串行内存写逻辑
3. 添加测试：`cop-vstore-mem`

### Phase 5：集成验证（1 天）

1. 混合测试：向量 load/store + lane ops + state ops
2. 全量回归：确保不破坏现有 62 个测试
3. 更新文档

---

## 六、风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 内存请求与标量访存冲突 | 性能下降 | V1 先串行，后续可优化 |
| flush 时内存请求未完成 | 状态不一致 | flush 时取消所有未完成请求 |
| 内存异常处理 | 需要新增异常上报 | V1 先不支持异常，后续扩展 |
| CPU 侧 LSU 接口变更 | 需要修改 CPU 侧 | 先确认接口设计，再实现 |

---

## 七、与 RVV 的映射关系

| 当前操作 | RVV 对应 | 迁移策略 |
|----------|----------|----------|
| `funct7=14` (vload_mem) | `vle8.v` | 迁移到标准 RVV load |
| `funct7=15` (vstore_mem) | `vse8.v` | 迁移到标准 RVV store |
| 固定 4 元素 | 可配置 VL | 扩展到 vlen 配置 |
| 8-bit 元素 | 多种宽度 | 扩展到 16/32/64-bit |
| unit-stride | 多种模式 | 扩展到 stride/gather/scatter |

---

## 八、总结

本草案设计了最小向量访存方案，通过共享 CPU 侧 LSU 路径实现 VRF 与内存的交互。V1 实现仅支持 unit-stride 8-bit 访存，后续可逐步扩展到 RVV 标准。

关键设计决策：
1. **共享 LSU**：低风险，复用已有基础设施
2. **串行请求**：简单，V1 先用串行
3. **固定 4 元素**：与现有 VRF 一致
4. **不支持掩码**：V1 先不支持，后续扩展

下一步：评审本草案，确认后开始实现。
