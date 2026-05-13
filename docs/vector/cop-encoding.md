# COP 编码表（当前状态）

## 一、概述

本文档记录 HelloCPU 向量协处理器（COP）当前已实现的完整指令编码。

- 指令格式：RISC-V custom-0（`opcode=0x0b`）
- 源寄存器：`rs1`（i_src1）、`rs2`（i_src2）
- 目的寄存器：`rd`（o_res）
- 执行模型：单发射，非访存操作固定短延迟，访存操作按内存响应完成，flush 可取消在飞操作

### RVV 兼容性说明

当前实现是**自定义协处理器原型**，使用 `custom-0` 指令空间，**不兼容 RVV 标准**。最终目标是迁移到标准 RVV 编码，支持：
- 标准 RVV opcodes（OP-V、LOAD-FP 等）
- 32 个向量寄存器（v0-v31），可配置元素宽度
- `vsetvl`/`vsetvli` 配置指令
- 向量掩码和向量访存

当前自定义编码是 RVV 迁移的验证平台，用于验证 COP 接口、状态管理和 VRF 基础设施。

---

## 二、编码总表

| funct3 | funct7 | 操作 | 返回值 | 内部状态 | 测试覆盖 |
|--------|--------|------|--------|----------|----------|
| 0 | 0 | scalar add | rs1 + rs2 | 无 | sum, cop-scalar-ext |
| 0 | 1 | scalar sub | rs1 - rs2 | 无 | cop-scalar-ext |
| 0 | 2 | scalar mul | (rs1 * rs2)[31:0] | 无 | cop-scalar-ext |
| 0 | 3 | vload | GPR → VRF，返回旧 v[rs2] | VRF | cop-vrf-load-store |
| 0 | 4 | vstore | VRF → GPR，只读 | 无 | cop-vrf-load-store |
| 0 | 5 | vrf lane add | v0 + v1（4x8-bit） | VRF | cop-vrf-vadd8 |
| 0 | 6 | vrf lane xor | v0 ^ v1 | VRF | cop-vrf-vadd8 |
| 0 | 7 | vrf lane and | v0 & v1 | VRF | cop-vrf-vadd8 |
| 0 | 8 | vrf lane sub | v0 - v1（4x8-bit） | VRF | cop-vrf-vadd8 |
| 0 | 9 | vrf lane mul | v0 * v1（4x8-bit，取低 8 位） | VRF | cop-vrf-mul-shift |
| 0 | 10 | vrf lane sll | v0 << v1（4x8-bit，每字节低 3 位） | VRF | cop-vrf-mul-shift |
| 0 | 11 | vrf lane srl | v0 >> v1（4x8-bit，每字节低 3 位） | VRF | cop-vrf-mul-shift |
| 0 | 12 | vrf lane sra | v0 >>> v1（4x8-bit，符号扩展） | VRF | cop-vrf-sra-or |
| 0 | 13 | vrf lane or | v0 \| v1 | VRF | cop-vrf-sra-or |
| 0 | 14 | vload_mem | 内存 4 字节 → v0，返回 v0 | VRF + memory | cop-vload-mem, cop-vload-store-mem, cop-vload-repeat-mem |
| 0 | 15 | vstore_mem | v0 低 4 字节 → 内存，返回 v0 | memory | cop-vstore-mem, cop-vload-store-mem |
| 0 | 16 | vtype_write | 写入 P1 prototype vtype，返回旧值 | vtype | cop-vtype, cop-vtype-illegal, cop-vtype-cross |
| 0 | 17 | vtype_read | 读取 P1 prototype vtype | 无（只读） | cop-vtype, cop-vtype-cross |
| 0 | 18 | vstate_add | 按 prototype `vl/vtype` 执行加法 | 无 | cop-vstate-add, cop-vstate-add-sew32 |
| 0 | 19 | vsetivli_p | 写入 prototype `vl/vtype`，返回新 `vl` | vlen + vtype | cop-vsetivli-proto |
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

### 4.4 vtype（32-bit，P1 prototype）

- reset 后为 `0x80000000`，表示 `vill=1`
- 通过 `funct3=0, funct7=16` 写入，写入延迟到完成拍
- 通过 `funct3=0, funct7=17` 只读
- 仅接受 `SEW=8/32` 且 `LMUL=m1` 的 prototype 编码
- unsupported `SEW/LMUL` 写入 `0x80000000`
- flush 取消未提交的 vtype 写入，但不清零已提交的 vtype

