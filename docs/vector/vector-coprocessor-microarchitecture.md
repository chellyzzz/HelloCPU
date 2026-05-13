# HelloCPU 向量协处理器微架构状态

本文档记录当前向量/COP 后端的实际 RTL 状态。历史草案中关于旧同步点、未拆分 dummy 路径、以及“尚未传递原始指令”的描述已经删除。

## 当前定位

当前实现仍是 V1 bring-up，不是完整 RISC-V Vector 实现。目标是先让 CPU 以稳定的 `issue / response / kill / busy` 边界接入一个长延迟后端，并在该边界上逐步长出真实向量功能。

当前约束：

1. 单发射。
2. 同时最多一个 COP 请求在飞。
3. COP 结果写回仍由 CPU/WBU 统一提交。
4. kill 采用粗粒度全杀，killed COP work 不得产生 GPR/VRF 写回。
5. 已有原型 VRF 和最小 COP memory 访问，但不是 RVV 架构状态。
6. 暂无标准 RVV decode、向量 CSR、mask/tail policy 或多 lane 流水。

## RTL 划分

相关 Verilog 已按 CPU 与向量边界整理：

1. `vsrc/cpu/`：CPU 主流水、标量 EXU/LSU、IFU/IDU/WBU、CSR/RegisterFile、片上互联和 include 文件。
2. `vsrc/vector/cop/idu_cop_regs.v`：CPU 到 COP 的 depth-1 queue entry，保存 `pc/instr/src1/src2/rd/wen`，并提供 `valid/ready/fire` 边界。
3. `vsrc/vector/cop/cop_backend.v`：COP 后端 wrapper，管理 busy、response valid 和结果保持。
4. `vsrc/vector/cop/dummy_coprocessor.v`：当前执行切片，包含 scalar/lane/VRF/state/memory 原型操作。

模块名暂时保持原名，避免引入大规模重命名风险。

## 当前指令行为

当前仍使用 `custom-0` opcode，即 `7'b0001011`，以 R-type 形式承载 `rd/rs1/rs2`。

主要 bring-up 子操作记录在 `cop-encoding.md`。当前大类包括：

1. 标量扩展操作：add/sub/mul。
2. 直接 GPR lane 操作：4x8-bit add/xor/and。
3. VRF 操作：vload/vstore、VRF lane add/xor/and/sub/mul/shift/or。
4. 状态操作：scratch、vlen、opcount。
5. COP memory 操作：`vload_mem` / `vstore_mem`，通过 CPU memory owner 边界访问内存。

软件生成示例：

```c
asm volatile (".insn r 0x0b, 1, 0, %0, %1, %2"
              : "=r"(result)
              : "r"(lhs), "r"(rhs));
```

## 当前验证

P0 基线应至少覆盖以下 test groups：

1. scalar smoke：`sum`、`load-store`。
2. COP scalar/lane：`cop-smoke`、`cop-chain`、`cop-vadd8`、`cop-vxor8`、`cop-vand8`、`cop-mixed-lanes`。
3. COP state/VRF：`cop-state*`、`cop-vlen*`、`cop-opcount*`、`cop-vrf-*`。
4. COP memory：`cop-vload-mem`、`cop-vstore-mem`、`cop-vload-store-mem`、`cop-vload-repeat-mem`。
5. directed pending-kill：`make cop_mem_pending_kill`。

`cop-vadd8` 覆盖第一条最小真实向量算子。`cop-vxor8` 和 `cop-vand8` 覆盖后续 lane 逻辑算子。`cop-vadd8-chain`、`cop-vadd8-after-add` 和 `cop-mixed-lanes` 覆盖连续/混合 COP 提交时序。COP memory tests 覆盖 VRF 与内存的最小交互，`cop_mem_pending_kill` 覆盖 COP load response 晚到后的 stale completion 吸收。

## 已知边界

混合连续向量/COP 请求曾暴露 response fire 同拍新 issue 与 refetch/kill 竞争问题。当前保守策略是 COP 完成后先经 CPU/WBU 统一提交，再由 response fire 触发 refetch `PC+4`；同时禁止 custom 指令走 stale scalar EXU valid 提交路径。

当前 COP memory 仍是 V1 owner-boundary bring-up，不是完整 vector memory subsystem。后续 RVV store、异常、misalign、多请求在飞和 cache 一致性都需要单独设计。

## 下一步

推荐按以下顺序推进：

1. 先完成 P0 文档、测试矩阵和 smoke 列表收敛。
2. 保持 `custom-0` COP 原型作为 RVV 迁移前的回归平台。
3. 后续若要提高连续 COP 吞吐，单独设计多请求/scoreboard/精确 flush 语义。
4. 进入 RVV 前先定义最小 `vl/vtype` 状态和 unsupported 行为。
