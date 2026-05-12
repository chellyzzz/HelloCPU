# HelloCPU CPU 演进路线文档

## 一、文档目标

本文档从**整体性能优化**角度描述 HelloCPU 的长期演进路线，而不是只盯住某一个局部热点。

目标有三层：

1. 持续提高当前标量 CPU 的真实性能；
2. 逐步把微架构从“局部 patch 驱动”推进到“边界清晰、结构稳定”；
3. 为未来的 COP / RVV / vector memory 扩展预留自然接口。

本文档同时给出：

- 当前阶段判断；
- 长期优化主线；
- 分阶段目标；
- A/B 两条 CPU 线的职责分配。

## 二、长期性能目标

当前需要明确一个现实约束：

> **在当前单发射、顺序、单结果提交的标量核框架下，IPC 不可能长期达到 2。**

因此，如果长期目标是 **`IPC >= 2`**，那么这已经不是“继续做局部优化”的问题，而是要明确进入新的微架构阶段。

这意味着：

1. 短期目标不再是单纯抬高当前单发射核的 IPC 上限；
2. 中期要把当前核心演进成“可双发射、可解耦、可扩展”的结构；
3. 长期要接受如下事实：
   - `IPC ~0.8 -> 1.0` 可以靠当前单发射核内的局部优化实现；
   - `IPC > 1.0` 需要显著减少 bubble 和等待；
   - **`IPC >= 2` 基本要求至少 2-wide in-order issue/commit 能力**，或者等价的更强结构并行性。

所以本文档后续路线分为两层：

- **阶段 A：把当前单发射核做到接近它的合理上限**；
- **阶段 B：为 IPC 2 目标做结构跃迁准备，并最终进入双发射顺序核。**

## 三、当前全局判断

当前稳定点：`8f48295`

当前 CoreMark `ITER=100`：

| Metric | Value |
|--------|-------|
| CoreMark/MHz | 2.853 |
| Total cycles | 35,047,662 |
| IPC | 0.874 |
| Stall rate | 10.4% |

当前 stall 构成：

| Source | Cycles | % of stalls | 说明 |
|--------|--------|-------------|------|
| Frontend/empty | 2,005,006 | 55.0% | 主要是 redirect recovery bubble |
| Control recovery | 795,702 | 21.8% | redirect 本体开销 |
| Other backend | 837,926 | 23.0% | 当前已确认不是“真 stall”热点，几乎全部是普通标量指令经过 EXU→WBU 的正常 pipe latency，需要继续从 stall 统计里剥离 |
| LSU wait | 7,107 | 0.2% | 已基本解决 |
| DIV wait | 2,962 | 0.1% | 已基本解决 |

### 当前最重要的全局结论

1. **LSU 已不是主瓶颈。** same-cycle load/store hit 已经把 LSU 从 6.98M cycles 降到 7K。
2. **真正的大头已经转到 redirect 链。** `Frontend/empty + Control recovery ≈ 2.8M cycles`，占当前 stall 的约 77%。
3. **“Other backend” 目前不能直接当成性能热点。** 最新细分显示 `blocked = 0`、`pipe latency = 100%`，说明这里主要是正常 backend occupancy，而不是后端真正阻塞。
4. 后续优化不应再继续以 LSU 局部 patch 为主，而应转向：
   - 前端预测与恢复；
   - backend 语义清晰化；
   - 面向未来向量扩展的统一接口。

## 四、长期整体优化主线

如果跳出单点优化，HelloCPU 后续的长期性能提升应当沿着三条主线推进。

### 主线 A：减少“发生多少次慢恢复”

这条线本质上是**降低 redirect 次数**：

- 提高 BTB 有效命中率；
- 改进 branch target / direction 覆盖；
- 减少无谓的后级 redirect；
- 让 predictor 学到更多真实分支行为。

这是“减少问题发生次数”的路线。

### 主线 B：减少“每次慢恢复要花多久”

这条线本质上是**降低 redirect 单次成本**：

- redirect recovery 3-cycle → 2-cycle；
- flush / refill 边界更轻；
- IFU/IDU/IDU-EXU 的恢复路径更短。

这是“单次事故代价更低”的路线。

### 主线 C：减少“正常流水也被算成等待”

这条线本质上是**清理后端结构边界和统计口径**：

