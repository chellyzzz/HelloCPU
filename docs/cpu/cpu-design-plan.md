# HelloCPU CPU 设计规划

## 一、文档目标

本文档专注于 HelloCPU **CPU 本体** 后续一段时间的设计规划。A/B 两条 CPU 优化线的分工、文件边界和进度记录见 `cpu-ab-collaboration.md`。

## 二、当前 CPU 状态

HelloCPU 当前已经具备：

- 五级顺序流水，RV32IM + Zicsr
- 4 KB ICache + 4 KB DCache
- 128-entry BTB + RAS + static JAL 分支预测
- Same-cycle LSU load/store hit（0-cycle cache hit）
- CPU tests 全通过（48/48）
- CoreMark 正确通过

### 当前性能基准（`8f48295`）

| Metric | Value |
|--------|-------|
| CoreMark/MHz | 2.853 |
| Total cycles (ITER=100) | 35,047,662 |
| IPC | 0.874 |
| Stall rate | 10.4% |

### 当前 stall 分布

| 来源 | Cycles | 占比 | Owner |
|------|--------|------|-------|
| Frontend/empty | 2,005,006 | 55.0% | B |
| Other backend | 837,926 | 23.0% | A（统计口径清洗） |
| Control recovery | 795,702 | 21.8% | B |
| LSU wait | 7,107 | 0.2% | Done |
| DIV wait | 2,962 | 0.1% | Done |

### 已完成的优化

| 优化 | Commit | CoreMark/MHz 变化 |
|------|--------|-------------------|
| Same-cycle load hit | `442bff8` | 2.382 → 2.737 (+14.9%) |
| Same-cycle store hit | `9e92c22` | 2.737 → 2.853 (+4.2%) |
| DIV fast paths (by-1, trivial-zero) | `8f48295` | DIV wait -21%, CoreMark unchanged |
| 128-entry BTB | `b73e571` | 42000681 → 41986504 cycles |
| MUL low fast path | `2ce4777` | MUL wait → 0 |
| Redirect recovery measurement | `27d0e4f` | 3 avg cycles × 772K events |

### 被拒绝的实验

| 实验 | 失败原因 |
|------|----------|
| 静态后跳 taken 预测 | CoreMark 2.381 → 2.373 退化 |
| 组合 RREADY/BREADY | 仿真挂死，AXI RAM 不兼容 |
| 删除 WBU branch/JAL/JALR pc_update | 破坏 sum/quick-sort |
| IFU/IDU registered-valid | sum 跳过 0x30000000/0x30000b00 |
| IFU/IDU skid buffer | JAL 重复 commit |

## 三、当前最主要的问题

### #1 Frontend/empty（55% of stalls，B 线负责）

96% 是 redirect recovery bubble：772K redirects × 2.5 frontend/empty cycles = 1.93M cycles。根因链：BTB miss (780K) → branch mispredict → redirect → pipeline refill。

B 线任务：降低 BTB miss rate 或缩短 redirect recovery 延迟。

### #2 Other backend（23% of stalls，A 线负责清洗统计口径）

最新细分结果表明，`Other backend` 当前不是一个可以直接拿来做 RTL 优化的“真 stall”热点。

把它拆成 `blocked` 和 `pipe latency` 后，可以看到：

- `blocked = 0`
- `pipe latency = 100%`
- `pipe latency` 几乎全部来自普通 `ALU/other` 指令

也就是说，这个桶当前主要混入了**普通标量指令经过 EXU→WBU 一拍的正常在飞周期**，而不是后端真的把流水卡住了。

因此 A 线在这件事上的下一步是：

1. 继续把 `normal backend occupancy` 和 `true backend stall` 彻底分开；
2. 避免把一个统计残项误判成真实性能热点；
3. 完成计数器清洗后，再决定是否还有值得继续优化的 backend 残余热点。

### #3 Control recovery（22% of stalls，B 线负责）

795K redirects，3 avg cycles。与 #1 是同一根因的不同计数。JAL 恢复 20 avg cycles（4,962 events），但占比仅 0.6%。

## 四、设计原则

### 1. 边界清晰优先于局部 patch

执行请求、完成、提交、冲刷、访存请求/返回的语义应逐步统一。不在现有 EXU/WBU 上堆条件分支。

### 2. 减少全局阻塞

哪个单元忙，哪个单元局部 backpressure。非依赖指令尽量继续前进。

### 3. 区分结果完成与架构提交

数据什么时候算出来 vs 数据什么时候可以正式提交。对 LSU 返回、多周期乘除、分支恢复、协处理器接入都关键。

### 4. 用最小必要结构换最大清晰度

不追求 dual-issue 或有限乱序。用统一接口、最小在飞项管理、轻量级 queue 把问题拆开。

## 五、主线设计方向

### 方向一：前端性能优化（B 线）

BTB 改善、redirect recovery 缩短、前端气泡减少。当前占 77% 的 stall。

### 方向二：后端剩余优化（A 线）

Other backend 统计口径清洗、store buffer、旁路强化。

### 方向三：统一执行后端接口

把 ALU/Branch/LSU/MUL/DIV 从"EXU 内部条件分支"重构成统一 request/accept/complete/writeback/flush 模型。短期不提分，但是后续扩展基础。

### 方向四：适度前后端解耦

fetch queue、decode queue、更明确的 issue 边界。减少后端反压对前端供给的影响。

### 方向五：轻量级 scoreboard

管理寄存器就绪状态、执行单元忙状态、访存请求状态。便于扩展协处理器。

## 六、建议的实施阶段

### 第一阶段（已完成）：后端高收益优化

- Same-cycle LSU load+store hit ✅
- MUL low fast path ✅
- DIV fast paths ✅
- 性能计数器细分 ✅
- 128-entry BTB ✅

### 第二阶段（进行中）：前端瓶颈消除

- BTB miss rate 降低（B-Task-7）
- Redirect recovery 缩短（B-Task-8）
- Other backend 统计口径清洗与 backend 语义理顺（A 线）

### 第三阶段：结构化扩展

- 统一执行后端接口
- 前后端解耦（fetch/decode queue）
- 轻量级 scoreboard
- Store buffer
- 为协处理器留自然接口

## 七、当前不建议优先做的事

- 继续扩大 BTB 容量（B 线应先尝试改善预测策略）
- 单纯增大 cache 容量（hit rate 已 99.6%+）
- 直接推进 dual-issue
- 直接尝试有限乱序
- 在结构未清晰前引入复杂大队列
