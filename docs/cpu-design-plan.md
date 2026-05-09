# HelloCPU CPU 设计规划

## 一、文档目标

本文档专注于 HelloCPU **CPU 本体** 后续一段时间的设计规划。A/B 两条 CPU 优化线的分工、文件边界和进度记录见 `cpu-ab-collaboration.md`。

目标不是泛泛讨论“还可以优化什么”，而是明确：

1. 当前 CPU 的主要问题是什么；
2. 接下来最值得投入的设计主线是什么；
3. 每一阶段要解决哪些结构问题；
4. 如何在不引入过早复杂度的前提下，把 CPU 从“能跑且正确”推进到“结构成熟、性能更高、可扩展性更好”的状态。

---

## 二、当前 CPU 状态判断

HelloCPU 当前已经具备：

- 五级顺序流水；
- RV32IM + Zicsr；
- 4 KB ICache + 4 KB DCache；
- BTB + RAS + static JAL 分支预测；
- CPU tests 全通过；
- CoreMark 正确通过。

当前 `cpu-mainline-branch` 还可以作为向量端回灌 CPU 进展的稳定同步点：

- LSU `load hit`、`store hit` 和 transaction start 快路径已经通过定向与全量回归；
- CoreMark `ITER=100` 当前参考为 `2.381 CoreMark/MHz`、`IPC=0.729`；
- COP 独立后端已经从 `vector-coproc-uarch` 同步到 CPU 主线；
- 连续 COP / RAW 依赖用例 `cop-chain` 已通过；
- 当前最新稳定提交为 `5a5caa9 fix: preserve consecutive cop issue flow`。

因此当前阶段已经不是：

- 补基础功能；
- 修大面积正确性缺口；
- 单纯证明 CPU 能运行。

现在进入的是一个新的阶段：

- 继续提升标量 CPU 的真实性能；
- 把执行、提交、访存、恢复边界理顺；
- 为后续更复杂的执行后端和结构扩展打基础。

---

## 三、当前最主要的问题

从当前 CoreMark 计数器和分析看，CPU 的主要问题不是 cache 容量，也不是总线带宽，而是**流水线内部效率不足**。不过，在 LSU `load hit`、`store hit` 和启动脉冲优化后，这个问题已经明显收敛。

主要表现为：

- `IPC` 已从 `0.473` 提升到 `0.729`；
- `stall cycles` 占比已从 `51.5%` 降到 `25.2%`；
- loads 占比较高，但真实 load AXI 事务极少，说明 load 成本主要来自内部相关和阻塞；
- branch recovery 仍有显著代价，但不是唯一大头；
- MUL / DIV / LSU 这类多周期路径仍会对整条流水造成过强反压。

换句话说，当前 CPU 最大的问题不是“前端供给不够”，而是：

- 后端耦合过紧；
- 结果可用和结果提交边界不够清楚；
- 多周期单元的 busy 容易演化成全局停顿；
- load-use penalty 和旁路能力仍然限制 IPC。

### 当前 stall 分类解释

为了避免只看到一个总的 `stall cycles` 数字、却不知道该先改哪里，当前仿真性能统计已经补充为更细粒度的 stall 分类。

当前建议关注以下 5 类：

- `Frontend/empty`：前端没有向 EXU 提供有效指令，通常意味着 IFU/IDU 供给不足，或者前端被控制流恢复打断后尚未重新填满；
- `LSU wait`：当前 EXU 正在处理 load/store，且 LSU 尚未完成，导致后续流水不能继续前进；
- `MUL/DIV wait`：当前 EXU 正在处理乘除法等多周期运算，结果尚未返回；
- `Control recovery`：分支误预测恢复、`pc_update`、flush 等控制流修复正在消耗周期；
- `Other backend`：后端确实在阻塞，但不属于上面几类，通常用于暴露更隐蔽的握手、旁路或结构耦合问题。

这组分类的价值在于：

- 可以快速判断瓶颈主要在前端、LSU、乘除、还是控制恢复；
- 可以避免在“感觉上最慢”的地方盲目优化；
- 可以把后续每次 RTL 修改和 stall 构成变化直接对应起来。

### 当前分类的使用方式

这组 stall 分类不是最终完美模型，而是当前阶段的**工程化观测切口**。

因此使用时应注意：

