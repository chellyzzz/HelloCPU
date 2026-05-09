# HelloCPU V1 向量协处理器微架构方案

## 一、文档目标

本文档给出 HelloCPU 第一阶段向量协处理器后端的微架构设计方案。

本方案的目标不是直接实现完整向量机，而是先把协处理器作为一个可联调、可演进、可验证的长延迟执行后端接入当前顺序核。

本文档重点回答以下问题：

1. V1 协处理器在系统中的定位是什么；
2. CPU 与协处理器的边界如何划分；
3. 第一版 RTL 应该长成什么样；
4. 后续如何从 dummy 后端演进到真实向量执行单元。

---

## 二、设计目标

V1 协处理器的核心目标是先打通最小控制闭环，而不是追求完整功能。

本阶段目标包括：

1. 在 CPU 中引入一个独立于标量 EXU 的协处理器执行后端；
2. 建立稳定的 `issue / resp / kill / busy` 语义；
3. 由 CPU 统一负责提交、异常生效和控制流恢复；
4. 允许后续逐步扩展真实向量算子、向量状态和向量访存。

本阶段不追求：

1. 完整 RISC-V V ISA；
2. 独立向量访存通路；
3. 多请求同时在飞；
4. lane 化执行；
5. 完整向量寄存器文件与 CSR 模型。

---

## 三、V1 设计约束

V1 方案严格采用以下约束：

1. 单发射；
2. 同时最多一个协处理器请求在飞；
3. 协处理器不直接修改 GPR、CSR、PC 或内存；
4. 所有架构可见提交统一由 CPU 在 WBU 完成；
5. kill 第一版只支持粗粒度全杀；
6. 异常先并入 response 语义，后续再细化异常字段；
7. 第一阶段先不引入协处理器独立 LSU。

这些约束的目的不是永久限制设计，而是确保当前顺序核能以最小代价、安全地接入一个新的长延迟后端。

---

## 四、与当前 CPU 微架构的关系

当前 HelloCPU 是 `IFU -> IDU -> EXU -> WBU -> Register File` 的五级顺序核。

对当前结构的基本判断如下：

1. 协处理器最自然的接入点是 EXU 旁边的并行长延迟后端；
2. 不建议把向量逻辑直接塞进 `hcpu_EXU` 内部的现有执行分支；
3. CPU 仍然保持单一架构提交点，即 `WBU`；
4. 协处理器路径应被视为“另一种执行完成来源”，而不是“另一套提交体系”。

因此，V1 采用如下总体结构：

```text
IFU -> IDU -> IDU/EXU regs -> { Scalar EXU | Coprocessor } -> WBU -> Register File
```

其中：

1. 标量指令进入现有 `EXU -> exu_wbu_regs -> WBU`；
2. 协处理器指令进入新的 `coprocessor backend`；
3. 最终由顶层把标量结果或协处理器结果选择后送入统一 `WBU`；
4. 当协处理器存在未提交在飞项时，前端停止继续发射，保持顺序提交模型。

### 当前 RTL 落点（向量整理同步点 `409575a`）

`vector-coproc-uarch` 已经实现了 V1 的最小稳定控制闭环；CPU 主线随后已经同步该闭环，并在 `5a5caa9 fix: preserve consecutive cop issue flow` 补齐连续 COP / RAW 依赖场景。当前 RTL 不是完整向量机，但协处理器边界已经从标量 EXU 中逐步拆清楚。

向量端当前建议 CPU 侧以 `409575a refactor: organize cpu vector project layout` 作为新的整理同步点。该点已经把 CPU 本体和向量/COP 相关逻辑拆到更清晰的目录结构，后续不建议继续在旧 `vsrc/exu` / `vsrc/idu` 路径上扩展 COP 设计。

当前主要模块职责如下。旧路径说明保留用于理解历史演进；`409575a` 之后应按新目录映射：