- 把 EXU accept、result ready、WBU valid、architectural commit 分清；
- 把正常在飞周期和真正 stall 分离；
- 让未来 COP / vector memory / long-latency backend 能自然接入。

这是“把结构理清，避免假瓶颈和接口混乱”的路线。

## 五、分阶段路线

## 阶段 0：已完成的高收益局部优化

这个阶段已经完成，不再作为主战场。

完成项：

1. 128-entry BTB
2. WBU `pc_update` 原因归因
3. same-cycle LSU load hit
4. same-cycle LSU store hit
5. MUL low fast path
6. DIV trivial fast path

效果：

- CoreMark/MHz `2.382 -> 2.853`
- LSU wait `6.98M -> 7K`
- Stall rate `25.2% -> 10.4%`

这一阶段说明：HelloCPU 已经不再是“被 LSU 卡死的教学核”，而是一个前端恢复成本主导的顺序核。

## 阶段 1：把当前单发射核做到接近上限（当前主阶段）

### 目标

把当前单发射核的明显浪费尽可能清掉，让 IPC 从当前 `0.874` 继续向 `~1.0` 靠近。

### 主要任务

1. 降低 BTB miss / mispredict
2. 缩短 redirect recovery latency
3. 精确区分 frontend bubble、control recovery、normal pipeline occupancy
4. 分清 `Other backend` 中哪些是“真 stall”，哪些只是正常 EXU→WBU latency

### 预期收益

这是当前唯一仍有 **5%~10% 级别潜力** 的方向，也是单发射核继续抬高 IPC 的最后高收益区间。

## 阶段 2：为更高 issue 宽度做结构准备

### 目标

把当前 CPU 从“高性能单发射核”推进成“具备双发射前提条件的顺序核”。

### 主要任务

1. 统一 EXU backend 的 request / complete / flush 语义
2. 明确 EXU→WBU 的正常 pipe latency 与真 stall
3. 明确 COP / future vector backend 的接入边界
4. 让 performance counters 区分：
   - normal pipe occupancy
   - true backend block
5. 引入更明确的 issue boundary，避免“当前拍 decode、当前拍 accept、下一拍 commit”这些边界混杂
6. 明确以后 2-wide issue 时哪些结构必须扩展：
   - IFU fetch width
   - IDU decode width
   - Register file read/write 端口
   - EXU/WBU commit bandwidth

### 预期收益

短期跑分不一定最大，但它决定后面能不能真的向 IPC 2 迈进，而不是被当前单发射结构卡死。

## 阶段 3：前后端解耦与局部并行

### 目标

在不立刻上 2-wide 的情况下，先让前端和后端不再彼此死死绑住，为双发射创造稳定环境。

### 主要任务

1. fetch / decode 小队列
2. 轻量级 scoreboard
3. store buffer / memory request tracking
4. 将 COP / future vector memory 接口整理成 service model
5. 统一 kill / flush / exception 传播方式

### 预期收益

这一步的收益不是马上把 IPC 拉到 2，而是让“同时让两类工作并行存在”成为可能。

## 阶段 4：进入双发射顺序核

### 目标

正式进入 **2-wide in-order**，这是 IPC 2 目标的必要阶段。

### 主要任务

1. IFU 至少 2-wide fetch / predecode
2. IDU 至少 2-wide decode / dispatch
3. Register file / bypass / scoreboard 支持双发射依赖检查
4. EXU 后端支持两条指令并行存在：
   - ALU + branch
   - ALU + LSU
   - ALU + MUL
5. WBU 至少 2-result commit，或者等价的双返回通路
6. 分支和访存冲突规则明确定义

### 预期收益

这一阶段完成后，IPC 目标才真正从“接近 1”切换到“可以实质性冲击 2”。

## 阶段 5：面向 IPC 2 的整体验证

### 目标

验证双发射顺序核在真实 workload 下是否能稳定逼近 IPC 2，而不是只在微基准上漂亮。

### 主要任务

1. 构建不止 CoreMark 的 benchmark matrix
2. 区分：
   - integer ALU heavy
   - branch heavy
   - load/store heavy
   - mul/div heavy
   - cop/vector mixed
3. 验证 issue 利用率、commit 利用率、bypass 覆盖率、queue occupancy

### 预期收益

