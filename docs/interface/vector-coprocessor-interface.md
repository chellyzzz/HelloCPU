# HelloCPU CPU/向量协处理器接口

本文档记录当前 CPU 与向量/COP 后端之间已经落地的接口语义。过期的“草案式字段全集”和尚未实现的异常、访存、seq/tag 细节已删除，未实现内容仅作为后续方向记录。

## 当前接口目标

当前 V1 接口服务于顺序单发射 CPU：CPU 负责发射、在飞记录、flush/kill 和统一提交；向量/COP 后端只负责接收请求、执行并返回结果。

核心原则：

1. 后端不直接修改架构状态。
2. 所有写回经 CPU/WBU 完成。
3. CPU 保证当前最多一个 COP 请求在飞。
4. 后端可以多拍完成。
5. kill 清空 CPU queue entry 与后端内部状态。

## 已实现通道

### Issue

当前 issue 边界由 `vsrc/vector/cop/idu_cop_regs.v` 和 `vsrc/vector/cop/cop_backend.v` 共同形成。

主要信号：

1. `cop_issue_valid`：当前 `IDU->EXU` payload 是 COP 指令。
2. `cop_issue_ready`：COP queue/backend 可接收请求。
3. `cop_issue`：`valid && ready` 后的 fire 信号。
4. `i_pc`、`i_ins`、`i_src1`、`i_src2`、`i_rd`、`i_wen`：当前请求 payload。

当前 payload 已包含原始 `instr`，后端可根据 `funct3/funct7` 分派 bring-up 子操作。

### Response

主要信号：

1. `cop_exu2wbu_valid`：后端结果可返回。
2. `wbu2exu_ready`：WBU 当前可接收。
3. `cop_resp_fire`：`cop_exu2wbu_valid && wbu2exu_ready`。
4. `cop_exu_res`：返回结果。

CPU 在 response fire 后通过 WBU 统一写回，并让 queue entry 出队。

### Kill

当前 kill 是粗粒度全杀：

```verilog
cop_kill = pc_update_en || idu2exu_fence_i || exu_mispredict_flush_r || cop_refetch_flush;
```

该信号同时驱动 COP queue 和后端 reset/flush。被 kill 的请求不得产生架构可见写回。

### Busy

`cop_backend_busy` 表示后端内部执行中或 response pending。它参与 queue ready 判断，并用于保持 V1 的单请求在飞约束。

## 当前目录边界

1. `vsrc/cpu/`：CPU 主流水和标量执行结构。
2. `vsrc/vector/cop/`：向量/COP issue queue、backend wrapper、当前执行切片。
3. `docs/cpu/`：CPU 文档。
4. `docs/vector/`：向量后端文档。
5. `docs/interface/`：CPU/向量边界文档。

## 当前验证覆盖

已验证：

1. `cop-smoke`：单条 `funct3=0` dummy add。
2. `cop-chain`：连续 dummy add / RAW 基线。
3. `cop-vadd8`：单条 `funct3=1` 4x8-bit lane add。
4. `cop-vxor8`：单条 `funct3=2` 4x8-bit lane xor。
5. `cop-vand8`：单条 `funct3=3` 4x8-bit lane and。
6. `cop-mixed-lanes`：`vadd8 -> vxor8 -> vand8` 连续 mixed lane chain。
7. `sum`、`load-store`：标量和 LSU 回归。

## 后续接口扩展

尚未实现但需要保留方向：

1. exception/cause/tval response 字段。
2. 更明确的 seq/tag，用于未来多请求在飞。
3. 独立向量访存 request/response 通道。
4. 向量 CSR/状态可见性定义。
5. response fire 同拍新 issue 与 refetch/kill 的精确定义。

其中 CPU 侧 memory request/response 的总边界，以 `docs/interface/cpu-memory-service-model.md` 为当前主参考；本文件只描述当前已经落地的 COP issue/response/kill 语义。
