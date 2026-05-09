# CPU/向量协处理器交接状态

本文档记录当前 CPU 主线与 `vector-coproc-uarch` 分支的 CPU/向量交接事实。旧的 `c361994` 同步点说明已过期；CPU 侧已经同步到向量端 `539bf41 fix: repair consecutive cop commit timing`。

## 当前状态

当前已完成：

1. CPU 主线已包含 `409575a refactor: organize cpu vector project layout` 的目录整理。
2. COP 路径保留 `valid/ready/fire + queue entry + response fire + shared kill` 边界。
3. RTL 已整理为 `vsrc/cpu/` 和 `vsrc/vector/` 两部分。
4. 文档已整理为 `docs/cpu/`、`docs/vector/`、`docs/interface/` 三类。
5. COP payload 已携带原始指令 `instr`。
6. 当前执行切片支持 `funct3=0` dummy add 和 `funct3=1` 4x8-bit lane add。
7. COP 完成后由 CPU/WBU 统一提交，response fire 后保守 refetch `PC+4`。
8. custom 指令不会再被 stale scalar EXU valid 误提交。

## 当前关键文件

1. `vsrc/cpu/top/hcpu.v`：顶层 mux、kill、response fire 和 WBU 接入。
2. `vsrc/cpu/idu/idu.v`：识别 `custom-0`。
3. `vsrc/cpu/idu/idu_exu_regs.v`：透传 `pc/instr/src1/src2/rd/wen/is_cop_insn`。
4. `vsrc/vector/cop/idu_cop_regs.v`：COP depth-1 queue entry。
5. `vsrc/vector/cop/cop_backend.v`：后端 response/busy wrapper。
6. `vsrc/vector/cop/dummy_coprocessor.v`：当前固定延迟执行切片。
7. `sw/tests/cpu-tests/cop-vadd8.c`：当前最小真实向量算子回归。
8. `sw/tests/cpu-tests/cop-vadd8-chain.c`：连续 `vadd8` 回归。
9. `sw/tests/cpu-tests/cop-vadd8-after-add.c`：标量/COP 混合提交时序回归。

## 验证结果

向量端最近通过：

1. `make run`：`45 passed, 0 failed`。

CPU 侧同步后至少应继续覆盖：

1. `make sim sw`
2. `./build/Vsim_top ./sw/build/cop-vadd8.bin`
3. `./build/Vsim_top ./sw/build/cop-vadd8-chain.bin`
4. `./build/Vsim_top ./sw/build/cop-vadd8-after-add.bin`
5. `./build/Vsim_top ./sw/build/cop-chain.bin`
6. `./build/Vsim_top ./sw/build/sum.bin`
7. `./build/Vsim_top ./sw/build/load-store.bin`

## 已知风险

1. 不要重新引入已回退的 dedicated IDU->COP ready mux 路线。
2. 当前仍是单请求在飞模型，不支持多请求并发。
3. 暂无异常字段、向量 CSR、向量寄存器文件和独立访存。

## 推荐下一步

1. 保持 `539bf41` 的保守单请求在飞语义，不重新开放 response fire 同拍新 issue。
2. 继续把 `dummy_coprocessor` 拆名为真实的 vector execution slice。
3. 后续若要提高连续 COP 吞吐，单独设计多请求/scoreboard/精确 flush 语义。
