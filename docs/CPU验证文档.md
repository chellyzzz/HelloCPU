# HelloCPU 验证文档

> 最后更新: 2026-05-01 | 状态: **37/37 全部通过 (100%)**

---

## 一、项目概述

**HelloCPU** 是一个自研 RISC-V 处理器（RV32IM）的 Verilator 仿真验证环境。

### 目标
- ✅ 让 CPU 通过全部 37 个软件测试用例
- ✅ 验证 RV32I 基础整数指令集和 RV32M 乘除法扩展的正确性
- ✅ 验证 AXI 总线与内存子系统的交互

---

## 二、环境架构

```
HelloCPU/
├── vsrc/          ← CPU RTL 源码 (IFU, IDU, EXU, WBU, ICache, LSU, RegFile, CSR, Xbar, 除法器, 乘法器)
├── sim/           ← 仿真环境 (sim_top.v, axi_ram.v, sim_main.cpp)
├── sw/            ← 软件框架
│   ├── tests/     ← 37 个测试用例
│   ├── lib/klib.c         ← C 标准库子集
│   ├── include/           ← 头文件 (trap.h 等)
│   ├── start.S            ← 启动代码
│   └── link.ld            ← 链接脚本
├── Makefile       ← 一键构建与运行
├── build/         ← 构建产物
└── docs/          ← 文档
```

### 关键技术参数

| 项目 | 说明 |
|------|------|
| **CPU 核心** | hcpu (5 级流水线: IFU → IDU → EXU → WBU) |
| **指令集** | RV32IM + Zicsr |
| **内存基址** | `0x30000000` |
| **UART 输出** | `0x10000000` (写 1 字节打印到终端) |
| **停机地址** | `0x10000004` (写任意值 = 仿真结束) |
| **仿真引擎** | Verilator 5.008 |
| **交叉编译** | riscv64-linux-gnu-gcc |
| **AXI RAM** | DPI-C 访问 C++ 内存数组 |
| **乘法器** | Booth-2 符号处理 + Verilog `*` 核心，2 周期流水线 |
| **除法器** | Radix-2 Non-Restoring, 34 周期 |

---

## 三、测试状态

**运行方式**: `make run`（全部）/ `make run ALL=<name>`（单个）

### ✅ 37/37 全部通过

| # | 测试 | 状态 | 周期 | 分类 |
|---|------|------|------|------|
| 1 | add | ✅ PASS | 2,426 | 基础运算 |
| 2 | add-longlong | ✅ PASS | 3,957 | 64 位运算 |
| 3 | bit | ✅ PASS | 1,643 | 位操作 |
| 4 | bubble-sort | ✅ PASS | 13,878 | 算法 |
| 5 | crc32 | ✅ PASS | 28,687 | M 扩展 |
| 6 | div | ✅ PASS | 5,939 | 除法 |
| 7 | dummy | ✅ PASS | 97 | 最小 |
| 8 | fact | ✅ PASS | 1,356 | 递归 |
| 9 | fib | ✅ PASS | 2,053 | 递归 |
| 10 | goldbach | ✅ PASS | 9,325 | 算法 |
| 11 | hello-str | ✅ PASS | 11,819 | 字符串 |
| 12 | hello | ✅ PASS | 394 | UART |
| 13 | if-else | ✅ PASS | 847 | 分支 |
| 14 | leap-year | ✅ PASS | 7,216 | 分支 |
| 15 | load-store | ✅ PASS | 1,476 | LSU |
| 16 | matrix-mul | ✅ PASS | 32,272 | 矩阵/乘法 |
| 17 | max | ✅ PASS | 2,627 | 分支 |
| 18 | mem | ✅ PASS | 2,885 | 内存 |
| 19 | mersenne | ✅ PASS | 172,921 | 算法 |
| 20 | min3 | ✅ PASS | 2,861 | 分支 |
| 21 | mov-c | ✅ PASS | 610 | 传送 |
| 22 | movsx | ✅ PASS | 1,001 | 符号扩展 |
| 23 | mul-longlong | ✅ PASS | 857 | 64 位乘法 |
| 24 | narcissistic | ✅ PASS | 64,162 | 水仙花数 |
| 25 | pascal | ✅ PASS | 12,746 | 算法 |
| 26 | prime | ✅ PASS | 51,997 | 算法 |
| 27 | quick-sort | ✅ PASS | 15,458 | 算法 |
| 28 | recursion | ✅ PASS | 47,638 | 递归 |
| 29 | select-sort | ✅ PASS | 10,565 | 算法 |
| 30 | shift | ✅ PASS | 1,126 | 移位 |
| 31 | string | ✅ PASS | 7,309 | 字符串 |
| 32 | sub-longlong | ✅ PASS | 3,957 | 64 位运算 |
| 33 | sum | ✅ PASS | 2,644 | 循环 |
| 34 | switch | ✅ PASS | 723 | 跳转 |
| 35 | to-lower-case | ✅ PASS | 3,616 | 字符处理 |
| 36 | unalign | ✅ PASS | 963 | 非对齐访问 |
| 37 | wanshu | ✅ PASS | 19,437 | 算法 |

