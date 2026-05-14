# 最小向量访存当前基线

## 一、目标

记录当前 COP 原型里的最小向量 load/store 基线，让 VRF 能与内存交互，并为后续 RVV unit-stride load/store 迁移保留清晰边界。

### 最终目标（RVV 兼容）

- 支持标准 RVV 向量 load/store 指令（`vle8.v`、`vse8.v` 等）
- 支持多种元素宽度（8/16/32/64-bit）
- 支持多种寻址模式（unit-stride、stride、gather/scatter）
- 支持可配置向量长度（VL）
- 支持向量掩码（vm=0/1）

### 当前阶段目标（V1 最小实现）

- 通过 CPU 侧 memory owner 边界访问内存，COP 访存期间复用统一外部 AXI master。
- 仅支持 unit-stride（连续地址）
- 仅支持 8-bit 元素宽度
- 固定 4 元素向量长度
- 不支持掩码

---

## 二、当前设计

### 2.1 CPU memory owner 边界

当前实现不是独立的长期 vector memory subsystem，而是 V1 COP memory bring-up：

- `dummy_coprocessor.v` 发出 COP-local memory request。
- `cop_backend.v` 透传 `o_cop_mem_req_*` / `i_cop_mem_resp_*`。
- `hcpu.v` 在 CPU memory owner 边界选择 scalar 或 COP owner。
- COP owner active 时驱动共享 AXI master 的 single-beat byte request。
- completion 只在未被 kill 时返回 COP backend。

这个边界的目标是保持 scalar LSU 与 COP memory 的 owner 语义一致，避免为 COP 继续增加 ad-hoc top-level special case。

### 2.2 仲裁策略：V1 串行 owner

当前 V1 仍依赖单发射和最多一个 COP 请求在飞：

- COP 访存期间 `o_busy=1`，CPU 流水线被 backpressure。
- memory owner 边界只有 scalar 或 COP 一个 active owner。
- COP request 只在 owner idle 且没有 stale completion bubble 时被接受。
- 后续若支持多个 vector memory request in flight，需要重新设计 owner/scoreboard/commit 语义。

### 2.3 编码方案

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

### 2.4 时序设计

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

### 2.5 kill/flush 语义

- kill/flush 会标记当前 COP memory transaction 为 killed。
- killed load 的晚到响应被 CPU owner 边界吸收，不返回 COP backend，也不写入 VRF。
- killed store 不应在 kill 后新发起写入；已经被外部总线接受的写入是架构可见风险点，后续 RVV store 必须进一步对齐 commit 边界。
- directed target `cop_mem_pending_kill` 覆盖 pending load response 晚到后的吸收与恢复。

### 2.6 异常处理

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

### 3.2 COP memory 接口

当前 COP-local memory 请求/响应端口：

```verilog
// COP -> CPU memory owner boundary
output        o_cop_mem_req_valid,
output        o_cop_mem_req_store,
output [31:0] o_cop_mem_req_addr,
output [31:0] o_cop_mem_req_wdata,
output [2:0]  o_cop_mem_req_size,

// CPU memory owner boundary -> COP
input         i_cop_mem_resp_valid,
input  [31:0] i_cop_mem_resp_rdata,
```

**接口说明**：
- 当前没有 request ready；V1 依赖 COP busy 和 CPU owner idle 串行化。
- `o_cop_mem_req_size` 当前固定为 byte。
- `i_cop_mem_resp_valid` 已经过 kill qualification，killed completion 不返回 COP backend。

**连接方式**：
- `cop_backend.v`：透传内存端口
- `hcpu.v`：通过 memory owner 边界选择 scalar 或 COP owner，并驱动共享 AXI master

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
| cop-vload-repeat-mem | vload_mem x2 | 重复地址加载，供 directed pending-kill 使用 |
| cop-vstore-repeat-mem | vstore_mem x2 | 重复 store，供 directed pre-accept store-kill 使用 |
| cop_mem_pending_kill | vload_mem + test-only kill | stale completion 吸收和后续恢复 |
| cop_mem_store_directed | vstore_mem + test-only monitor | COP store 走 AW/W/B owner path，且 B 后才暴露 response |
| cop_mem_store_kill | vstore_mem + test-only kill | AW/W 接受前 kill 不产生 store bus side effect，后续 store 恢复 |

`COP_MEM_PENDING_KILL_TB` 构建还导出 COP-specific debug pulses：`tb_cop_mem_ar_fire`、`tb_cop_mem_r_fire`、`tb_cop_mem_aw_fire`、`tb_cop_mem_w_fire`、`tb_cop_mem_b_fire`、`tb_cop_mem_store` 和 `tb_cop_mem_addr`。directed top 还提供 `tb_hold_read_resp` 和 `tb_hold_write_req` 来制造 pending load/store 场景。这些信号只用于 directed sim，不属于普通 RTL 接口。

### 4.2 后续边界测试

| 测试名 | 覆盖操作 | 验证重点 |
|--------|----------|----------|
| cop-vload-mem-align | vload_mem | 对齐地址，当前可由基础测试覆盖 |
| cop-vload-mem-misalign | vload_mem | 未对齐地址，后续需定义支持或 illegal |
| cop-vstore-kill | vstore_mem | killed store 不产生错误 side effect |

### 4.3 混合测试