1. `vsrc/idu/idu.v`：识别 `custom-0`，输出 `o_is_cop_insn`。
2. `vsrc/idu/idu_exu_regs.v`：透传 COP 标记，仍保留现有标量主流水握手。
3. `vsrc/idu/idu_cop_regs.v`：实现 COP depth-1 queue-entry 形态，提供 `i_issue_valid / o_issue_ready / o_issue_fire`，并保存 `pc/src1/src2/rd/wen`。
4. `vsrc/exu/cop_backend.v`：独立 COP 后端包装，提供 `busy`、response valid 和 result。
5. `vsrc/top/hcpu.v`：统一组织 COP issue、response fire、kill、WBU mux 和寄存器堆 bypass。

当前顶层使用以下命名表达 COP 生命周期：

1. `cop_issue_active`：当前 IDU/EXU payload 是 COP issue。
2. `cop_commit_active`：COP queue entry 已存在，提交元数据来自 `idu_cop_regs`。
3. `cop_pipeline_active`：COP issue 或 commit 路径正在占用顶层 mux。
4. `cop_resp_fire`：COP response 被 WBU 接收。
5. `cop_kill`：统一 kill/flush 信号，同时驱动 queue 和 backend。

CPU 主线在该边界上额外确认了三点：

1. `idu_cop_regs` 支持 response dequeue 和下一条 COP issue 同拍发生。
2. 同拍新 issue 时，backend 操作数必须选择新 payload，提交元数据仍来自旧 entry。
3. COP response 当前会触发保守 refetch，避免在 `IFU/IDU` 尚未完全标准化前出现重复提交或跳过后续指令。

当前 CPU 主线同步点已通过：`make sim`、`cop-chain`、`dummy`、`cop-smoke`、`add`、`sum`、`load-store`、`quick-sort`。

当前向量整理同步点 `409575a` 已由向量端验证：`make clean && make sim`、`sw`、`cop-vadd8`、`cop-chain`、`sum`。

CPU 侧下一轮建议先同步到 `409575a` 的目录整理结果，再继续替换 dummy 后端为真实向量执行单元；否则容易继续基于旧路径开发，后续合并成本会快速上升。

---

## 五、模块划分建议

### 1. CPU 侧模块

CPU 侧建议增加三类逻辑。

第一类是 decode 标记：

1. `IDU` 增加 `is_cop_insn`；
2. `idu_exu_regs` 透传 `is_cop_insn`。

第二类是顶层协处理器控制：

1. 协处理器 issue 选择；
2. 单项 `cop_inflight` 记录；
3. 协处理器 kill 广播；
4. 协处理器返回到 `WBU` 的选择逻辑。

第三类是顺序提交保护：

1. 当 `cop_inflight=1` 时阻塞前端；
2. 防止后续标量指令绕过未完成协处理器指令提交；
3. 保证 flush、trap、mispredict 下协处理器结果不会错误生效。

### 2. 协处理器侧模块

V1 协处理器建议拆成下面三个子块：

1. `Issue Latch`：锁存来自 CPU 的请求字段；
2. `Execution Slice`：执行 dummy 或真实向量运算；
3. `Response Latch/FSM`：在完成时持有结果，等待 CPU 接收。

对应的第一版状态机可简单设计为：

1. `IDLE`：等待 issue；
2. `EXEC`：内部执行；
3. `RESP`：结果已准备好，等待 CPU 接收；
4. `KILLED` 可不单独建状态，直接回到 `IDLE`。

---

## 六、推荐接口语义

V1 维持四组基础接口：

1. `issue_valid / issue_ready / issue_payload`
2. `resp_valid / resp_ready / resp_payload`
3. `kill`
4. `busy`

### 1. Issue

`issue` 通道负责把一条协处理器指令正式发给后端。

建议的最小 payload 包括：

1. `pc`
2. `instr`
3. `src1_value`
4. `src2_value`
5. `rd`
6. `wen`
7. 预留 `func/opcode/mode`

语义要求：

