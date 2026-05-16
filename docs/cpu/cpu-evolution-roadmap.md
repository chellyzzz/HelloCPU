# HelloCPU CPU 演进路线文档

## 一、文档目标

本文档从**整体性能优化**角度描述 HelloCPU 的长期演进路线，而不是只盯住某一个局部热点。

目标有三层：

1. 持续提高当前标量 CPU 的真实性能；
2. 逐步把微架构从“局部 patch 驱动”推进到“边界清晰、结构稳定”；
3. 为未来的 COP / RVV / vector memory 扩展预留自然接口。

本文档现在是**单人统筹的 CPU 优化主路线图**。旧工作流已清理，不再作为当前入口。

本文档同时给出：

- 当前阶段判断；
- 长期优化主线；
- 分阶段目标；
- 分阶段职责映射。

## 二、长期性能目标

当前需要明确一个现实约束：

> **在当前单发射、顺序、单结果提交的标量核框架下，IPC 不可能长期达到 2。**

因此，如果长期目标是 **`IPC >= 2`**，那么这已经不是“继续做局部优化”的问题，而是要明确进入新的微架构阶段。

这意味着：

1. 短期目标不再是单纯抬高当前单发射核的 IPC 上限；
2. 中期要把当前核心演进成“可双发射、可解耦、可扩展”的结构；
3. 长期要接受如下事实：
   - `IPC ~0.8 -> 1.0` 已经是单发收尾区，继续堆局部优化性价比很低；
   - `IPC > 1.0` 需要进入多发结构阶段，而不是继续死磕单发微调；
   - **`IPC >= 2` 基本要求至少 2-wide in-order issue/commit 能力**，或者等价的更强结构并行性。

所以本文档后续路线分为两层：

- **阶段 1：单发收尾，冻结局部微调收益；**
- **阶段 2：直接进入多发准备，并推进到双发射顺序核。**

## 三、当前统一状态

当前稳定点：`master@7ec84cc`
当前工作分支：`codex/lane1-future-contract`
当前统筹方式：单人 owner。
最新已验证收口：

- `pair_dispatch` 只接 fireable future-lane 候选
- blocked visible pairs 继续停在 `pair_handoff`
- `top_slot1_observability`、`top_pc_update_flush`、`backend_contract_checks` 保持绿色

### 冻结性能参考

下面的 `ITER=100` 结果仍是当前性能对照基线：

| Metric | Value |
|--------|-------|
| CoreMark/MHz | 3.098 |
| Total cycles | 32,279,748 |
| IPC | 0.883 |
| Stall rate | 11.7% |

当前 stall 构成：

| Source | Cycles | % of stalls | 说明 |
|--------|--------|-------------|------|
| Frontend/empty | 3,486,137 | 92.5% | 仍主要是 redirect 之后的前端空泡 |
| Control recovery | 271,994 | 7.2% | 仍是主要的恢复成本来源 |
| Other blocked backend | 0 | 0.0% | 当前统计下已不是热点 |
| LSU wait | 7,562 | 0.2% | 已不再是主瓶颈 |
| DIV wait | 2,832 | 0.1% | 已不再是主瓶颈 |

### 当前最重要的全局结论

1. **单发优化已经进入收尾区。** CoreMark 仍能维持 `3.098 CoreMark/MHz`，但继续在分支/恢复上抠小分已经不再是主战场。
2. **多发准备应该成为主线。** `IPC 0.928` 说明单发已经到高位区，下一步的主要收益只能来自结构跃迁。
3. **当前剩余工作重点是多发前置条件。** 包括边界收口、queue、scoreboard、RF/commit 带宽和验证矩阵。
4. **“Other backend” 目前不能直接当成性能热点。** 当前统计已经给出 `Other blocked backend = 0`。
5. 后续优化不应再继续以 LSU 或分支微调为主，而应转向：
   - 多发边界与 issue contract；
   - backend 语义清晰化；
   - 面向未来向量扩展的统一接口。

### Latest Validation Snapshot

- `make bench_only ITER=100`: PASS, `3.098 CoreMark/MHz`, `32279748` cycles, `0.883 IPC`, `11.7%` stalls, redirect cost `2 avg cycles`.
- `make run ALL=quick-sort`: PASS, `4340` cycles, `0.690 IPC`, `31.0%` stalls, redirect cost `3 avg cycles`.
- Takeaway: the single-owner boundary cleanup is still safe; CoreMark improved about `+5.4%` over the previous freeze, while quick-sort remains control-heavy and still needs frontend/bubble reduction.
- The `pair_dispatch` fireable-only contract did not introduce a regression on either workload.

### 重要决策原则