- 它的目标是帮助确定“先改哪条主线”，而不是替代更细的波形或 trace 分析；
- `Other backend` 偏大时，通常意味着当前分类还不够细，后续应继续拆分；
- `Frontend/empty` 偏大时，不一定代表 ICache 不够，也可能是后端控制流恢复把前端供给打断；
- `LSU wait` 偏大时，需继续区分是 load hit 返回晚、load-use interlock、store 阻塞，还是 miss/uncached 路径所致。

### 当前初步观测

基于当前 CoreMark `ITER=100` 多循环结果，stall 构成已经显示出一个明确趋势：

- `LSU wait` 仍是当前主导项，占全部 stall 的 `56.0%`；
- `MUL/DIV wait` 已经成为第二个明确后端瓶颈，占全部 stall 的 `15.1%`；
- `Control recovery` 仍有影响，占全部 stall 的 `6.5%`，但不是第一矛盾。

当前又把 `MUL/DIV wait` 拆成了 `MUL` 和 `DIV` 子项，用于区分短延迟乘法和长延迟除法：

- `mul-longlong` 中 `MUL/DIV wait` 为 `34` cycles，全部来自 `MUL`；
- `wanshu` 中 `MUL/DIV wait` 为 `13398` cycles，全部来自 `DIV`；
- 低位 `MUL` 快路径落地后，CoreMark `ITER=100` 中 `MUL/DIV wait` 降到 `3762` cycles，全部来自 `DIV`；
- 因此 `MUL/DIV` 已经不是 CoreMark 第一线瓶颈，DIV 后续更适合作为除法密集程序专项。

进一步把 `LSU wait` 拆开后，可以看到：

- 新增 `start` 子项后，CoreMark `ITER=100` 中 `LSU wait = 6980532`，其中 `start = 6973588`，占 `LSU wait` 的 `99.9%`；
- `start` 子项里 load 占 `5473195` cycles（`78.5%`），store 占 `1500393` cycles（`21.5%`）；
- `refill` 在 CoreMark 中只占 `LSU wait` 的 `0.1%`；
- `uncached` 和 `writeback` 占比很小；
- 因此当前 CoreMark 上剩余 LSU 成本主要不是 AXI refill，而是 cache hit、load-use、请求启动和主流水握手耦合。

基于这组观测，已经做过两轮针对性的 LSU 返回路径实验：

- `load hit` 当前拍完成：已经在 `vsrc/exu/lsu.v` 落地，并通过 `add`、`load-store`、`mem`、`quick-sort` 回归；
- `store hit` 当前拍完成：已经在 `vsrc/exu/lsu.v` 落地，并通过访存、排序和全量 CPU 回归；
- LSU 启动脉冲提前：去掉第二级启动沿检测寄存器后，减少每次 load/store 前的空等周期；CoreMark `ITER=100` 从 `1.545` 提升到 `2.279 CoreMark/MHz`；
- 低位 `MUL` 快路径：普通 `MUL` 直接走 EXU 组合乘法结果，高位 `MULH/MULHSU/MULHU` 与 DIV 仍走原多周期路径；CoreMark `ITER=100` 进一步提升到 `2.381 CoreMark/MHz`；
- `refill` 最后一拍同拍返回：虽然在简单样例上可过，但会破坏 `quick-sort` 正确性，因此当前已明确回退，不作为现阶段可保留优化；
- 连续拉高 refill `RREADY`：会导致 `load-store` 在 refill R data 阶段卡死，也已明确回退。
- LSU 直接用 EXU 当前 `ready` 或 `valid` 启动：会在简单访存或 `quick-sort` 中卡死或跑飞，说明启动条件不能只局部替换；
- `S_IDLE` 同拍 cacheable load-hit 返回：即使只针对 load、不提前 store，也会破坏 `load-store` / `quick-sort`，并可能重复启动或卡在 load start，说明现有 IDU/EXU valid 生命周期与 LSU 内部同拍完成不兼容。

当前可以确认的一点是：`cache hit` 路径和 LSU 请求启动路径确实偏保守，提早一拍能够稳定带来收益；但 `refill -> result` 路径仍然和主流水、写回边界存在更深耦合，不能直接按同样思路激进推进。

这说明当前 LSU 的问题并不只是“外部存储太慢”，还包括：