1. 只有 `valid && ready` 同拍时请求才算进入协处理器；
2. 第一版 `ready` 仅在无在飞请求时为高；
3. CPU 负责保证同一时刻最多只有一个请求发出。

### 2. Response

`resp` 通道负责把执行完成结果返还给 CPU。

建议的最小 payload 包括：

1. `result`
2. `rd`
3. `wen`
4. `pc`
5. 预留 `exc/cause/tval/flags`

语义要求：

1. `resp_valid` 只表示结果已准备好；
2. 不等同于结果已经架构提交；
3. CPU 接收后仍需通过统一 `WBU` 完成真正写回。

### 3. Kill

V1 只支持粗粒度 `kill_all` 语义。

触发来源包括：

1. 分支误预测 flush；
2. `ecall/mret/trap` 路径；
3. 其他导致未提交指令失效的全局清空事件。

语义要求：

1. 被 kill 的协处理器请求即使内部已经算完，也不能再产生架构可见写回；
2. kill 后协处理器内部状态必须回到空闲态；
3. CPU 侧 `cop_inflight` 记录同步清空。

### 4. Busy

`busy` 仅反映协处理器内部仍有未完成工作。

V1 中 `busy` 主要用于：

1. 调试观测；
2. 将来扩展更精细的前端阻塞策略；
3. 后续性能计数器和 trace 统计。

---

## 七、CPU 侧微架构方案

### 1. Decode 阶段

在 `IDU` 中增加 `is_cop_insn`，把协处理器指令与普通标量指令区分开。

V1 bring-up 阶段建议先使用 `custom-0` opcode 作为 dummy 协处理器编码，而不是立即绑定标准 `OP-V`。

这样做有三个好处：

1. 不会过早把 dummy 行为和真实向量 ISA 绑定；
2. 更适合先验证控制闭环；
3. 后续替换为正式向量编码时改动范围更可控。

### 2. 发射阶段

当当前指令是协处理器指令时，顶层不再让它进入标量 `EXU`。

取而代之的是：

1. 检查 `cop_inflight == 0`；
2. 检查 `cop_issue_ready == 1`；
3. 成功握手后把请求送入协处理器；
4. 同时在 CPU 侧记录 `cop_inflight`。

如果协处理器忙，前端停顿，保持顺序模型。

### 3. Inflight 记录

CPU 侧建议维护一个最小 `cop_inflight` 表项，记录：

1. `valid`
2. `pc`
3. `rd`
4. `wen`
5. 预留 `instr/tag/flags`

V1 中这个表项的作用有三类：

1. 约束最多一个请求在飞；
2. 在返回时提供统一提交所需元数据；
3. 在 kill 时统一清空协处理器生命周期。

### 4. 返回与提交

当协处理器返回结果时：

1. 顶层选择协处理器返回作为当前 `WBU` 输入；
2. `WBU` 按普通写回路径把结果写回 GPR；
3. `cop_inflight` 在 `resp && ready` 时清空。

这样做的核心收益是：

1. 不需要协处理器自己修改架构状态；
2. 不需要引入第二套提交器；
3. `RegisterFile`、CSR、PC 更新语义可以保持一致。

### 5. 顺序提交保证

V1 必须严格保证顺序提交。

最简单可靠的实现是：

1. 一旦 `cop_inflight=1`，前端停止发射后续指令；
2. 等待协处理器结果被 `WBU` 接收后再解除阻塞。

这不是最终性能最优方案，但非常适合第一阶段降低控制复杂度。

---

## 八、协处理器内部微架构方案

### 1. V1 Dummy 协处理器

第一阶段建议先做一个最小 dummy 协处理器。

行为建议如下：

1. 收到一条请求后锁存所有输入；
2. 固定延迟若干拍；
3. 输出一个简单结果，例如 `src1 + src2`；
4. 在 `kill` 到来时直接丢弃结果并回到空闲态。

当前 bring-up 版本的 dummy 指令编码约定如下：

