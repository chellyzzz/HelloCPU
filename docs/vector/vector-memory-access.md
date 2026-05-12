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

### 2.1 方案选择：COP 直连 AXI（绕过 DCache）

**选项 A：COP 直连 AXI（推荐，V1 采用）**
- COP 访存时绕过 LSU DCache，直接发起 AXI single-beat 请求
- 在 `hcpu.v` 加一个 AXI mux（标量 LSU vs COP）
- 优点：不动 LSU FSM，干净，V1 阶段 DCache 对 4 字节访存收益不大
- 缺点：COP 访存不经过 DCache（V1 可接受，阶段 D 再优化）

**选项 B：COP 通过 LSU FSM**
- LSU FSM 新增 `S_COP_LOAD` / `S_COP_STORE` 状态
- 优点：COP 自动获得 DCache 加速
- 缺点：修改 LSU FSM，风险较高

**选择理由**：V1 阶段优先正确性，选择方案 A。后续阶段可升级到方案 B。

### 2.2 仲裁策略：COP busy 自然串行化

**不需要显式仲裁逻辑**。原因：
- COP 访存时 `o_busy=1`，CPU 流水线 stall（`exu2idu_ready=0`）
- 标量 LSU 不会同时发起请求（CPU 流水线被阻塞）
- COP busy 自然串行化了标量访存和 COP 访存

**确认**：COP 访存期间，COP 的 `o_busy=1`，CPU 流水线 stall，标量 LSU 不会同时发起事务。

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

- V1 阶段不支持异常上报（`o_exception` 端口暂不需要）
- 当前所有访存地址是软件构造的，TLB/misalign 异常处理是 V2 的事
- 减少接口复杂度，降低实现风险

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

需要新增内存请求/响应端口（A 线确认的接口）：

```verilog
// COP → AXI（请求）
output        o_mem_req,       // =1 表示 COP 要访存
output [31:0] o_mem_addr,      // 访存地址
output [31:0] o_mem_wdata,     // 写数据（store 时有效）
output        o_mem_wen,       // =1 store, =0 load

// AXI → COP（响应）
input         i_mem_done,      // =1 访存完成
input  [31:0] i_mem_rdata,     // 读数据（load 时有效）
```

**接口说明**：
- 不需要 `_valid`/`_ready` 握手 — COP 访存时 LSU 被独占，COP 等 `i_mem_done` 即可
- COP 访存期间 `o_busy=1`，CPU 流水线 stall，标量 LSU 不会同时发起事务
- 不需要仲裁逻辑，COP busy 自然串行化

**连接方式**：
- `cop_backend.v`：透传内存端口
- `hcpu.v`：AXI mux（标量 LSU vs COP），COP 直连 AXI 绕过 DCache

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

1. 在 `dummy_coprocessor.v` 中新增内存请求/响应端口（6 个信号）
2. 在 `cop_backend.v` 中透传内存端口
3. 在 `hcpu.v` 中添加 AXI mux（标量 LSU vs COP），COP 直连 AXI 绕过 DCache

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
| 内存请求与标量访存冲突 | 性能下降 | COP busy 自然串行化，不需要仲裁 |
| flush 时内存请求未完成 | 状态不一致 | flush 时取消所有未完成请求 |
| AXI mux 复杂度 | CPU 侧改动 | 仅修改 hcpu.v，不动 LSU FSM |
| COP 访存不经过 DCache | 性能 | V1 可接受，阶段 D 再优化 |

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
1. **COP 直连 AXI**：绕过 DCache，不动 LSU FSM，低风险
2. **COP busy 串行化**：不需要仲裁逻辑，COP busy 自然阻塞标量 LSU
3. **串行 4 次请求**：每次 COP 操作约 20-40 cycles，V1 可接受
4. **固定 4 元素**：与现有 VRF 一致
5. **不支持异常**：V1 暂不需要，减少接口复杂度
6. **6 个信号接口**：`o_mem_req`/`o_mem_addr`/`o_mem_wdata`/`o_mem_wen`/`i_mem_done`/`i_mem_rdata`

下一步：A 线确认接口设计后，C 线开始实现。A 在下一个集成点接收。
