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

当前稳定点：`codex/b-line-predictor-rtl` on top of `41b0734`

当前 CoreMark `ITER=100`：

| Metric | Value |
|--------|-------|
| CoreMark/MHz | 3.031 |
| Total cycles | 32,990,370 |
| IPC | 0.928 |
| Stall rate | 7.2% |

当前 stall 构成：

| Source | Cycles | % of stalls | 说明 |
|--------|--------|-------------|------|
| Frontend/empty | 1,841,129 | 77.6% | 仍主要是 redirect 之后的前端空泡 |
| Control recovery | 521,535 | 22.0% | 单次 redirect 成本已降到 `2-cycle` |
| Other blocked backend | 0 | 0.0% | 当前统计下已不是热点 |
| LSU wait | 6,832 | 0.3% | 已基本解决 |
| DIV wait | 2,962 | 0.1% | 已基本解决 |

### 当前最重要的全局结论

1. **LSU 已不是主瓶颈。** same-cycle load/store hit 已经把 LSU 从 6.98M cycles 降到 6.8K。
2. **redirect recovery 3 -> 2 已经兑现。** 当前 `Redirect cost = 2 avg cycles`，说明这条 recovery 主线已经从“待验证假设”变成了“已验证收益”。
3. **剩余大头仍在 redirect 链，但更偏向“减少剩余方向错误次数”。** `Frontend/empty + Control recovery` 仍然占几乎全部 true stall。
4. **“Other backend” 目前不能直接当成性能热点。** 当前统计已经给出 `Other blocked backend = 0`。
4. 后续优化不应再继续以 LSU 局部 patch 为主，而应转向：
   - 前端预测与恢复；
   - backend 语义清晰化；
   - 面向未来向量扩展的统一接口。

### 重要决策原则

当前需要明确一个工程判断：

> **“它是最大瓶颈” 不等于 “优化它一定高回报”。**

对当前的 frontend / redirect 主线，必须同时满足三个条件，才值得继续投入：

1. **可压缩性明确**：要先证明减少的是哪一部分真实成本，而不是统计口径或结构表象；
2. **中间指标可验证**：不仅看 CoreMark 总分，还要看 mispredict、redirect avg cycles、frontend bubble 是否真的下降；
3. **长期结构不被破坏**：不能为了一个短期 patch 破坏 future dual-issue、COP memory、vector memory 的边界清晰度。

这意味着：

- frontend / redirect 仍然是当前最高优先级；
- 但 `redirect recovery -1 cycle` 这件事已经完成，下一步不应继续在同一处反复打补丁；
- 后续必须用“先证明，再投入”的方式推进，而不是因为它最大就持续猛砸。

因此整体策略应该是：

1. 继续探索 redirect 主线，但重点从“缩短单次恢复”切到“减少剩余方向错误次数”；
2. 同时并行推进 backend / memory / interface 清晰化；
3. 避免把所有工程精力都押在一个可能回报快速递减的热点上。

### 当前已验证的 redirect ROI 样例

在 `8837032` 之后，B 线按“先证明，再投入”的方式完成了一轮 frontend 验证：

1. 先给 branch mispredict 增加了更细分的归因计数：
   - `pred NT -> actual taken`
   - `pred taken -> actual NT`
   - `target bad`
2. CoreMark `ITER=100` 基线结果表明：
   - `BTB mispredicts = 780,786`
   - `target bad = 0`
   - 说明当前 branch redirect 的主问题是 **direction**，不是 branch target 计算错误。
3. 基于这个证明，B 没有继续扩大 BTB 或修改前后端边界，而是采用更小结构代价的方案：
   - 保留现有 tagged BTB target cache；
   - 仅在 BTB miss 时，引入独立 BHT 作为 direction fallback。

该实验的结果：

- CoreMark/MHz `2.853 -> 2.861`
- IPC `0.874 -> 0.876`
- `Frontend/empty 2,005,006 -> 1,971,153`
- `Control recovery 795,702 -> 775,077`
- `BTB mispredicts 780,786 -> 760,013`

这轮实验之所以符合 ROI 原则，不是因为“frontend 最大”，而是因为它同时满足：

- **可压缩性明确**：先证明当前问题属于 direction，而不是 target/统计口径；
- **中间指标真实下降**：mispredict、control recovery、frontend bubble 都下降；
- **结构边界未被破坏**：未改 IFU/IDU/IDU-EXU 协议，也未破坏 future dual-issue / COP memory / vector memory 的接口清晰度。

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

- redirect recovery 3-cycle → 2-cycle（已验证完成）；
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

## 阶段 1：把当前单发射核做到接近上限（接近收尾）

### 目标

把当前单发射核的明显浪费尽可能清掉，让 IPC 从当前 `0.928` 继续向 `~1.0` 靠近。

### 主要任务

1. 降低剩余 BTB-hit direction miss / mispredict
2. 精确区分 frontend bubble、control recovery、normal pipeline occupancy
3. 维持 redirect / flush / valid 语义稳定，避免回归
4. 分清 `Other backend` 中哪些是“真 stall”，哪些只是正常 EXU→WBU latency

### 预期收益

这是当前仍可继续挖的小收益方向，但已经不再适合作为主战场。单发射核继续抬高 IPC 的空间还在，但回报曲线已经明显变陡。

## 阶段 2：为更高 issue 宽度做结构准备（当前主阶段）

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