1. 使用 `custom-0` opcode，即 `7'b0001011`；
2. 采用 R-type 形式承载 `rd/rs1/rs2`；
3. 当前 `func3/funct7` 暂不区分子操作，统一视为 dummy add；
4. 软件侧可通过 GNU 汇编 `.insn r 0x0b, 0, 0, rd, rs1, rs2` 生成该指令。

在当前 RTL 中，该 dummy 指令的行为定义为：

1. CPU 把 `rs1/rs2` 作为源操作数发给协处理器；
2. 协处理器固定延迟若干拍后返回 `src1 + src2`；
3. 最终结果由 CPU 统一经 `WBU` 写回 `rd`。

这个 dummy 的作用不是模拟真实向量机，而是验证：

1. `issue` 握手是否正确；
2. `resp` 回传是否稳定；
3. `kill` 是否不会留下错误写回；
4. `WBU` 提交路径是否真的统一。

### 2. 从 Dummy 到真实向量执行的演进

当 dummy 路径稳定后，协处理器内部可逐步替换为真实执行结构。

推荐演进顺序：

1. 固定延迟伪操作；
2. 少量真实纯计算型向量操作；
3. 最小向量状态保存结构；
4. 向量 CSR；
5. 独立访存接口；
6. lane 化与并发优化。

这一演进顺序的关键是每一步都建立在已经验证的 `issue/resp/kill/commit` 框架上，而不是每次都重做 CPU 集成。

---

## 九、V1 不建议现在做的内容

为了控制风险，V1 明确不建议现在实现以下内容：

1. 向量 load/store 独立访存通路；
2. 多协处理器请求同时在飞；
3. 复杂 scoreboard；
4. 完整向量寄存器文件；
5. 标准 RISC-V V CSR 细节；
6. 精确到元素级别的异常恢复；
7. lane 级调度和高吞吐优化。

这些内容都应该等到最小闭环和统一控制语义稳定后再逐步展开。

---

## 十、推荐 RTL 集成步骤

建议按以下顺序推进 RTL：

### 步骤 1：Decode 打标

1. `IDU` 增加 `is_cop_insn`；
2. `idu_exu_regs` 增加对应流水位。

### 步骤 2：Dummy 协处理器占位

1. 新增最小 `dummy_coprocessor` 模块；
2. 固定 `issue/resp/kill/busy` 端口；
3. 支持固定延迟返回。

### 步骤 3：CPU 顶层控制接线

1. 增加 `cop_inflight` 记录；
2. 增加协处理器 issue 选择；
3. 增加粗粒度 kill；
4. 增加协处理器返回到 `WBU` 的 mux。

### 步骤 4：最小验证闭环

1. 单条协处理器请求写回；
2. 连续两条协处理器请求；
3. 协处理器忙导致前端停顿；
4. flush/kill 场景不产生错误写回。

### 步骤 5：功能深化

1. 支持少量真实向量算子；
2. 再考虑异常字段；
3. 再考虑状态和访存扩展。

---

## 十一、调试与观测点建议

V1 阶段建议优先暴露下列观测点：

1. `is_cop_insn`
2. `cop_issue_valid/ready`
3. `cop_resp_valid/ready`
4. `cop_busy`
5. `cop_inflight`
6. `cop_kill`
7. 协处理器返回的 `rd/result`
8. `WBU` 最终接收的是标量路径还是协处理器路径

这些点对于早期联调尤其重要，因为 V1 最大风险在控制交互，而不是算术本身。

---

## 十二、结论

HelloCPU 第一阶段最合理的向量路线，不是直接做完整向量机，而是先做一个受控的协处理器后端。

V1 的核心原则是：

1. 协处理器只负责执行与返回；
2. CPU 统一负责发射、在飞记录、kill、提交和 trap；
3. 先做单请求、无访存、可 kill 的最小闭环；
4. 再在这个框架上逐步长出真实向量能力。

这条路线与当前顺序核结构最匹配，也最有利于后续从 dummy 路径平滑演进到真实向量后端。
