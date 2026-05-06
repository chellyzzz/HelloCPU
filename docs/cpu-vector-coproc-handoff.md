# CPU 侧协处理器接入交接说明

本文档面向 CPU 端同学，给出当前最小协处理器闭环的状态、已经验证过的边界，以及我对后续 CPU 侧重构顺序的建议。

## 一、这次已经完成了什么

当前仓库已经有一版**稳定、可回归**的最小协处理器闭环。

这一版做了以下事情：

1. `IDU` 识别 `custom-0` 协处理器指令：`vsrc/idu/idu.v`
2. `idu_exu_regs` 透传 `is_cop_insn`：`vsrc/idu/idu_exu_regs.v`
3. 新增 `dummy coprocessor`：`vsrc/exu/dummy_coprocessor.v`
4. 在 `EXU` 内把协处理器作为一个长延迟结果源接入：`vsrc/exu/exu.v`
5. 顶层完成最小接线：`vsrc/top/hcpu.v`
6. 增加两个最小软件用例：
   - `sw/tests/cpu-tests/dummy.c`
   - `sw/tests/cpu-tests/cop-smoke.c`

当前 `dummy coprocessor` 的功能非常简单：

1. 指令编码使用 `custom-0` opcode `0x0b`
2. 行为是 `src1 + src2`
3. 当前稳定基线采用简化的完成脉冲语义
4. 后续再把它外拆成正式的 `issue / resp / busy / kill` 独立接口

## 二、当前版本已经验证通过什么

已通过的回归如下：

1. `./build/Vsim_top sw/build/add.bin`
2. `./build/Vsim_top sw/build/dummy.bin`
3. `./build/Vsim_top sw/build/cop-smoke.bin`

这说明当前最小闭环已经证明了三件事：

1. 不改前端主握手，也可以先挂上一个最小协处理器后端；
2. 标量主线 `add` 不会被当前接法破坏；
3. 协处理器指令可以完成“识别 -> 发射 -> 等待 -> 返回 -> 写回”闭环。

## 三、这版实现的定位

这版实现是一个**稳定 bring-up 基线**，不是最终向量协处理器架构。

它适合用于：

1. 对齐 CPU/协处理器的基础接口语义；
2. 验证最小长延迟后端不会破坏现有标量流水；
3. 给后续真正独立的 `cop backend` 提供可工作的起点。

它暂时不解决：

1. 独立 `cop_inflight` 生命周期管理；
2. 独立协处理器发射寄存路径；
3. 独立异常返回；
4. 独立向量访存；
5. 多请求在飞。

## 四、当前最大的 CPU 侧结构问题

### 1. `IFU/IDU` 握手不是标准寄存式 valid/ready

关键位置：`vsrc/ifu/ifu_idu_regs.v:23`

```verilog
assign o_post_valid = i_post_ready && icache_hit;
```

这个写法的问题是：

1. `valid` 不表示“当前寄存器里持有有效 payload”；
2. `valid` 直接依赖下游 `ready`；
3. 数据生命周期和接收时机耦合在一起。

对于纯顺序标量路径，这种实现还能工作；但对协处理器、多周期执行单元、旁路后端来说，它会明显放大接入难度。

### 2. `IDU->EXU` 当前不太像一个通用发射边界

`vsrc/idu/idu_exu_regs.v` 现在更像“给单条标量主通路服务的流水寄存器”，而不是一个容易扩展到多目标执行后端的发射边界。

缺的主要是：

1. 更明确的单次消费语义；
2. 更明确的 payload ownership；
3. 对旁路执行目标的天然扩展性。

### 3. `EXU` 已经开始承载过多角色

当前 `EXU` 同时承担：

1. ALU
2. LSU
3. MUL/DIV
4. 分支判定与预测纠正
5. 这次新增的 dummy cop

短期 bring-up 没问题，但长期看它会变成所有复杂性的汇聚点。

## 五、我对 CPU 端的建议

### 建议 1：先接受这版稳定基线，不要继续在它上面硬拧前端握手

这版已经证明最小闭环能跑通，而且标量回归稳定。

短期最好的做法是：

1. 把它作为协处理器 bring-up 基线保留下来；
2. 不要在同一个改动里同时重构前端握手和协处理器路径。

### 建议 2：下一步优先做独立 `IDU->COP` 小寄存器

这是我认为 CPU 侧最值得先做的事。

建议新增：

1. `idu_cop_regs`
2. 协处理器自己的 `valid/ready`
3. 单独的 `issue_fire` 生命周期

这样做的直接收益是：

1. 协处理器不再寄生在标量 `IDU->EXU` 主通路上；
2. 更容易保证“稳定发一次、只发一次”；
3. 更容易继续往独立 `cop backend` 演进。

### 建议 3：把 `IFU/IDU` 握手标准化视为单独结构任务

这件事很重要，但不建议和协处理器独立后端拆分绑在同一个 patch 里。

更稳妥的顺序是：

1. 先把协处理器拆出独立后端路径；
2. 保证最小功能继续可回归；
3. 再单独推进 `IFU/IDU` 标准寄存式 `valid/ready` 重构。

### 建议 4：继续保持统一提交点

`WBU` 统一提交这个方向是对的，建议继续保持：

1. 协处理器不直接改 GPR/CSR/PC/内存；
2. CPU 统一决定写回是否生效；
3. kill/flush 的最终解释权保留在 CPU。

## 六、建议的后续推进顺序

建议 CPU/协处理器后续按下面顺序推进：

1. 保留当前最小稳定基线；
2. 从 `EXU` 内部拆出真正独立的 `cop backend`；
3. 增加独立 `idu_cop_regs` 和 `cop_inflight`；
4. 让 `cop` 拥有自己的 `issue / resp / kill / busy` 外部接口；
5. 等协处理器后端边界稳定后，再回头重构 `IFU/IDU` 握手。

## 七、一句话结论

当前最小闭环已经证明协处理器方向可行，但 CPU 侧后续真正要补的不是 `dummy cop` 算法，而是更干净的发射边界，以及最终把协处理器从 `EXU` 内部拆成独立后端。
