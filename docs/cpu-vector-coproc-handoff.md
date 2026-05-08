# CPU 侧协处理器接入交接说明

本文档说明 CPU 主线与 `vector-coproc-uarch` 之间当前的双向同步状态、已经验证过的稳定边界，以及下一步把 CPU 进展同步回向量端时应保留的约束。

## 一、当前同步点

当前 CPU 主线分支：`cpu-mainline-branch`

当前 CPU 主线稳定点：

```text
5a5caa9 fix: preserve consecutive cop issue flow
```

该点已经包含两部分内容：

1. CPU 侧 LSU / CoreMark 性能稳定点：`282abe6 perf: reduce LSU startup stalls`。
2. 向量端 COP 独立后端同步点：`c361994 refactor: clarify cop active states`，以及后续 CPU 侧连续 COP 修正 `5a5caa9`。

建议向量端下一轮以 `5a5caa9` 作为 CPU 回灌同步点，而不是继续停留在旧的 `5bb827b` / `c361994` 附近。

原向量端给 CPU 的同步基点：

```text
c361994 refactor: clarify cop active states
```

该提交之前的关键稳定点包括：

1. `475ba0e feat: split cop backend from scalar exu`
2. `cff41fc feat: latch cop issue metadata separately`
3. `1fbe838 feat: expose cop backend busy state`
4. `780f7aa refactor: move cop issue readiness into queue regs`
5. `ec84b72 refactor: use valid ready cop issue boundary`
6. `3ec7036 refactor: model cop issue state as queue entry`
7. `98a37b8 refactor: split cop queue kill and dequeue`
8. `50ab806 refactor: drive cop dequeue from response fire`
9. `f541a33 refactor: share cop kill signal`
10. `c361994 refactor: clarify cop active states`

历史上 `d1d7bad feat: add dedicated IDU to cop issue queue` 已被 `b64b051` 回退。不要把 `d1d7bad` 的前端握手改法当作当前建议方案。

## 二、当前已经完成什么

当前 CPU 主线已经同时具备最新 CPU 进展和更清晰的独立协处理器路径。

CPU 侧已经稳定落地的内容包括：

1. LSU `load hit` 快速完成。
2. LSU `store hit` 快速完成。
3. LSU transaction start 提前，去掉多余启动等待拍。
4. LSU refill stall 细分计数：`AR wait` / `R data`。
5. IFU held-valid stall 细分计数：`control` / `LSU` / `MUL/DIV` / `COP` / `other`。
6. CoreMark `ITER=100` 正确通过，当前参考 `2.279 CoreMark/MHz`、`IPC=0.698`。

COP 侧已经从最早的“dummy cop 塞在 EXU 内部”演进到独立协处理器路径：

1. `IDU` 识别 `custom-0` 协处理器指令：`vsrc/idu/idu.v`
2. `idu_exu_regs` 透传 `is_cop_insn`：`vsrc/idu/idu_exu_regs.v`
3. 新增独立 COP issue state/queue-entry 模块：`vsrc/idu/idu_cop_regs.v`
4. 新增独立 COP backend：`vsrc/exu/cop_backend.v`
5. `dummy_coprocessor` 作为当前后端执行体：`vsrc/exu/dummy_coprocessor.v`
6. 顶层 `hcpu` 负责 COP/标量路径 mux、kill、response fire、WBU 统一提交：`vsrc/top/hcpu.v`
7. 软件最小用例仍使用 `custom-0`：`sw/tests/cpu-tests/dummy.c`、`sw/tests/cpu-tests/cop-smoke.c`、`sw/tests/cpu-tests/cop-chain.c`

当前 dummy cop 行为仍是 `src1 + src2`，只用于验证控制闭环，不代表最终向量 ISA 行为。

## 三、当前接口语义

当前已经形成以下边界语义：

1. `cop_issue_valid`：当前 `IDU->EXU` payload 是 COP 指令。
2. `cop_issue_ready`：`idu_cop_regs` 判断当前可接收一个 COP issue。
3. `cop_issue`：`valid && ready` 后的 fire 信号，驱动 `cop_backend.i_pre_valid`。
4. `cop_backend_busy`：后端内部忙或 response pending。
5. `cop_resp_fire`：`cop_exu2wbu_valid && wbu2exu_ready`，表示 COP response 被 CPU 接收。
6. `cop_kill`：统一 kill/flush 信号，目前由 `pc_update_en || idu2exu_fence_i || exu_mispredict_flush_r || cop_refetch_flush` 产生。

`idu_cop_regs` 当前是 depth-1 queue-entry 形态，保存：

1. `entry_valid`
2. `entry_pc`
3. `entry_src1`
4. `entry_src2`
5. `entry_rd`
6. `entry_wen`

它的生命周期分为：

1. `o_issue_fire`：接收一条 COP 指令并锁存 payload。
2. `i_dequeue`：COP response 被 WBU 接收后正常出队；若同拍有新 COP issue，允许 dequeue + enqueue。
3. `i_kill`：flush/fence/redirect 等事件导致队列项失效。

当前 CPU 主线额外修正了连续 COP 场景：

1. `o_issue_ready` 允许在 `i_dequeue` 同拍接收下一条 COP。
2. `o_active_src1/o_active_src2` 在新 issue fire 时直接选择新 payload，避免 backend 误用旧 entry 操作数。
3. COP response 当前会触发 `cop_refetch_flush`，避免依赖尚未完全标准化的 IFU/IDU held-valid 语义导致重复提交或跳过后续指令。