当前需要明确一个工程判断：

> **“它是最大瓶颈” 不等于 “优化它一定高回报”。**

对当前的 frontend / redirect 主线，必须同时满足三个条件，才值得继续投入：

1. **可压缩性明确**：要先证明减少的是哪一部分真实成本，而不是统计口径或结构表象；
2. **中间指标可验证**：不仅看 CoreMark 总分，还要看 mispredict、redirect avg cycles、frontend bubble 是否真的下降；
3. **长期结构不被破坏**：不能为了一个短期 patch 破坏 future dual-issue、COP memory、vector memory 的边界清晰度。

这意味着：

- frontend / redirect 仍然要稳住，但不再是主战场；
- `redirect recovery` 已经足够好，继续挖单发分支收益的 ROI 很低；
- 后续必须把主精力转到多发结构准备，而不是因为局部指标还可抠分就继续猛砸。

因此整体策略应该是：

1. 立即把主线从单发优化切到多发准备；
2. 同时并行推进 backend / memory / interface 清晰化；
3. 避免把所有工程精力都押在一个已经接近上限的热点上。

### 当前已验证的 redirect ROI 样例

在 `8837032` 之后，项目按“先证明，再投入”的方式完成了一轮 frontend 验证：

1. 先给 branch mispredict 增加了更细分的归因计数：
   - `pred NT -> actual taken`
   - `pred taken -> actual NT`
   - `target bad`
2. CoreMark `ITER=100` 基线结果表明：
   - `BTB mispredicts = 780,786`
   - `target bad = 0`
   - 说明当前 branch redirect 的主问题是 **direction**，不是 branch target 计算错误。
3. 基于这个证明，没有继续扩大 BTB 或修改前后端边界，而是采用更小结构代价的方案：
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

### 主线 1：减少“发生多少次慢恢复”

这条线本质上是**降低 redirect 次数**：

- 提高 BTB 有效命中率；
- 改进 branch target / direction 覆盖；
- 减少无谓的后级 redirect；
- 让 predictor 学到更多真实分支行为。

这是“减少问题发生次数”的路线。

### 主线 2：减少“每次慢恢复要花多久”

这条线本质上是**降低 redirect 单次成本**：

- redirect recovery 3-cycle → 2-cycle（已验证完成）；
- flush / refill 边界更轻；
- IFU/IDU/IDU-EXU 的恢复路径更短。

这是“单次事故代价更低”的路线。

### 主线 3：减少“正常流水也被算成等待”

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

## 阶段 1：单发收尾

### 目标

把当前单发射核的最后一点结构噪声收干净，但不再把继续抬高单发 IPC 当成主目标。

### 主要任务

1. 冻结单发主收益，不再为小分数继续扩大战线
2. 精确区分 frontend bubble、control recovery、normal pipeline occupancy
3. 维持 redirect / flush / valid 语义稳定，避免回归
4. 分清 `Other backend` 中哪些是“真 stall”，哪些只是正常 EXU→WBU latency

### 预期收益

这个阶段的主要价值是收尾和冻结，而不是继续追求单发跑分。它的意义在于给多发准备让路。

## 阶段 2：多发准备（已完成）

### 目标

把当前 CPU 从“接近单发上限”推进成“具备双发射前提条件的顺序核”。

### 主要任务

1. 统一 EXU backend 的 request / complete / flush 语义
2. 明确 EXU→WBU 的正常 pipe latency 与真 stall
3. 明确 COP / future vector backend 的接入边界
4. 让 performance counters 区分：
   - normal pipe occupancy
   - true backend block
5. 引入更明确的 multi-issue boundary，避免“单发 valid”与“第二发 ready”混在一起
6. 明确以后 2-wide issue 时哪些结构必须扩展：
   - IFU fetch width
   - IDU decode width
   - Register file read/write 端口
   - EXU/WBU commit bandwidth
   - scoreboard / hazard matrix

### 预期收益

短期跑分不一定最大，但它决定后面能不能真的向 IPC 2 迈进，而不是被当前单发射结构卡死。

### 完成判定

阶段 2 现在可以视为完成，理由是：

1. frontend boundary / future-lane contract 已经写清，并且当前非执行 lane-1 contract 已收口到 `pair_dispatch`
2. backend `accept / done / commit-visible` 语义已经统一成文档与 directed gate 的共同基线
3. queue insertion point、第一版 scoreboard scope、pairing matrix、RF / commit 带宽约束都已写成 reviewable plan
4. 第一版 `2-wide` slice 已经定义为可落地的小步路径，而不是宽泛的“以后再说”
5. benchmark 已不再只有 CoreMark，当前至少有 `CoreMark ITER=100` 和 `quick-sort` 两个参考点