### 4.5 P1C/P2 prototype state consumer

- `funct3=0, funct7=18` 是 `vstate_add`，只消费 prototype `vl/vtype`，不写 VRF
- `vtype.vill=1` 时返回 `0x80000000`，不执行近似加法
- `SEW=8` 时只计算 `0 <= element_index < vl` 的 byte lane，tail byte 当前返回 0
- `SEW=32` 时 `vl>0` 返回 32-bit 加法，`vl=0` 返回 0
- `funct3=0, funct7=19` 是 `vsetivli_p`，把 `rs1` 作为 AVL、`rs2` 作为 prototype vtype immediate，返回饱和后的新 `vl`
- `vsetivli_p` 仍是 custom-0 prototype，不是标准 RVV `vsetivli`

---

## 五、flush 语义

当 COP 在飞操作被 flush 时：
1. `busy` 清零
2. `countdown` 清零
3. `latched_res` 清零
4. `pending_scratch_write` 和 `pending_vlen_write` 清零（取消未提交写入）
5. `o_done` 清零
6. **不清零** `scratch`、`vlen`、`op_count`（已提交状态不受影响）

访存操作额外遵守以下规则：

1. killed load 的晚到响应必须被吸收，不写入 VRF 或 GPR。
2. killed store 不应在被 kill 后新发起架构可见写入。
3. COP memory completion 只在未被 kill 时返回给 COP backend。
4. pending-kill 语义由 directed Verilator target `cop_mem_pending_kill` 覆盖。
5. directed sim 的 COP-specific AR/R/AW/W/B debug pulses 只在 `COP_MEM_PENDING_KILL_TB` 构建导出。

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
| o_cop_mem_req_valid | out | COP 访存请求有效 |
| o_cop_mem_req_store | out | COP 访存请求为 store |
| o_cop_mem_req_addr | out | COP 访存地址 |
| o_cop_mem_req_wdata | out | COP store 写数据 |
| o_cop_mem_req_size | out | COP 访存大小，当前为 byte |
| i_cop_mem_resp_valid | in | COP 访存响应有效 |
| i_cop_mem_resp_rdata | in | COP load 返回数据 |

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
| cop-vrf-load-store | vload, vstore | VRF 读写基本功能 |
| cop-vrf-vadd8 | vrf lane add/xor/and/sub | VRF lane ops |
| cop-vrf-mul-shift | vrf lane mul/sll/srl | VRF lane 乘法和移位 |
| cop-vrf-sra-or | vrf lane sra/or | VRF lane 算术右移和按位或 |
| cop-vload-mem | vload_mem | 从内存加载 4 字节到 v0 |
| cop-vstore-mem | vstore_mem | 将 v0 低 4 字节写回内存 |
| cop-vload-store-mem | vload_mem + vstore_mem | COP load/store 往返 |
| cop-vload-repeat-mem | vload_mem x2 | 重复地址 COP load 和 pending-kill directed image |
| cop-vstore-repeat-mem | vstore_mem x2 | 重复 COP store 和 pre-accept store-kill directed image |
| cop_mem_pending_kill | vload_mem + test-only kill | COP load response 晚到后被 kill 吸收 |
| cop_mem_store_directed | vstore_mem + test-only monitor | COP store AW/W/B owner path 和 B 后 response |
| cop_mem_store_kill | vstore_mem + test-only kill | AW/W 接受前 killed store 无 bus side effect，后续 store 恢复 |
| cop-vtype | vtype write/read | supported `vtype` 写入/读回 |
| cop-vtype-illegal | vtype write/read | unsupported `SEW/LMUL` 置 `vill=1` |
| cop-vtype-cross | vlen + vtype | `vl` 与 `vtype` 状态互不污染 |
| cop_vtype_kill | backend vtype write/read + flush | pending `vtype` 写入被 flush 取消，后续写入恢复 |
| cop-vstate-add | vstate_add + vlen/vtype | `SEW=8` 下 `vl/vtype` gating 和 `vill` guard |
| cop-vstate-add-sew32 | vstate_add + vlen/vtype | `SEW=32` 下 `vl=0/1` 和 illegal guard |
| cop-vsetivli-proto | vsetivli_p + vstate_add | custom vset prototype 同时设置 `vl/vtype` |
