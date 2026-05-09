# COP 编码表（当前状态）

## 一、概述

本文档记录 HelloCPU 向量协处理器（COP）当前已实现的完整指令编码。

- 指令格式：RISC-V custom-0（`opcode=0x0b`）
- 源寄存器：`rs1`（i_src1）、`rs2`（i_src2）
- 目的寄存器：`rd`（o_res）
- 执行模型：单发射、2 周期延迟、flush 可取消在飞操作

---

## 二、编码总表

| funct3 | funct7 | 操作 | 返回值 | 内部状态 | 测试覆盖 |
|--------|--------|------|--------|----------|----------|
| 0 | 0 | scalar add | rs1 + rs2 | 无 | sum, cop-scalar-ext |
| 0 | 1 | scalar sub | rs1 - rs2 | 无 | cop-scalar-ext |
| 0 | 2 | scalar mul | (rs1 * rs2)[31:0] | 无 | cop-scalar-ext |
| 1 | * | vadd8 | 4x8-bit lane add | 无 | cop-vadd8, cop-vadd8-chain |
| 2 | * | vxor8 | rs1 ^ rs2 | 无 | cop-vxor8 |
| 3 | * | vand8 | rs1 & rs2 | 无 | cop-vand8, cop-mixed-lanes |
| 4 | * | scratch swap | 旧 scratch；写入 rs1 | scratch（32-bit） | cop-state, cop-state-branch, cop-state-mixed |
| 5 | * | vlen write | 旧 vlen；写入 rs1 | vlen（32-bit） | cop-vlen, cop-vlen-cross |
| 6 | * | vlen read | vlen | 无（只读） | cop-vlen, cop-vlen-cross |
| 7 | * | opcount read | op_count | 无（只读） | cop-opcount, cop-opcount-cross |

`*` 表示 funct7 字段未使用（被忽略）。

---

## 三、编码字段说明

```
31       25 24  20 19  15 14  12 11   7 6      0
┌─────────┬──────┬──────┬──────┬──────┬────────┐
│ funct7  │ rs2  │ rs1  │funct3│  rd  │ opcode │
│  [31:25]│[24:20]│[19:15]│[14:12]│[11:7]│ [6:0]  │
└─────────┴──────┴──────┴──────┴──────┴────────┘
opcode = 0x0b (custom-0)
```

- `funct3`：主操作选择（0-7）
- `funct7`：子操作选择（仅 funct3=0 使用）
- `rs1`：第一源操作数（GPR）
- `rs2`：第二源操作数（GPR）
- `rd`：目的寄存器（GPR）

---

## 四、内部状态说明

### 4.1 scratch（32-bit）

- reset 后为 0
- 通过 funct3=4 写入，写入延迟到完成拍（避免 refetch 重复写入）
- flush 取消未提交的写入，但不清零已提交的 scratch
- 语义：临时交换寄存器，软件可自由使用

### 4.2 vlen（32-bit）

- reset 后为 0
- 通过 funct3=5 写入，写入延迟到完成拍
- 通过 funct3=6 只读
- flush 取消未提交的写入，但不清零已提交的 vlen
- 语义：向量长度配置寄存器，为后续 VRF 准备

### 4.3 op_count（32-bit）

- reset 后为 0
- 每次 COP 操作完成时递增（含 opcount 自身）
- 通过 funct3=7 只读
- flush 不影响计数（只计已完成操作）
- 语义：调试/性能观测计数器

---

## 五、flush 语义

当 COP 在飞操作被 flush 时：
1. `busy` 清零
2. `countdown` 清零
3. `latched_res` 清零
4. `pending_scratch_write` 和 `pending_vlen_write` 清零（取消未提交写入）
5. `o_done` 清零
6. **不清零** `scratch`、`vlen`、`op_count`（已提交状态不受影响）

---

## 六、COP 接口信号

| 信号 | 方向 | 说明 |
|------|------|------|
| i_valid | in | 发射有效 |
| i_src1 | in | 源操作数 1 |
| i_src2 | in | 源操作数 2 |
| i_ins | in | 指令编码（funct3/funct7） |
| i_flush | in | flush 信号 |
| o_res | out | 结果 |
| o_done | out | 完成信号 |
| o_pre_ready | out | 后端可接受新请求 |
| o_post_valid | out | 响应有效 |
| o_busy | out | 后端忙 |

---

## 七、测试矩阵

| 测试名 | 覆盖操作 | 验证重点 |
|--------|----------|----------|
| sum | 标量 add | 基本标量功能 |
| cop-scalar-ext | sub, mul | funct7 扩展 |
| cop-scalar-ext-cross | sub, mul + vadd8 + state | funct7 与 lane/state 混合 |
| cop-vadd8 | vadd8 | lane add 基础 |
| cop-vadd8-chain | vadd8 x3 | 连续 lane ops |
| cop-vadd8-after-add | add + vadd8 | 标量后接 lane op |
| cop-vxor8 | vxor8 | lane xor |
| cop-vand8 | vand8 | lane and |
| cop-mixed-lanes | vadd8 + vxor8 + vand8 | 混合 lane ops |
| cop-state | scratch | 状态读写 |
| cop-state-branch | scratch + branch | 状态跨控制流 |
| cop-state-mixed | scratch + lane ops | 状态与 lane ops 互不干扰 |
| cop-scratch-vlen | scratch + vlen | 两个状态寄存器独立 |
| cop-vlen | vlen read/write | vlen 持久性 |
| cop-vlen-cross | vlen + lane ops | vlen 与 lane ops 互不干扰 |
| cop-opcount | opcount | 计数器递增 |
| cop-opcount-cross | opcount + mixed ops | 计数器跨多种操作 |