这一阶段输出的不是单个 patch，而是对“IPC 2 目标是否真的可行”的系统性回答。

## 六、A/B 分工

## A 线：Backend Performance And Integration

A 线负责：

1. EXU / LSU / MUL / DIV / WBU / top-level integration
2. performance counters 和 CoreMark 基准
3. backend 语义统一
4. 与 COP / vector memory 的 CPU 侧集成

### A 线当前阶段任务

#### A-1：清洗 `Other backend`

目标：把 `Other backend` 从“混合残项”拆成：

- normal EXU→WBU pipe latency
- true backend blocked
- mul-high / cop / residual

这仍然是 A 线当前最直接的工作，而且已经确认：这一桶当前大头不是 MUL 或 COP，而是普通 `ALU/other` 指令的正常一拍传递。

#### A-2：统一 backend 接口语义

把 LSU、MUL、DIV、COP 的完成/提交/flush 语义进一步统一，为未来 vector memory 接入准备。

#### A-3：评估 scalar LSU 向 service model 演进

不是再做快路径，而是开始考虑更清晰的 request / response 模型。

## B 线：Frontend Performance

B 线负责：

1. IFU / IDU / IFU-IDU / IDU-EXU pipeline 边界
2. BTB / RAS / predictor 策略
3. redirect recovery 路径
4. frontend stall 根因和对应 RTL 改进

### B 线当前阶段任务

#### B-1：BTB miss rate reduction

这是 B 当前最重要的任务。

目标：降低 780K mispredicts。

交付标准：

- behavioral RTL patch
- B-line gate PASS
- CoreMark 数据

#### B-2：redirect recovery -1 cycle

前提：必须证明是真正缩短了恢复链，而不是只改变统计或引入无效 NOP。

之前 `skip_pre_valid` 方案无效，原因是 `ifu_idu_regs` 的 valid 与 payload 时序不对齐。后续新方案必须直接解决这个结构问题。

#### B-3：frontend counter cleanup

辅助 A 一起把 redirect bubble、icache miss、normal refill 这几类前端事件继续拆干净。

## 七、阶段化 A/B 任务映射

### 阶段 1（当前）

- A：清洗 `Other backend`，定义 normal occupancy vs true stall
- B：BTB miss reduction + redirect recovery

### 阶段 2

- A：backend 接口统一、WBU/commit 语义清晰化
- B：IFU/IDU/issue boundary 清晰化，准备更宽 issue

### 阶段 3

- A：memory service model、store buffer、COP/vector memory 接口
- B：fetch/decode queue、frontend decoupling、predictor 与 queue 协同

### 阶段 4

- A：双发射 backend / dual writeback / bypass matrix
- B：双发射 frontend / dual decode / issue arbitration

## 八、跳出分工框架后的真正优先级

如果完全不考虑 A/B 分工，只从全局收益排序，当前最合理的顺序是：

1. **修正 stall 统计口径**，把真 stall 和正常在飞分开
2. **减少 redirect 次数**（BTB / predictor）
3. **减少 redirect 单次成本**（recovery 3→2）
4. **统一 backend / memory / flush 语义**
5. **为 future vector memory / RVV 迁移留自然接口**

也就是说：

- 眼前最大的性能收益仍在前端
- 真正决定长期上限的，是结构边界是否清晰

## 九、结论

HelloCPU 的长期路线已经从“继续抠 LSU”转变成：

1. 先解决 redirect 相关的大头
2. 再把 backend 语义和统计口径理清
3. 最后把 CPU 结构演进成能自然接 vector / RVV 的成熟顺序核

当前主阶段不是“哪里都能提点分”，而是很明确：

- **B 线主攻 frontend / predictor / redirect**
- **A 线主攻 backend 语义清理和 future interface**

如果长期目标明确为 **IPC ≥ 2**，那么后续路线就必须承认：

1. 当前单发射核只能作为过渡阶段继续榨干；
2. 真正到 IPC 2，必须进入 **2-wide in-order** 或等价结构跃迁；
3. 现在做的所有 frontend/backend/interface 清理，都是在为那一步降低风险，而不是可有可无的“整理代码”。

这两条线如果都走通，HelloCPU 才会从“已经很快的教学核”进一步演进成“结构清晰、可持续优化、可扩展”的成熟核心。
