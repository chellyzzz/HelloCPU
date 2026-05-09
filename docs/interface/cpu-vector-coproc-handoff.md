# CPU/向量协处理器交接状态

本文档记录当前 `vector-coproc-uarch` 分支的 CPU/向量交接事实。旧的 `c361994` 同步点说明已过期；当前分支已经合入 CPU 主线同步点 `5a5caa9`，并在其上继续加入最小 `vadd8` 向量算子切片。

## 当前状态

当前已完成：

1. CPU 主线 `5a5caa9 fix: preserve consecutive cop issue flow` 已合入当前向量分支。
2. COP 路径保留 `valid/ready/fire + queue entry + response fire + shared kill` 边界。
3. RTL 已整理为 `vsrc/cpu/` 和 `vsrc/vector/` 两部分。
4. 文档已整理为 `docs/cpu/`、`docs/vector/`、`docs/interface/` 三类。
5. COP payload 已携带原始指令 `instr`。
6. 当前执行切片支持 `funct3=0` dummy add 和 `funct3=1` 4x8-bit lane add。

## 当前关键文件

1. `vsrc/cpu/top/hcpu.v`：顶层 mux、kill、response fire 和 WBU 接入。
2. `vsrc/cpu/idu/idu.v`：识别 `custom-0`。
3. `vsrc/cpu/idu/idu_exu_regs.v`：透传 `pc/instr/src1/src2/rd/wen/is_cop_insn`。
4. `vsrc/vector/cop/idu_cop_regs.v`：COP depth-1 queue entry。
5. `vsrc/vector/cop/cop_backend.v`：后端 response/busy wrapper。
6. `vsrc/vector/cop/dummy_coprocessor.v`：当前固定延迟执行切片。
7. `sw/tests/cpu-tests/cop-vadd8.c`：当前最小真实向量算子回归。

## 验证结果

最近通过：

1. `make sim sw`
2. `./build/Vsim_top ./sw/build/cop-vadd8.bin`
3. `./build/Vsim_top ./sw/build/cop-smoke.bin`
4. `./build/Vsim_top ./sw/build/cop-chain.bin`
5. `./build/Vsim_top ./sw/build/sum.bin`
6. `./build/Vsim_top ./sw/build/load-store.bin`

## 已知风险

1. 不要重新引入已回退的 dedicated IDU->COP ready mux 路线。
2. 当前仍是单请求在飞模型，不支持多请求并发。
3. `funct3=1` 已支持单条 `vadd8`，但 mixed/连续向量链式场景还需要单独修 response 同拍新 issue 与 refetch/kill 的竞争。
4. 暂无异常字段、向量 CSR、向量寄存器文件和独立访存。

## 推荐下一步

1. 先提交当前文档/目录整理与 `vadd8` 切片。
2. 单独修复 response fire 同拍新 issue 的精确语义。
3. 加入连续 `vadd8` 回归。
4. 再把 `dummy_coprocessor` 拆名为真实的 vector execution slice。
