# HelloCPU 验证文档

## 一、项目概述

**HelloCPU** 是一个自研 RISC-V 处理器（RV32IM）的 Verilator 仿真验证环境。

### 目标
- 让 CPU 通过全部 37 个软件测试用例
- 验证 RV32I 基础整数指令集和 RV32M 乘除法扩展的正确性
- 验证 AXI 总线与内存子系统的交互

---

## 二、环境架构

```
HelloCPU/
├── vsrc/          ← CPU RTL 源码 (IFU, IDU, EXU, WBU, ICache, LSU, RegFile, CSR, Xbar, 除法器, 乘法器)
├── sim/           ← 仿真环境 (sim_top.v, axi_ram.v, sim_main.cpp)
├── sw/            ← 软件框架
│   ├── tests/cpu-tests/  ← 37 个 CPU 测试用例
│   ├── benchmark/coremark/ ← CoreMark 基准测试
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
| **交叉编译** | riscv64-linux-gnu-gcc / riscv64-unknown-elf-gcc |
| **AXI RAM** | DPI-C 访问 C++ 内存数组 |
| **乘法器** | 2 周期流水线 |
| **除法器** | Radix-2 Non-Restoring, 34 周期 |

---

## 三、测试状态

**运行方式**: `make run`（全部）/ `make run ALL=<name>`（单个）

### 当前: 35 ✅ / 2 ❌

| # | 测试 | 状态 | 周期 | 分类 |
|---|------|------|------|------|
| 1 | add | ✅ | 2,426 | 基础运算 |
| 2 | add-longlong | ✅ | 3,957 | 64 位运算 |
| 3 | bit | ✅ | 1,643 | 位操作 |
| 4 | bubble-sort | ✅ | 13,878 | 算法 |
| 5 | crc32 | ✅ | 28,687 | M 扩展 |
| 6 | div | ✅ | 5,840 | 除法 |
| 7 | dummy | ✅ | 97 | 最小 |
| 8 | fact | ✅ | 1,290 | 递归 |
| 9 | fib | ✅ | 2,053 | 递归 |
| 10 | goldbach | ✅ | 9,325 | 算法 |
| 11 | hello-str | ✅ | 11,819 | 字符串 |
| 12 | hello | ✅ | 394 | UART |
| 13 | if-else | ✅ | 847 | 分支 |
| 14 | leap-year | ✅ | 7,216 | 分支 |
| 15 | load-store | ✅ | 1,476 | LSU |
| 16 | matrix-mul | ✅ | 31,273 | 矩阵/乘法 |
| 17 | max | ✅ | 2,627 | 分支 |
| 18 | mem | ✅ | 2,885 | 内存 |
| 19 | mersenne | ✅ | 172,918 | 算法 |
| 20 | min3 | ✅ | 2,861 | 分支 |
| 21 | mov-c | ✅ | 610 | 传送 |
| 22 | movsx | ✅ | 1,001 | 符号扩展 |
| 23 | mul-longlong | ❌ | 335 | 64 位乘法 |
| 24 | narcissistic | ❌ | 7,913 | 水仙花数 |
| 25 | pascal | ✅ | 12,746 | 算法 |
| 26 | prime | ✅ | 51,997 | 算法 |
| 27 | quick-sort | ✅ | 15,458 | 算法 |
| 28 | recursion | ✅ | 47,638 | 递归 |
| 29 | select-sort | ✅ | 10,565 | 算法 |
| 30 | shift | ✅ | 1,126 | 移位 |
| 31 | string | ✅ | 7,309 | 字符串 |
| 32 | sub-longlong | ✅ | 3,957 | 64 位运算 |
| 33 | sum | ✅ | 2,644 | 循环 |
| 34 | switch | ✅ | 723 | 跳转 |
| 35 | to-lower-case | ✅ | 3,616 | 字符处理 |
| 36 | unalign | ✅ | 963 | 非对齐访问 |
| 37 | wanshu | ✅ | 19,437 | 算法 |

---

## 四、待解决问题

| 测试 | 周期 | 可能原因 |
|------|------|----------|
| **narcissistic** | 7,913 | DIV/REM 多周期依赖转发问题，或除法器 REM 有误 |
| **mul-longlong** | 335 | MUL/MULHU 结果正确但测试仍失败，疑似流水线握手或测试数据读取问题 |

---

## 五、关键源文件

| 文件 | 说明 |
|------|------|
| `vsrc/top/hcpu.v` | CPU 顶层模块 |
| `vsrc/ifu/ifu.v` | 取指单元 |
| `vsrc/ifu/icache.v` | 指令缓存 |
| `vsrc/idu/idu.v` | 译码单元 |
| `vsrc/exu/exu.v` | 执行单元顶层 |
| `vsrc/exu/alu.v` | ALU |
| `vsrc/exu/multiplier.v` | 乘法器 (2 周期) |
| `vsrc/exu/divider.v` | 除法器 (34 周期) |
| `vsrc/exu/lsu.v` | 加载存储单元 |
| `vsrc/Registers/RegisterFile.v` | 寄存器堆 |
| `vsrc/Registers/Csrs.v` | CSR 寄存器 |
| `vsrc/include/Xbar.v` | AXI 交叉开关 |
| `sim/sim_top.v` | 仿真顶层 |
| `sim/sim_main.cpp` | Verilator 主程序 |
| `sw/tests/cpu-tests/` | 37 个测试用例 |
| `sw/benchmark/coremark/` | CoreMark 基准测试 |

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

---

## 七、已知问题

1. **axi_ram.v 宽度警告**: `r_addr` 32 位扩展为 34 位时有 WIDTHEXPAND 警告（不影响功能）
2. **wstrb 宽度警告**: 4 位 wstrb 传给 32 位期望的 DPI 函数（不影响功能）
3. **ALU 信号命名**: `srl_res` / `sra_res` 命名与实际功能互换，但 IDU 的 opt 映射同步互换，两处 bug 相消，功能正确但命名误导

---

## 八、变更日志

| 日期 | 变更 |
|------|------|
| 2026-05-01 | 初始环境搭建，37 个测试 27/37 通过 |
| 2026-05-01 | 修复 LSU non-cacheable 移位 → +6 通过 |
| 2026-05-01 | 修复乘法器 MUL 符号 + MULHSU src1_neg → +1 通过 |
| 2026-05-01 | 添加 exu_post_valid 门控 → 多周期指令转发正确性 |
| 2026-05-01 | 替换整个乘法器为 Verilog `*` 实现 → mersenne PASS |
| 2026-05-01 | 模块重命名: ysyx_23060124 → hcpu; 测试重组为 cpu-tests; 引入 CoreMark |