### 阶段切换判断

当前已经满足从“单发收尾”切向“2-wide 前置准备”的条件：

1. LSU 和 redirect recovery 这类大颗粒收益已经兑现；
2. 当前 `IPC = 0.928` 已经接近单发射顺序核的高位区间；
3. 后续收益越来越像“为局部 workload 做末端微调”，不再像全局结构收益；
4. 长期目标已经明确是 `IPC >= 2`，因此更应该优先把 issue / flush / commit / queue / scoreboard 边界准备好。

因此，从现在开始：

- 只保留低风险维护级前端改动；
- 主精力切到 2-wide 前置准备，不再把 branch hit-rate 微调当成主线。

执行入口见 `docs/cpu/two-wide-preparation-checklist.md`。

## 阶段 3：前后端解耦与局部并行（已完成）

### 目标

在不立刻上 2-wide 的情况下，先让前端和后端不再彼此死死绑住，为双发射创造稳定环境。

### 主要任务

1. fetch / decode 小队列
2. 轻量级 scoreboard
3. store buffer / memory request tracking
4. 将 COP / future vector memory 接口整理成 service model
5. 统一 kill / flush / exception 传播方式

### 具体执行项

#### 3.1 lane-1 real boundary

1. 定义 lane-1 `accept` 语义：什么条件下第二条指令从 `pair_dispatch` 进入真实 backend-adjacent ownership
2. 定义 lane-1 `kill / flush` 语义：slot0 redirect、frontend flush、backend block 时 lane1 如何死亡
3. 决定 lane-1 valid 是独立 bit，还是继续依附 pair-valid contract
4. 把这些语义先写进文档，再写 assertion，再写 RTL

当前最小落地约定：

- `pair_dispatch` 继续保存 dispatch-adjacent payload，但不再把 handoff 时刻拍下来的 `allow_second` 当成唯一执行真相。
- `pair_dispatch_fireable` 是 live wire，由 `pair_dispatch_valid` 和 dispatch-side realtime scoreboard 共同决定；它不是一个被寄存下来、可长期复用的快照。
- `pair_handoff -> pair_dispatch` 的 real accept 现在由 handoff 侧实时 executable scoreboard 决定，而不是由旧的 snapshot fireability 直接驱动。
- lane-1 的真实 live bit 现在是独立的 `lane1_issue_valid`，不再只是依附 `pair_dispatch_valid` 的“有 payload 即算活着”。
- `lane1_issue_accept` 语义：`pair_dispatch` 当前有有效 pair payload，且 dispatch 侧实时 scoreboard 允许第二条进入 live ownership，且当前还没有 live lane1。
- `lane1_issue_kill` 语义：一旦 dispatch 侧实时 scoreboard 因 backend block 或 flush 不再允许该 payload，`lane1_issue_valid` 在下一拍清掉。
- `frontend_flush` 仍然有最高优先级，会直接杀死 `pair_handoff`、`pair_dispatch` 和 `lane1_issue_valid`。

#### 3.2 decode / dispatch decoupling

1. 决定 decode queue 是否真的落地，以及第一版深度
2. 明确 queue entry 里需要保存的 payload、predictor metadata、predecode sidecar
3. 明确 queue 的 flush / replay / hold 语义
4. 决定 real dispatch boundary 是在 `pair_dispatch` 之后新增寄存器，还是把 `pair_dispatch` 自身演进成真实 boundary

当前状态：已完成最小落地，真实 dispatch boundary 继续收口在 `pair_dispatch` / `lane1_issue_valid`，decode queue 暂不引入。

#### 3.3 first executable scoreboard

1. 把当前草案 hazard matrix 收敛成可执行规则
2. 固化第一版 `RAW / WAW / exclusive owner / redirect-hostile` reject policy
3. 明确第一版允许和禁止的 pairing classes
4. 决定 scoreboard 只看 slot-local pairing，还是同时看长延迟 owner busy

当前第一版 executable scoreboard 约定：

- scope 仍然保持最小：slot-local `RAW/WAW`、single writeback pressure、exclusive backend owner、redirect-hostile control、一个 runtime busy view。
- pairing class 仍然只允许最窄的 `older simple ALU + younger conditional branch`。
- runtime busy view 当前先取 `exu2idu_ready` 和 `cop_pipeline_active`，不假装已经支持更宽的 backend occupancy model。
- handoff 侧 scoreboard 负责决定 `pair_dispatch_accept`；dispatch 侧 scoreboard 负责决定 `lane1_issue_valid` 的 live / kill。

#### 3.4 memory and service decoupling