### 阶段切换判断

当前已经满足从“单发射局部优化”切向“2-wide 前置准备”的条件：

1. LSU 和 redirect recovery 这类大颗粒收益已经兑现；
2. 剩余前端收益主要是 `BTB-hit` 上的方向细修，属于 `1%~3%` 级别空间；
3. 当前 `IPC = 0.928`，已经接近单发射顺序核的高位区间；
4. 后续收益越来越像“为 CoreMark 局部热点定制”，不再像全局结构收益；
5. 长期目标已经明确是 `IPC >= 2`，因此更应该优先把 issue / flush / commit / queue 边界准备好。

因此，从现在开始：

- 保留低风险、小步、可快速证伪的前端补充优化；
- 但主精力切到 2-wide 前置准备，不再把 branch hit-rate 微调当成主线。

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

当 A/B/C 三线并行导致接口同步和整体验进方向成为瓶颈时，引入 D 线负责 architecture / integration control。D 线职责见 `docs/cpu/d-line-architecture-integration.md`。

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

当前 A 线的基线文档是 `docs/interface/cpu-memory-service-model.md`，后续 scalar LSU、COP memory、future vector memory 的 CPU 侧边界统一以该文档为参考。

## B 线：Frontend Performance

B 线负责：

1. IFU / IDU / IFU-IDU / IDU-EXU pipeline 边界
2. BTB / RAS / predictor 策略
3. redirect recovery 路径
4. frontend stall 根因和对应 RTL 改进

### B 线当前阶段任务

当前 B 线已经从“active frontend performance mode”切到“2-wide 前置准备 mode”。前端性能优化不停止，但降级为辅助线，而不是主战场。

#### B-1：IFU/IDU/issue boundary formalization

这是 B 当前第一优先级。

目标：把 frontend 关键边界整理成能支撑更宽 issue 的稳定 contract：

- `IFU/IDU`
- `IDU/EXU`
- redirect / flush / kill
- accepted payload / registered valid
- future fetch/decode queue insertion points

#### B-2：frontend queue and decoupling preparation

目标：在不立刻上 2-wide 的前提下，定义最小 frontend decoupling 方案：

- fetch queue 是否需要、深度多少
- decode queue 是否需要、深度多少
- flush 时 queue 清空语义
- predictor 与 queue 的 metadata 绑定方式

#### B-3：predictor refinement as secondary work

目标：只在低风险且可快速证伪的前提下，继续观察剩余 `BTB-hit` direction miss 是否还有便宜收益。

当前约束：

- 不再把 hit-rate 微调作为当前主线；
- 不允许 predictor 微调阻塞 2-wide 前置准备。

#### B-4：benchmark matrix for wider-issue decision

目标：补齐不止 CoreMark 的 benchmark 观察面，为后续是否正式进入 2-wide RTL 提供证据。

至少区分：

- branch heavy
- load/store heavy
- integer ALU heavy
- mul/div heavy
- cop/vector mixed

## 七、阶段化 A/B 任务映射

### 阶段 1（收尾）

- A：收尾 true stall / normal occupancy 口径
- B：保留小步 predictor 补充优化，避免回归

### 阶段 2（当前）

- A：backend 接口统一、WBU/commit 语义清晰化
- B：IFU/IDU/issue boundary 清晰化，准备更宽 issue

### 阶段 3

- A：memory service model、store buffer、COP/vector memory 接口
- B：fetch/decode queue、frontend decoupling、predictor 与 queue 协同

其中 memory service model 的当前文档入口为 `docs/interface/cpu-memory-service-model.md`。

### 阶段 4

- A：双发射 backend / dual writeback / bypass matrix
- B：双发射 frontend / dual decode / issue arbitration

## 八、跳出分工框架后的真正优先级

如果完全不考虑 A/B 分工，只从全局收益排序，当前最合理的顺序是：

1. **为 2-wide 做前后端边界准备**
2. **统一 backend / memory / flush 语义**
3. **构建更广 benchmark matrix**
4. **保持 stall 统计口径稳定**，避免假回归 / 假优化
5. **仅作为辅助线继续观察剩余 BTB-hit direction quality**

也就是说：

- 单发射继续抠分还有空间，但已经不是主矛盾
- 真正决定长期上限的，是结构边界是否清晰，以及是否能平滑过渡到更宽 issue

## 九、结论

HelloCPU 的长期路线已经从“继续抠 LSU”进一步转变成：

1. 保留小步、低风险的前端补充优化
2. 主精力切到 2-wide 前置准备
3. 同时把 backend 语义和统计口径维持清晰
4. 最后把 CPU 结构演进成能自然接 vector / RVV 的成熟顺序核

当前主阶段不是“哪里都能提点分”，而是很明确：

- **B 线主攻 2-wide 前置准备、frontend boundary、queue / issue 准备**
- **A 线主攻 backend 语义清理和 future interface**

如果长期目标明确为 **IPC ≥ 2**，那么后续路线就必须承认：

1. 当前单发射核只能作为过渡阶段继续榨干；
2. 真正到 IPC 2，必须进入 **2-wide in-order** 或等价结构跃迁；
3. 现在做的所有 frontend/backend/interface 清理，都是在为那一步降低风险，而不是可有可无的“整理代码”。

这两条线如果都走通，HelloCPU 才会从“已经很快的教学核”进一步演进成“结构清晰、可持续优化、可扩展”的成熟核心。