| 测试名 | 覆盖操作 | 验证重点 |
|--------|----------|----------|
| cop-vload-mem-lane | vload_mem + vrf lane ops | 内存加载后接向量计算 |
| cop-vstore-mem-lane | vrf lane ops + vstore_mem | 向量计算后存储到内存 |

---

## 五、开发步骤

### Phase 1：当前已完成基线

1. `dummy_coprocessor.v` 实现 `vload_mem` / `vstore_mem`。
2. `cop_backend.v` 透传 COP memory request/response。
3. `hcpu.v` 接入 CPU memory owner 边界。
4. 已有 `cop-vload-mem`、`cop-vstore-mem`、`cop-vload-store-mem`、`cop-vload-repeat-mem`。
5. 已有 `cop_mem_pending_kill` directed coverage。

### Phase 2：P0 收敛项

1. 保持文档、编码表和测试矩阵与 RTL 同步。
2. 固化 smoke 列表，避免后续 RVV 迁移回退 custom COP 基线。
3. 补 killed store 或 store side effect 的 directed coverage 设计。
4. 明确 misalign、异常和 unsupported 行为仍是后续阶段。

---

## 六、风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 内存请求与标量访存冲突 | owner 混乱或错误响应 | 通过 memory owner 边界串行化 scalar/COP |
| flush 时内存请求未完成 | 状态不一致 | flush 时取消所有未完成请求 |
| AXI mux 复杂度 | CPU 侧改动 | V1 只在 owner 边界选择 scalar/COP，不改 LSU FSM |
| COP 访存不经过 DCache | 性能 | V1 可接受，阶段 D 再优化 |
| killed store side effect | 内存错误提交 | 后续 RVV store 前必须补 commit/kill 语义设计和 directed test |

---

## 七、与 RVV 的映射关系

| 当前操作 | RVV 对应 | 迁移策略 |
|----------|----------|----------|
| `funct7=14` (vload_mem) | `vle8.v` | custom prototype 保留为 legacy/debug harness |
| `funct7=15` (vstore_mem) | `vse8.v` | custom prototype 保留为 legacy/debug harness |
| 固定 4 元素 | 可配置 VL | 标准 `vle8.v/vse8.v` 已按当前 `vl` 限制 active byte lanes |
| 8-bit 元素 | 多种宽度 | 扩展到 16/32/64-bit |
| unit-stride | 多种模式 | 扩展到 stride/gather/scatter |

---

## 八、总结

当前基线通过 CPU memory owner 边界实现 VRF 与内存的交互。V1 实现仅支持 unit-stride 8-bit 访存，后续可逐步扩展到 RVV 标准。

P0 收尾状态：当前 smoke 覆盖 `cop-vload-mem`、`cop-vstore-mem`、`cop-vload-store-mem`、`cop-vload-repeat-mem`、`cop-vstore-repeat-mem`；directed coverage 覆盖 pending-kill load、store AW/W/B owner path 和 AW/W 接受前 killed-store 无 bus side effect。后续 P1 不应扩大 memory side effect 语义，除非先完成 RVV store commit/kill 设计。

Phase 4 标准 memory slice 已支持 `vle8.v/vse8.v`：

1. 只识别 unit-stride `vm=1`、`width=000`、`mop=00`、`mew=0`、`nf=0` 编码。
2. 只在 `SEW=8`、`LMUL=m1`、`vill=0` 下发起 memory request。
3. `vl=0` 时 `vle8.v` 写 0 到目标 VRF，`vse8.v` 不发起 memory request。
4. `0<vl<4` 时只访问 active byte lanes，inactive bytes 在 load result 中写 0。
5. `vd/vs3` 当前仍映射到 4-entry COP-local VRF 低两位。
6. memory request/response 继续复用 CPU memory owner 边界，kill/store directed coverage 继续作为安全门槛。
7. directed tests 使用 static initialized memory，避免 stack store 留在 scalar cache 而 COP owner bypass 从 backing memory 读到旧值。

Phase 6 标准 memory slice 已支持 `vle32.v/vse32.v`：

1. 只识别 unit-stride `vm=1`、`width=110`、`mop=00`、`mew=0`、`nf=0` 编码。
2. 只在 `SEW=32`、`LMUL=m1`、`vill=0`、`vl>0` 下发起 memory request。
3. 为复用当前 COP memory owner 的 byte strobe，`vle32.v/vse32.v` 使用 4 个 byte-serial requests，而不是一个 word request。
4. `vl=0` 时 `vle32.v` 写 0 到目标 VRF，`vse32.v` 不发起 memory request。
5. `vd/vs3` 当前仍映射到 4-entry COP-local VRF 低两位。
6. 不声明 scalar cache 与 COP bypass coherent；directed tests 继续使用 static initialized backing memory。

关键设计决策：
1. **CPU memory owner 边界**：scalar 和 COP 请求使用统一 owner 语义
2. **COP busy 串行化**：V1 不支持多个 COP memory 请求在飞
3. **串行 4 次请求**：每次 COP 操作约 20-40 cycles，V1 可接受
4. **固定 4 元素**：与现有 VRF 一致
5. **不支持异常**：V1 暂不需要，减少接口复杂度
6. **COP-local memory 接口**：`o_cop_mem_req_*` / `i_cop_mem_resp_*`

下一步：继续 P0 收敛，补齐文档、smoke 列表和 killed store 风险项；进入 RVV 前不扩大 memory 接口语义。