- cache hit 路径和请求启动路径仍然会造成主流水停顿；
- refill 完成后结果回到主流水的路径需要更保守地重构；
- load-use interlock 很可能仍然过于保守。

不过，围绕 `load-use` 又做过一轮更进一步的试探后，可以确认一个更重要的结构事实：

- 单独放宽一处局部 interlock，并不能稳定释放 `load hit` 提前完成的收益；
- 一旦开始尝试把 `IFU/IDU` 改成更标准的寄存式 `valid` 持有语义，当前主线很容易立即出现跑飞或超时；
- 最近一次仅把 `IFU/IDU` 加 `post_valid`、再连带把 `IDU/EXU` 改成 `!valid || ready` 接收新 payload 的实验，会让 `sum` 跳过 reset / redirect 后的第一条指令，commit trace 中表现为漏掉 `0x30000000` 和 `0x30000b00`，最终 `sum` fail；
- 这说明当前问题已经不只是“某个 hazard 条件写得太保守”，而是前端握手语义、IDU 生命周期、以及 LSU 结果可见边界之间本身存在结构耦合。

因此，`load-use penalty` 虽然仍然是后续重要方向，但它已经不能再被视为一个完全局部的小优化点。继续在现有握手语义上硬调条件，风险会迅速高于收益。后续若再推进 `IFU/IDU` 标准化，需要同时处理 IFU PC 推进、ICache hit/data 与边界寄存器 payload 的同拍对齐关系，而不是只替换某一级的 `valid` 生成逻辑。

这进一步支持当前规划中的优先级判断：

1. 继续做 `LSU / memory subsystem`，但重心从 refill bandwidth 转向 hit/load-use/request-response 语义；
2. 再做 `IFU/IDU` 最小握手标准化；
3. 然后推进 `旁路 + load-use penalty`；
4. 同步评估 `MUL/DIV` 阻塞局部化，因为 CoreMark 上它已经是第二大显式等待来源；
5. 最后再做 `分支恢复时延优化`。

---

## 四、总设计原则

后续 CPU 设计建议遵守以下几条原则。

### 1. 先清结构，再抢跑分

有些优化可以短期加分，但如果继续在现有 EXU/WBU 上堆条件分支和特殊时序，后面会越来越难改。

因此当前更优先的是：

- 明确执行后端边界；
- 明确完成与提交边界；
- 明确 flush / kill / redirect 语义；
- 明确 LSU 的请求/返回语义。

### 2. 减少全局阻塞

后续优化的主线不应再是“一个单元忙，全流水都等”，而应逐步转成：

- 哪个单元忙，哪个单元局部 backpressure；
- 非依赖指令尽量继续前进；
- 让慢路径对整机的影响更局部化。

### 3. 区分结果完成与架构提交

当前很多复杂性来自两个语义混在一起：

- 数据什么时候已经算出来；
- 数据什么时候可以正式提交。

后续 CPU 结构需要逐渐把这两个边界分清，这对于：

- LSU 返回；
- 多周期乘除；
- 分支恢复；
- 后续协处理器接入；

都非常关键。

### 4. 用最小必要结构换最大清晰度

当前不建议一上来就追求：

- dual-issue；
- 有限乱序；
- 大量复杂 queue；
- 完整 scoreboard 全覆盖。

更合理的做法是先用：

- 统一接口；
- 最小在飞项管理；
- 轻量级 queue；
- 局部记分板；

把问题拆开。

---

## 五、主线设计方向

### 方向一：统一执行后端接口

这是 CPU 主线里最基础、也最值得先做的工作。

当前 EXU 里同时挂着：

- ALU；
- Branch；
- LSU；
- Multiplier；
- Divider。

建议逐步把这些单元从“EXU 内部一堆条件分支”重构成更统一的后端模型，至少在设计语义上明确：

- request；
- accept；
- complete；
- writeback metadata；
- status / exception；
- flush / kill。

这项工作短期不一定带来最大跑分提升，但它是后续 LSU、旁路、多周期阻塞优化的基础。

### 方向二：重构 LSU / memory subsystem

这是当前最有希望带来明显收益的一条线。

建议把 LSU 的关注点从“能接 DCache / AXI 就行”升级为：

