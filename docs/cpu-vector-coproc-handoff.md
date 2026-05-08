# CPU 侧协处理器接入交接说明

本文档面向 CPU 端同学，说明当前 `vector-coproc-uarch` 分支上最小协处理器闭环的稳定状态、已经验证过的边界，以及后续 CPU 侧接入/重构建议。

## 一、当前同步点

当前分支：`vector-coproc-uarch`

建议 CPU 端以以下提交作为当前同步点：

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

当前 RTL 已经从最早的“dummy cop 塞在 EXU 内部”演进到更清晰的独立协处理器路径：

1. `IDU` 识别 `custom-0` 协处理器指令：`vsrc/idu/idu.v`
2. `idu_exu_regs` 透传 `is_cop_insn`：`vsrc/idu/idu_exu_regs.v`
3. 新增独立 COP issue state/queue-entry 模块：`vsrc/idu/idu_cop_regs.v`
4. 新增独立 COP backend：`vsrc/exu/cop_backend.v`
5. `dummy_coprocessor` 作为当前后端执行体：`vsrc/exu/dummy_coprocessor.v`
6. 顶层 `hcpu` 负责 COP/标量路径 mux、kill、response fire、WBU 统一提交：`vsrc/top/hcpu.v`
7. 软件最小用例仍使用 `custom-0`：`sw/tests/cpu-tests/dummy.c`、`sw/tests/cpu-tests/cop-smoke.c`

当前 dummy cop 行为仍是 `src1 + src2`，只用于验证控制闭环，不代表最终向量 ISA 行为。

## 三、当前接口语义

当前已经形成以下边界语义：

1. `cop_issue_valid`：当前 `IDU->EXU` payload 是 COP 指令。
2. `cop_issue_ready`：`idu_cop_regs` 判断当前可接收一个 COP issue。
3. `cop_issue`：`valid && ready` 后的 fire 信号，驱动 `cop_backend.i_pre_valid`。
4. `cop_backend_busy`：后端内部忙或 response pending。
5. `cop_resp_fire`：`cop_exu2wbu_valid && wbu2exu_ready`，表示 COP response 被 CPU 接收。
6. `cop_kill`：统一 kill/flush 信号，目前由 `pc_update_en || idu2exu_fence_i || exu_mispredict_flush_r` 产生。

`idu_cop_regs` 当前是 depth-1 queue-entry 形态，保存：

1. `entry_valid`
2. `entry_pc`
3. `entry_src1`
4. `entry_src2`
5. `entry_rd`
6. `entry_wen`

它的生命周期分为：

1. `o_issue_fire`：接收一条 COP 指令并锁存 payload。
2. `i_dequeue`：COP response 被 WBU 接收后正常出队。
3. `i_kill`：flush/fence/redirect 等事件导致队列项失效。

## 四、当前验证结果

当前同步点已通过以下验证：

1. `make sim`
2. `./build/Vsim_top ./sw/build/sum.bin`
3. `./build/Vsim_top ./sw/build/add.bin`
4. `./build/Vsim_top ./sw/build/dummy.bin`
5. `./build/Vsim_top ./sw/build/cop-smoke.bin`

其中 `sum` 是之前暴露 `ret/jalr` 回归的关键标量用例；当前同步点已确认通过。

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

关键位置：`vsrc/ifu/ifu_idu_regs.v:23`

```verilog
assign o_post_valid = i_post_ready && icache_hit;
```

这意味着 `valid` 仍依赖下游 `ready`，不是“寄存器持有有效 payload”的标准语义。后续若要做真正并行后端或更深队列，需要把这件事作为单独结构任务处理。

### 3. 当前 `cop_pipeline_active` 仍服务于保守顺序模型

现在设计仍让 COP 路径保持顺序阻塞，不允许后续标量指令越过 COP 提交。这符合 V1 约束，但不是高性能形态。

## 七、建议 CPU 端下一步

建议按以下顺序继续：

1. 先同步 `c361994` 当前稳定点。
2. 不要合入 `d1d7bad` 那类改前端 ready mux 的方案。
3. 在当前边界上先补一个 COP stress test，例如连续两条 `custom-0`、COP 后接 `jalr/ret`、COP 后接 load/store。
4. 再尝试让 `idu_cop_regs.o_issue_ready` 成为真正 queue-ready，而不是直接被 `i_backend_busy` 限制。
5. 最后再单独规划 `IFU/IDU` 标准 valid/ready 重构。

## 八、一句话结论

当前分支已经有稳定、可回归、命名清晰的最小 COP 控制闭环。CPU 端现在可以同步这个点，但下一阶段仍应避免直接改前端主握手；应先用当前 `valid/ready/fire + queue entry + response fire + shared kill` 边界继续演进。