---

## 四、修复记录

### Bug 1: LSU non-cacheable 访存数据移位 (`vsrc/exu/lsu.v`)

**现象**: `load-store`, `to-lower-case`, `unalign` 等 6 个测试失败

**根因**: LSU 对所有访存统一使用 `raw_word >> lat_shift8` 移位。Non-cacheable 访问通过 DPI-C 直接读写内存数组，数据已按地址定位到正确字节位置（bits[7:0] 即为目标字节），进一步移位会破坏数据。

**修复**: 新增 `load_src` / `eff_wstrb` / `eff_wdata` 信号，根据 `lat_cacheable` 决定是否移位。Cacheable 路径保持原移位逻辑，non-cacheable 路径使用原始值。

### Bug 2: 乘法器 MUL 指令符号错误 (`vsrc/exu/multiplier.v`)

**现象**: `matrix-mul` 失败

**根因**: MUL (func3=000) 返回 `unsigned_product[31:0]`（绝对值乘积的低32位）。当两操作数符号不同时，结果应为负数的低32位（two's complement），但绝对值乘积无法表达负值。注释 "two's complement low word is same" 是错误的。

**修复**: MUL 分支改用 `signed_product[31:0]` 替代 `unsigned_product[31:0]`

### Bug 3: 乘法器 MULHSU 操作数符号遗漏 (`vsrc/exu/multiplier.v`)

**根因**: `src1_neg = ~mul_op[1] & src1[31]` 未覆盖 MULHSU (op=10) 时 src1 为 signed 的情况

**修复**: `src1_neg` 改为 `(~mul_op[1] | ~mul_op[0]) & src1[31]`

### Bug 4: 寄存器堆多周期指令转发未门控 (`vsrc/Registers/RegisterFile.v`)

**现象**: 理论正确性漏洞（虽未单独触发测试失败）

**根因**: 寄存器堆无条件转发 `exu_wdata`。多周期指令（DIV/REM/MUL）在计算过程中 `exu_wdata` 为中间值，导致后续依赖指令读到错误数据。

**修复**: 新增 `exu_post_valid` 输入端口，连接 EXU 的 `o_post_valid`（`exu2wbu_valid`）。读端口转发逻辑加入门控：`raddr == exu_rd && exu_wen && exu_post_valid`

### Bug 5: 乘法器 `mul_done` 电平信号导致乱序写入 (`vsrc/exu/multiplier.v`) ⭐ 关键

**现象**: `narcissistic` (DIV/REM/MUL) 和 `mul-longlong` (MUL/MULH 连续) 失败