## 四、当前验证结果

当前 CPU 主线稳定点已通过以下验证：

1. `make sim`
2. `./build/Vsim_top sw/build/cop-chain.bin --max-cycles=2000000`
3. `./build/Vsim_top sw/build/dummy.bin --max-cycles=2000000`
4. `./build/Vsim_top sw/build/cop-smoke.bin --max-cycles=2000000`
5. `./build/Vsim_top sw/build/add.bin --max-cycles=2000000`
6. `./build/Vsim_top sw/build/sum.bin --max-cycles=2000000`
7. `./build/Vsim_top sw/build/load-store.bin --max-cycles=2000000`
8. `./build/Vsim_top sw/build/quick-sort.bin --max-cycles=2000000`

LSU/CoreMark 稳定点此前也已通过：

1. `make run`：`42 passed, 0 failed`。
2. CoreMark `ITER=1`：CRC 正确，`2.046 CoreMark/MHz`。
3. CoreMark `ITER=100`：CRC 正确，`2.279 CoreMark/MHz`。

其中 `sum` 是之前暴露 `ret/jalr` 回归的关键标量用例；`cop-chain` 是当前 CPU 主线新增的连续 COP / RAW 依赖回归。

## 五、当前架构定位

当前实现仍是 V1 bring-up，不是完整向量协处理器。

当前保持的约束：

1. 单发射。
2. 同时最多一个 COP 请求在飞。
3. COP 不直接修改 GPR、CSR、PC 或内存。
4. 所有架构可见状态仍由 CPU/WBU 统一提交。
5. kill 当前是粗粒度全杀。
6. 暂不支持独立向量访存。

当前顶层意图已经拆成更清楚的三个状态名：

1. `cop_issue_active`：当前 IDU/EXU payload 是 COP issue。
2. `cop_commit_active`：已有 COP queue entry 在等待/提交。
3. `cop_pipeline_active`：COP issue 或 commit 路径占用当前顶层 mux。

WBU 与寄存器堆 bypass mux 当前使用 `cop_commit_active` 来选择 COP 提交元数据。

## 六、已知风险与不要踩的坑

### 1. 不要现在改 `idu2ifu_ready` 分流

之前失败的 `d1d7bad` 尝试把 COP 从 `IDU->EXU` 主路径旁路出去，并修改 `IDU/IFU` ready 选择。该方案导致 `sum` 标量回归，表现为尾部 `ret/jalr` 没有稳定按原路径进入 EXU。

当前稳定路线是：

1. 先保留现有前端主握手。
2. 在其后逐步把 COP 边界结构化。
3. 等 COP 边界稳定后，再单独处理前端标准 valid/ready 重构。

### 2. `IFU/IDU` 握手仍不是标准寄存式 valid/ready

关键位置：`vsrc/ifu/ifu_idu_regs.v:22`

```verilog
assign o_post_valid = icache_hit;
```

当前已经修掉了 `valid` 直接依赖下游 `ready` 的最危险形态，但这一级仍不是完整标准的寄存式 `valid/ready` 边界：payload 更新仍由 `icache_hit && i_post_ready` 控制，`valid` 表示更接近“当前 IFU 命中可供给”，而不是“边界寄存器内有一条完整持有的有效指令”。后续若要做真正并行后端或更深队列，需要把这件事作为单独结构任务处理。

### 3. 当前 `cop_pipeline_active` 仍服务于保守顺序模型

现在设计仍让 COP 路径保持顺序阻塞，不允许后续标量指令越过 COP 提交。这符合 V1 约束，但不是高性能形态。

## 七、建议向量端下一步

建议按以下顺序继续：

1. 从 CPU 主线同步到 `5a5caa9`，把 LSU fast paths、性能计数器、CoreMark 文档和 COP 连续 issue 修正一起带过去。
2. 同步时保留 `b64b051` 对 `d1d7bad` 的回退结果，不要重新引入前端 ready mux 分流方案。
3. 先保持当前 COP V1 顺序阻塞模型，不在同一个 patch 中引入多请求在飞、scoreboard 或向量访存。
4. 同步后至少跑 `add`、`sum`、`dummy`、`cop-smoke`、`cop-chain`、`load-store`、`quick-sort`。
5. 稳定后再单独规划 `IFU/IDU` 标准 valid/ready 重构。

建议向量端优先同步的 CPU 文件范围：

1. `vsrc/exu/lsu.v`
2. `vsrc/ifu/ifu_idu_regs.v`
3. `vsrc/top/hcpu.v`
4. `vsrc/idu/idu_cop_regs.v`
5. `vsrc/exu/cop_backend.v`
6. `sim/sim_main.cpp`
7. `sw/tests/cpu-tests/cop-chain.c`
8. `docs/coremark-results.md`
9. `docs/cpu-design-plan.md`
10. `docs/microarchitecture.md`

## 八、一句话结论

当前 CPU 主线可以视作一个新的稳定同步点：标量 CPU LSU/CoreMark 进展已经回归通过，COP 独立后端也已吸收并补齐连续 issue 回归。下一步更合理的是先把 CPU 主线同步回向量端，避免向量端继续基于过旧 CPU 结构开发；随后再在共同基线上推进真实向量后端。