- load hit 是否能更早可用；
- store 是否必须阻塞主流水直到真正写入；
- 请求和返回能否更明确解耦；
- 命中路径、miss 路径、uncached 路径是否能有清晰边界。

这一阶段最值得考虑的结构是：

- store buffer；
- 更明确的 load return timing；
- 渐进式 request/response 模型；
- 后续可排队 LSU 的接口预留。

### 方向三：强化旁路与依赖处理

对五级顺序单发射核来说，旁路质量几乎直接决定 IPC 上限。

这一方向的重点不是“多做几条转发线”这么简单，而是要更系统地区分：

- 结果已存在；
- 结果可旁路；
- 结果尚未提交但对消费者已足够可见；
- 结果真正还不可用。

建议重点观察：

- EXU -> IDU/RegisterFile 旁路；
- WBU -> IDU/RegisterFile 旁路；
- load hit 提前旁路；
- hazard 检查是否过于保守。

同时需要补充一个当前已确认的工程前提：

- 在现有实现下，`旁路 + load-use` 不能只看 EXU/WBU 数据路径；
- `IFU/IDU` 与 `IDU/EXU` 的握手语义本身，已经会直接影响这类优化能否安全落地；
- 因此这条线的第一步不应再是盲目放宽条件，而应先明确“哪一级持有有效指令、哪一级允许消费、结果在什么时候对消费者可见”。

### 方向四：降低多周期单元的全局阻塞

当前 MUL / DIV / LSU 等慢路径对前级 ready 影响较大。

建议逐步把这类阻塞从“整机停住”收敛成：

- 只拦必须等待的相关指令；
- 不相关的前后端尽可能继续工作；
- 对慢路径做最小在飞项跟踪。

第一阶段未必要做到复杂调度，但至少要做到：

- busy 来源可观测；
- stall 原因可细分；
- issue 拦截条件更精确。

### 方向五：优化分支恢复时延

当前分支预测已经具备可用效果，因此下一步不应优先继续堆 predictor 容量，而是更关注：

- 分支结果能否更早确认；
- 正确预测路径是否仍被晚级过度干扰；
- mispredict 后 redirect 是否还能再缩一拍；
- flush 是否能更轻量。

这条线是重要方向，但建议放在 LSU / 执行接口 / 旁路之后推进。

### 方向六：适度前后端解耦

在前几项逐步清晰之后，可以开始引入最小程度的解耦，例如：

- fetch queue；
- decode queue；
- 更明确的 issue 边界。

目标不是追求乱序，而是减少短期抖动和后端瞬时反压对前端供给的影响。

---

## 六、建议的实施阶段

### 第一阶段：把边界理清

这一阶段的目标不是先追最大性能，而是先把 CPU 结构整理清楚。

建议依次完成：

1. 给执行后端定义统一语义；
2. 明确 EXU 完成与 WBU 提交的边界；
3. 梳理 flush / kill / redirect 的统一控制框架；
4. 补更细粒度 stall 分类计数器；
5. 让 LSU 的请求、返回、写回语义更明确。

其中第 4 项的目标不是“为了多几个统计数字”，而是为了给第 5 项以及后续旁路优化提供可靠依据。

阶段输出应包括：

- 更清晰的 EXU 结构；
- 更清晰的在飞项定义；
- 更可信的 stall 归因数据。

### 第二阶段：做高收益性能优化

在结构清晰后，再做当前最有收益的优化。

建议优先顺序：

1. LSU hit/load-use/request-response 语义继续收敛；
2. `IFU/IDU` 最小握手标准化；
3. load-use penalty 优化；
4. 更强旁路；
5. MUL/DIV 阻塞局部化；
6. branch recovery 时延优化。

这里把 `IFU/IDU` 最小握手标准化前移，不是因为它本身直接带来最大跑分，而是因为当前已经验证：如果不先把这一层的 `valid/ready` 语义理顺，后续 `load-use` 和更激进的旁路优化会持续撞到结构边界。

这一阶段的核心目标是把当前大量 stall 真正打下来，而不是只在某个 benchmark 上碰运气提分。

### 第三阶段：引入结构化扩展能力

等前两阶段稳定后，再考虑进一步扩展 CPU 结构能力。

建议内容：

- fetch/decode queue；
- 轻量级 scoreboard；
- 最小 issue tracking；
- 为协处理器或额外执行后端留自然接口。