**根因**: `mul_done = pipe_valid` 是**电平信号**而非脉冲。当连续 MUL 指令时，`pipe_valid` 跨指令边界保持高电平，导致：
1. EXU 认为第二条 MUL 指令立刻完成（实际刚进入流水线）
2. EXU→WBU 寄存器在错乱时刻捕获，把前一条指令的结果写到下一条指令的目的寄存器
3. MULH 结果被写入 a7 而非 a5（寄存器堆调试确认）

**修复**: 引入 `mul_busy` 状态机：
- 第 1 周期：`mul_valid && !mul_busy` → 设为忙
- 第 2 周期：`mul_busy` → 结果就绪，产生 1 周期脉冲
- 其他：空闲

---

## 五、关键源文件

| 文件 | 说明 | 修改 |
|------|------|------|
| `vsrc/top/hcpu.v` | CPU 顶层模块 | ✅ exu_post_valid 连接 |
| `vsrc/exu/lsu.v` | 加载存储单元 (含 DCache) | ✅ non-cacheable 移位修复 |
| `vsrc/exu/multiplier.v` | 混合乘法器 | ✅ MUL 符号 + MULHSU + mul_done 脉冲 |
| `vsrc/Registers/RegisterFile.v` | 寄存器堆 | ✅ exu_post_valid 门控 |
| `vsrc/exu/divider.v` | 除法器 (34 周期) | - |
| `vsrc/exu/alu.v` | ALU | - |
| `vsrc/exu/exu.v` | 执行单元顶层 | - |
| `vsrc/idu/idu.v` | 译码单元 | - |
| `vsrc/ifu/ifu.v` | 取指单元 | - |
| `vsrc/wbu/wbu.v` | 写回单元 | - |
| `sim/sim_top.v` | 仿真顶层 | - |
| `sim/sim_main.cpp` | Verilator 主程序 | - |

---

## 六、调试方法

```bash
make run ALL=<test_name>    # 运行单个测试
make sim                     # 重新编译仿真
make sw                      # 重新编译软件
make clean                   # 清理
gtkwave wave.vcd             # 查看波形
```

### 调试技巧
1. 在 `sim_main.cpp` 中启用 `--debug` 模式打印内存访问地址和数据
2. 在 Verilog 源码中临时添加 `$display` 观察信号
3. 用 `--trace` 生成 VCD 波形，在 GTKWave 中分析总线时序
4. 对比 `.txt` 反汇编文件确认指令生成正确
5. 寄存器堆写入追踪可确认值是否正确写入目标寄存器

---

## 七、已知问题（技术债务）

1. **axi_ram.v 宽度警告**: `r_addr` 32 位扩展为 34 位时有 WIDTHEXPAND 警告（不影响功能）
2. **wstrb 宽度警告**: 4 位 wstrb 传给 32 位期望的 DPI 函数（不影响功能）
3. **ALU 信号命名**: `srl_res` / `sra_res` 命名与实际功能互换，但 IDU 的 opt 映射同步互换，两处 bug 相消，功能正确但命名误导
4. **hcpu.v 代码清洁度**: 早期 sed 命令残留空行（不影响编译），建议手动清理
5. **乘法器**: 当前为混合方案（Booth-2 符号处理 + Verilog `*` 核心），原 Booth-2 Wallace Tree 的 sign extension compensation 存在复杂位偏差未修复

---

## 八、变更日志

| 日期 | 变更 | 通过率 |
|------|------|--------|
| 2026-05-01 | 初始环境搭建 | 27/37 (73%) |
| 2026-05-01 | LSU non-cacheable 移位修复 → +6 | 33/37 (89%) |
| 2026-05-01 | 乘法器 MUL 符号 + MULHSU → +1 | 34/37 (92%) |
| 2026-05-01 | 寄存器堆 exu_post_valid 门控 | 34/37 |
| 2026-05-01 | 乘法器整体替换为 Verilog `*` → mersenne PASS | 35/37 (95%) |
| 2026-05-01 | 消除 ysyx-workbench 符号链接依赖 | 35/37 |
| 2026-05-01 | **mul_done 脉冲修复 → +2** | **37/37 (100%)** |