1. 明确 scalar memory 在 stage 3 是否仍保持 single-entry owner
2. 决定 store buffer / request tracking 是文档先行还是最小 RTL skeleton 先行
3. 统一 scalar / COP / future vector memory 对 `request / pending / visible / killed` 的解释
4. 确保 stage 3 不会误把 memory overlap 伪装成已经支持 dual-issue

当前状态：已完成 V1 收口，scalar / COP / future vector 继续共享同一 single-owner memory service，且不引入 store buffer 或 dual ownership。

#### 3.5 implementation and validation gates

1. 为真实 lane1 boundary 增加 directed test
2. 为 scoreboard reject / allow cases 增加 directed pairing tests
3. 为 queue flush / kill / replay 增加 top-level coverage
4. 为 dual-issue candidate workload 增加 benchmark observation point

### 建议顺序

1. 先完成 `3.1 lane-1 real boundary`
2. 再完成 `3.3 first executable scoreboard`
3. `3.2 decode / dispatch decoupling` 的最小落地点已确定并落在 `pair_dispatch` / `lane1_issue_valid`
4. `3.4 memory and service decoupling` 的最小落地点已确定并落在 V1 single-owner memory service
5. 最后用 `3.5 implementation and validation gates` 固化阶段结果

### 完成判定

阶段 3 完成时，至少应满足：

1. lane-1 已经有真实 `accept / kill / flush` 语义，不再只是 observability sink
2. 第一版 scoreboard / pairing matrix 已经变成 executable policy
3. decode / dispatch decoupling 的最小实现边界已确定并落地
4. stage-3 memory/service decoupling 约束已写清，且没有假装进入 memory overlap
5. directed tests 能覆盖 allow / reject / flush / replay / stale-kill 的关键路径

### 最小验证门

1. `make top_slot1_observability EXTRA_VERILATOR_FLAGS='-j 1'`
2. `make top_pc_update_flush EXTRA_VERILATOR_FLAGS='-j 1'`
3. `make backend_contract_checks EXTRA_VERILATOR_FLAGS='-j 1'`
4. 新增的 lane1 / pairing directed tests
5. `make bench_only ITER=100`
6. 至少一个 branch-heavy 或 mixed workload benchmark

### 预期收益

这一步的收益不是马上把 IPC 拉到 2，而是让“同时让两条指令在同一拍并行存在”成为可能。

### 阶段结论

阶段 3 的完成判定已经满足：

1. lane-1 已经有真实 `accept / kill / flush` 语义，不再只是 observability sink
2. 第一版 scoreboard / pairing matrix 已经变成 executable policy
3. decode / dispatch decoupling 的最小实现边界已确定并落地
4. stage-3 memory/service decoupling 约束已写清，且没有假装进入 memory overlap
5. directed tests、flush gates 和 benchmark checkpoints 都已通过

因此，阶段 3 现在视为完成，后续主线转入阶段 4。

## 阶段 4：进入双发射顺序核

### 目标

正式进入 **2-wide in-order**，这是 IPC 2 目标的必要阶段。

### 阶段 4 路线

阶段 4 不追求“一步到位的全面双发”，而是按最小可用切片逐步扩宽：

1. `4.1` 前端宽化先行
   - 把 `2-wide fetch/predecode` 落成真实结构，而不是只保留观测面
   - 保持 slot1 仍然是 flush-safe、non-executing 的前端真值面
   - 不新增 decode queue，不改变当前单发 execute/commit 行为
2. `4.2` decode / issue 传输边界收紧
   - 明确从前端双宽 surface 到 `pair_dispatch` 的真实 transport contract
   - 继续保持 `pair_dispatch` 只是 payload store，直到更宽 issue 真的需要
   - 保留 `visible / blocked / flushed` 的可验证分解
3. `4.3` 第一组合法 pairing 落地
   - 只放行 `older ALU + younger branch`
   - scoreboard / hazard / flush / kill 规则继续作为唯一发射门
   - 明确拒绝 `ALU + ALU`、`ALU + LSU`、`ALU + MUL`、`ALU + COP` 以及 redirect-hostile pairing
4. `4.4` commit / writeback 带宽补齐
   - 先确保现有单发主线不被双宽前端扰动
   - 再决定 WBU 是双结果提交，还是等价的分阶段提交 / staging
   - 只有当 pairing 真正成立时，才扩大 commit-side bandwidth
5. `4.5` 验证与基准矩阵闭环
   - directed tests 覆盖 allow / reject / flush / replay / stale-kill
   - benchmark matrix 至少包含 CoreMark、branch-heavy、load/store-heavy、ALU-heavy、mul/div-heavy、cop/vector mixed
   - 用这些 workload 判断阶段 4 的宽化是否真的带来结构收益