这一阶段的目标是把 CPU 从“优化过的顺序核”推进成“结构清晰、可继续演化的顺序核”。

---

## 七、建议的近期优先级

如果只看近期最值得做的几项，建议优先级如下：

1. `LSU / memory subsystem` 继续收敛 hit/load-use/request-response 边界；
2. `IFU/IDU` 最小握手标准化；
3. `旁路 + load-use penalty` 优化；
4. `MUL/DIV` 阻塞局部化；
5. `执行后端接口` 统一；
6. `分支恢复时延` 优化。

这个排序的核心逻辑是：

- 继续压低当前最大的显式 stall 来源，也就是 LSU；
- 尽快把前端握手边界理顺，为 load-use 和旁路优化解除结构限制；
- 在 LSU 收敛后处理已经显现出来的 MUL/DIV 等第二层后端等待；
- 最后处理更统一的后端接口和更远期扩展问题。

这里的“前端问题”当前不再只是性能锦上添花，而是已经被证明会直接限制 LSU 后续优化空间。因此近期更合理的做法不是全面大改前端，而是做一次**最小范围的握手语义标准化**，仅把 `IFU/IDU` 这一级变成真正可持有有效项的寄存器边界。

这一步建议约束为：

1. `o_post_valid` 表示“当前级寄存器持有有效指令”；
2. `i_post_ready` 表示“下游当前拍允许消费”；
3. 只有 `valid && ready` 才消费；
4. `valid` 不再直接组合依赖 `ready`；
5. 第一阶段不同时重构更深级流水，避免把风险扩散到整个前端。

### 分支同步优先级

在继续新结构优化前，建议先把 CPU 主线进展同步回 `vector-coproc-uarch`，让向量端和 CPU 端回到同一个稳定基线。

这次回灌应包含：

1. LSU fast paths 和 start timing 优化；
2. stall / COP / LSU refill 细分性能计数器；
3. CoreMark 结果与 CPU 规划文档更新；
4. COP 独立后端同步后的连续 issue 修正；
5. `cop-chain` 回归用例。

同步时不应同时推进新的 `IFU/IDU` 标准化、真实向量后端或多请求在飞模型。这样可以确保向量端先获得当前 CPU 的稳定性能与验证基线，再在共同基线上继续扩展。

---

## 八、阶段里程碑建议

### 里程碑 C1：执行语义理清

完成标准：

- EXU 子单元边界更明确；
- 完成/提交语义有统一描述；
- stall 分类比现在更细。

### 里程碑 C2：LSU 主线重构完成第一版

完成标准：

- load/store 路径边界清晰；
- store 不再对后续路径产生过多无效阻塞；
- request start 不再额外引入空等拍；
- 有能力继续扩展成 request/response 模型。

### 里程碑 C3：旁路与依赖处理改善

完成标准：

- load-use penalty 明显下降；
- hazard 判断更精确；
- CoreMark stall 占比有可观察下降。

### 里程碑 C4：多周期阻塞局部化

完成标准：

- MUL/DIV/LSU 对全局 ready 的影响减弱；
- issue 条件比现在更细粒度；
- 不相关指令前进能力更强。

### 里程碑 C5：CPU 进入结构成熟阶段

完成标准：

- 前后端有初步解耦；
- 轻量级在飞项/记分机制出现；
- 后续协处理器或新执行后端有自然接入点。

---

## 九、当前不建议优先做的事

当前不建议把主要精力优先放在：

- 继续扩大 BTB 容量；
- 单纯增大 cache 容量；
- 直接推进 dual-issue；
- 直接尝试有限乱序；
- 在结构未清晰前引入复杂大队列。

这些方向并非永远不做，而是放在当前阶段性矛盾之后再考虑更合适。

---

## 十、结论

HelloCPU 当前 CPU 设计的最优主线，不是继续做零散 patch，也不是过早追求复杂 superscalar 结构，而是：

1. 先统一执行、提交、恢复、访存边界；
2. 再针对 LSU、旁路、load-use、多周期阻塞做高收益优化；
3. 最后逐步引入 queue、scoreboard、额外执行后端等结构化能力。

如果这条路线走通，HelloCPU 会从“正确可运行的五级顺序核”，进一步演进成“结构更清晰、性能更扎实、后续扩展成本更低”的成熟标量 CPU。
