# HelloCPU 向量协处理器微架构状态

本文档记录当前向量/COP 后端的实际 RTL 状态。历史草案中关于旧同步点、未拆分 dummy 路径、以及“尚未传递原始指令”的描述已经删除。

## 当前定位

当前实现仍是 V1 bring-up，不是完整 RISC-V Vector 实现。目标是先让 CPU 以稳定的 `issue / response / kill / busy` 边界接入一个长延迟后端，并在该边界上逐步长出真实向量功能。

当前约束：

1. 单发射。
2. 同时最多一个 COP 请求在飞。
3. 向量/COP 后端不直接修改 GPR、CSR、PC 或内存。
4. 写回仍由 CPU/WBU 统一提交。
5. kill 采用粗粒度全杀。
6. 暂无独立向量访存、向量 CSR、向量寄存器文件或多 lane 流水。

## RTL 划分

相关 Verilog 已按 CPU 与向量边界整理：

1. `vsrc/cpu/`：CPU 主流水、标量 EXU/LSU、IFU/IDU/WBU、CSR/RegisterFile、片上互联和 include 文件。
2. `vsrc/vector/cop/idu_cop_regs.v`：CPU 到 COP 的 depth-1 queue entry，保存 `pc/instr/src1/src2/rd/wen`，并提供 `valid/ready/fire` 边界。
3. `vsrc/vector/cop/cop_backend.v`：COP 后端 wrapper，管理 busy、response valid 和结果保持。
4. `vsrc/vector/cop/dummy_coprocessor.v`：当前执行切片，固定延迟返回结果。

模块名暂时保持原名，避免引入大规模重命名风险。

## 当前指令行为

当前仍使用 `custom-0` opcode，即 `7'b0001011`，以 R-type 形式承载 `rd/rs1/rs2`。

已实现的 bring-up 子操作：

1. `funct3=0`：标量 dummy add，返回 `src1 + src2`。
2. `funct3=1`：4x8-bit lane add，按字节分别计算 `src1[i] + src2[i]`，每个 byte 自然截断。

软件生成示例：

```c
asm volatile (".insn r 0x0b, 1, 0, %0, %1, %2"
              : "=r"(result)
              : "r"(lhs), "r"(rhs));
```

## 当前验证

最近验证通过：

1. `make sim sw`
2. `./build/Vsim_top ./sw/build/cop-vadd8.bin`
3. `./build/Vsim_top ./sw/build/cop-smoke.bin`
4. `./build/Vsim_top ./sw/build/cop-chain.bin`
5. `./build/Vsim_top ./sw/build/sum.bin`
6. `./build/Vsim_top ./sw/build/load-store.bin`

`cop-vadd8` 覆盖第一条最小真实向量算子。`cop-smoke` 和 `cop-chain` 覆盖旧 dummy add 行为和连续 COP 基线。

## 已知边界

混合连续向量/COP 请求曾暴露 response fire 同拍新 issue 与 refetch/kill 竞争问题。当前保守策略是不改变后端 ready/accept 时序，只保留已验证的单条 `vadd8` 功能切片。后续若要提高连续 COP 吞吐，应单独处理 response 同拍新 issue 的 kill/refetch 语义。

## 下一步

推荐按以下顺序推进：

1. 把当前 `dummy_coprocessor` 拆名为更明确的 vector execution slice。
2. 为 `funct3=1` 增加更多非链式功能覆盖。
3. 单独修复 response 同拍新 issue 与 refetch/kill 的竞争。
4. 再增加连续 `vadd8` / mixed COP chain 回归。
5. 最后再考虑向量状态、CSR、访存和更完整的 lane 结构。