### 预期收益

这一阶段完成后，IPC 目标才真正从“接近 1”切换到“可以实质性冲击 2”。

### 完成判定

阶段 4 完成时，至少应满足：

1. `2-wide fetch/predecode` 已经是稳定的真实结构，不再只是前端观测面
2. `pair_dispatch` / `lane1_issue_valid` 的边界能支撑真实的第一组合法 pairing
3. `ALU + branch` 是唯一放行的 v1 pairing，其他 pairing 仍明确拒绝
4. commit / writeback 宽度已经和新的 issue 形态匹配
5. directed tests 和 benchmark matrix 都能稳定说明结构收益，而不是只在单一 workload 上成立

Current branch validation on 2026-05-17:

- `CoreMark ITER=100` revalidated at `3.098 CoreMark/MHz` and `32,279,748` simulator cycles
- `quick-sort`, `load-store`, `sum`, `div`, and `rvv-acceptance-subset` all passed as local workload proxies for the branch-heavy, load/store-heavy, ALU-heavy, mul/div-heavy, and cop/vector-mixed categories
- the Embench checkout is not available on this host, so the repository tests above act as the local wider-matrix proxy until that source tree is restored

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

## 六、统一职责

现在只有一个 owner，统一负责 frontend、backend、integration 和未来扩展边界。

当前职责分成四块，而不是两条分裂工作线：

1. **frontend boundary / issue contract**
   - `IFU/IDU`
   - `IDU/EXU`
   - redirect / flush / kill
   - future fetch/decode queue insertion points
2. **backend semantic cleanup**
   - `accept / done / commit-visible`
   - `Other blocked backend` 与正常 pipe occupancy 口径
   - scalar / COP / future vector memory 边界一致化
3. **multi-issue preparation**
   - fetch/decode queue
   - scoreboard / hazard matrix
   - RF 读写端口
   - WBU / commit 带宽
4. **benchmark and validation matrix**
   - CoreMark
   - branch-heavy
   - load/store-heavy
   - integer ALU-heavy
   - mul/div-heavy
   - cop/vector mixed

当接口同步和整体验进方向成为瓶颈时，引入 D 线负责 architecture / integration control。D 线职责见 `docs/cpu/d-line-architecture-integration.md`。

## 七、阶段化执行

### 阶段 1（当前收尾）

- 冻结单发微调收益，不再把 branch hit-rate refinement 当成主线
- 保持当前 gate 和 benchmark 基线稳定
- 只修真正阻塞多发准备的问题

### 阶段 2（已完成）

- 完成 frontend boundary / future-lane contract 收口
- 完成 backend `accept / done / commit-visible` 统一语义
- 明确 queue / scoreboard / RF / commit 的第一版约束
- 把 `2-wide` 的第一刀切成足够小的可落地 slice

### 阶段 3（已完成）

- 引入 fetch/decode decoupling
- 写清第一版 pairing matrix
- 明确 dual-issue 下的结构冲突与 kill/flush 规则
- 准备 dual-issue 所需的读写带宽与 bypass 方案

### 阶段 4（正式进入双发）

- 先落地 `2-wide fetch/predecode` 的真实结构
- 再收紧 `pair_dispatch` 到真实 decode / issue transport 边界
- 只放行 `older ALU + younger branch` 的第一版合法 pairing
- 最后补齐 commit / writeback 带宽和验证矩阵

## 八、当前优先级

如果只按 ROI 排序，当前最合理的顺序是：

1. **为 2-wide 做前后端边界准备**
2. **统一 backend / memory / flush 语义**
3. **定义 scoreboard / hazard matrix / RF 带宽**
4. **构建更广 benchmark matrix**
5. **只保留少量维护级单发修补**

也就是说：

- 单发继续抠分还有一点空间，但已经不是主矛盾
- 真正决定长期上限的，是结构边界是否清晰，以及是否能平滑过渡到更宽 issue

## 九、结论

HelloCPU 的长期路线已经很明确：

1. 单发优化现在进入收尾区
2. 主精力立即切到 2-wide 前置准备
3. backend 语义、memory service、flush/kill 规则继续收口
4. 最终进入成熟的多发顺序核，再谈更高 IPC

如果长期目标明确为 **IPC ≥ 2**，那么后续路线就必须承认：

1. 当前单发射核只能作为过渡阶段；
2. 真正到 IPC 2，必须进入 **2-wide in-order** 或等价结构跃迁；
3. 现在做的所有 frontend/backend/interface 清理，都是在为那一步降低风险，而不是可有可无的“整理代码”。
