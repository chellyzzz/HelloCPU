# HelloCPU 验证文档

> 最后更新: 2026-05-01（第三轮修复后）

---

## 一、项目概述

**HelloCPU** 是一个自研 RISC-V 处理器（RV32IM）的 Verilator 仿真验证环境。

### 目标
- 让 CPU 通过全部 37 个软件测试用例
- 验证 RV32I 基础整数指令集的正确性
- 验证 RV32M 乘除法扩展的正确性
- 验证 AXI 总线与内存子系统的交互

---

## 二、环境架构

```
/home/chelly/HelloCPU/
├── vsrc/          ← CPU RTL 源码（IFU, IDU, EXU, WBU, ICache, LSU, 寄存器, CSR, Xbar, CLINT, 除法器, 乘法器）
├── sim/           ← 仿真环境（sim_top.v, axi_ram.v, sim_main.cpp）
├── sw/            ← 软件测试框架（start.S, link.ld, 37 个测试用例）
├── Makefile       ← 一键构建与运行
├── build/         ← 构建产物（Vsim_top, .bin 文件）
└── docs/          ← 文档
```

### 关键技术细节
| 项目 | 说明 |
|------|------|
| **CPU 核心** | ysyx_23060124（5级流水线：IFU→IDU→EXU→WBU） |
| **指令集** | RV32IM（I 基础 + M 乘除） |
| **内存基址** | `0x30000000`（TEXT_BASE） |
| **UART 输出** | `0x10000000`（写1字节打印到终端） |
| **停机地址** | `0x10000004`（写任意值 = 仿真结束） |
| **仿真引擎** | Verilator 5.008（C++ 时序仿真） |
| **交叉编译** | riscv64-unknown-elf-gcc |
| **AXI RAM** | 通过 DPI-C 调用 pmem_read/pmem_write 访问 C++ 内存数组 |

---

## 三、测试状态

**运行方式**: `make run`（全部）/ `make run ALL=<name>`（单个）

### 当前结果：35 通过 ✅ / 2 失败 ❌（2026-05-01 第三轮）

| # | 测试名 | 状态 | 周期数 | 分类 |
|---|--------|------|--------|------|
| 1 | add | ✅ PASS | 2,426 | 基础运算 |
| 2 | add-longlong | ✅ PASS | 3,957 | 64位运算 |
| 3 | bit | ✅ PASS | 1,643 | 位操作 |
| 4 | bubble-sort | ✅ PASS | 13,878 | 算法 |
| 5 | crc32 | ✅ PASS | 28,687 | M扩展/复杂 |
| 6 | div | ✅ PASS | 5,840 | 除法 |
| 7 | dummy | ✅ PASS | 97 | 最小 |
| 8 | fact | ✅ PASS | 1,290 | 递归 |
| 9 | fib | ✅ PASS | 2,053 | 递归 |
| 10 | goldbach | ✅ PASS | 9,325 | 算法 |
| 11 | hello-str | ✅ PASS | 11,819 | 字符串 |
| 12 | hello | ✅ PASS | 394 | UART输出 |
| 13 | if-else | ✅ PASS | 847 | 分支 |
| 14 | leap-year | ✅ PASS | 7,216 | 分支 |
| 15 | load-store | ✅ PASS | 1,476 | LSU |
| 16 | matrix-mul | ✅ PASS | 31,273 | 矩阵/乘法 |
| 17 | max | ✅ PASS | 2,627 | 分支 |
| 18 | mem | ✅ PASS | 2,885 | 内存 |
| 19 | mersenne | ✅ PASS | 172,918 | 算法 |
| 20 | min3 | ✅ PASS | 2,861 | 分支 |
| 21 | mov-c | ✅ PASS | 610 | MOV指令 |
| 22 | movsx | ✅ PASS | 1,001 | 符号扩展 |
| 23 | mul-longlong | ❌ FAIL (exit 1) | 335 | 64位乘法 |
| 24 | narcissistic | ❌ FAIL (exit 1) | 7,913 | 水仙花数 |
| 25 | pascal | ✅ PASS | 12,746 | 算法 |
| 26 | prime | ✅ PASS | 51,997 | 算法 |
| 27 | quick-sort | ✅ PASS | 15,458 | 算法 |
| 28 | recursion | ✅ PASS | 47,638 | 递归 |
| 29 | select-sort | ✅ PASS | 10,565 | 算法 |
| 30 | shift | ✅ PASS | 1,126 | 移位 |
| 31 | string | ✅ PASS | 7,309 | 字符串 |
| 32 | sub-longlong | ✅ PASS | 3,957 | 64位运算 |
| 33 | sum | ✅ PASS | 2,644 | 循环 |
| 34 | switch | ✅ PASS | 723 | 跳转 |
| 35 | to-lower-case | ✅ PASS | 3,616 | 字符处理 |
| 36 | unalign | ✅ PASS | 963 | 非对齐访问 |
| 37 | wanshu | ✅ PASS | 19,437 | 算法 |

### 本轮新通过的测试（共8个）
| 测试 | 原状态 | 根因 | 修复文件 |
|------|--------|------|----------|
| load-store | ❌ FAIL | 非cacheable加载数据移位错误 | lsu.v |
| to-lower-case | ❌ FAIL | 同上（LBU读取错位字节） | lsu.v |
| unalign | ❌ FAIL | 非对齐字加载移位错误 | lsu.v |
| hello-str | ❌ FAIL | sprintf/strcmp依赖正确LSU | lsu.v（副作用） |
| string | ❌ FAIL | strcmp/strcat/memcmp依赖正确LSU | lsu.v（副作用） |
| crc32 | ❌ FAIL | 复杂位运算依赖正确LSU | lsu.v（副作用） |
| matrix-mul | ❌ FAIL | MUL指令结果符号错误 | multiplier.v |
| mersenne | ⏱️ TIMEOUT | 64位取模依赖MUL/MULH正确性 | multiplier.v |

---

## 四、修复详情

### 🔧 修复 1：LSU 非 Cacheable 访问数据移位问题（`vsrc/exu/lsu.v`）

**根因**: LSU 对所有访存（cacheable + non-cacheable）统一使用 `raw_word >> lat_shift8` 移位。Non-cacheable 访问通过 DPI-C 直接读写内存数组，数据已按地址定位到正确字节位置（bits[7:0]即为目标字节）。进一步移位会破坏数据。

**改动**:
- 新增 `load_src` 信号：`lat_cacheable ? shifted_data : raw_word`，根据是否 cacheable 决定是否移位
- 新增 `eff_wstrb`/`eff_wdata` 信号：对 non-cacheable 写使用未移位的 strb 和 data
- W channel 的 `M_AXI_WDATA`/`M_AXI_WSTRB` 改用 `eff_wdata`/`eff_wstrb`

### 🔧 修复 2：乘法器 MUL 指令结果符号错误（`vsrc/exu/multiplier.v`）

**根因**: MUL (func3=000) 指令返回 `unsigned_product[31:0]`（绝对值乘积的低32位）。当两操作数符号不同时，结果应为负数的低32位（two's complement），但绝对值乘积无法表达负值。

**改动**:
- `mul_result` 的 MUL 分支改用 `signed_product[31:0]` 替代 `unsigned_product[31:0]`
- `signed_product` 在 `pipe_neg` 为真时已做 two's complement 求负

### 🔧 修复 3：乘法器 MULHSU 操作数符号处理（`vsrc/exu/multiplier.v`）

**根因**: `src1_neg = ~mul_op[1] & src1[31]` 未覆盖 MULHSU (op=10) 的情况（此时 src1 为 signed，但 ~mul_op[1]=0）

**改动**:
- `src1_neg` 改为 `(~mul_op[1] | ~mul_op[0]) & src1[31]`，覆盖 MUL/MULH/MULHSU 三种 signed src1 情况

### 🔧 修复 4：乘法器整体替换（`vsrc/exu/multiplier.v`）

**根因**: 原 Booth-2 + Wallace Tree 实现存在两个深度 bug：
1. 零 partial product 时 sign extension compensation 仍添加偏移位，导致小数值乘法结果错误
2. sign_correction 位位置计算错误（用了2*gi而非33+2*gi）

**改动**: 将整个 Booth-2 Wallace Tree 替换为 Verilog 内建 `$signed()` × `$signed()` 的简洁实现，保留2周期流水线接口

**效果**: mersenne 从 TIMEOUT → PASS（172K cycles），MUL/MULH 结果完全正确

---

## 五、仍待解决（2个失败 + 已知问题）

| 测试 | 周期 | 可能原因 | 优先级 |
|------|------|----------|--------|
| **narcissistic** | 7,913 | DIV/REM 多周期依赖转发仍存问题，或除法器 REM 计算有误 | 🟡 中 |
| **mul-longlong** | 335 | MUL/MULH值现在正确(0x19d29ab9/0xdb1a18e4)，但测试仍在372周期失败，怀疑是流水线手信号或ans数组读取问题 | 🟡 中 |
| **mersenne** | TIMEOUT | 已修复 → PASS（172K cycles）| ✅ 已解决 |

### narcissistic 分析
- 测试依赖 `DIV(n, 100)`, `DIV/REM(n, 10)` 等指令
- 反汇编确认使用硬件 `div`/`rem` 指令
- 存在 DIV→REM 的 RAW 数据冒险（如 `div a1,n,10` 后紧跟 `rem a1,a1,10`）
- 已添加寄存器堆 exu_post_valid 门控，但问题仍在，需进一步调试

### mul-longlong 分析
- `mul()` 函数被编译器展开为 MUL + MULHU + ADD 序列实现64位乘法
- 不用 klib.c 的 `__muldi3`（编译器内联了指令序列）
- 快速失败（335 cycles），怀疑某次 MUL/MULHU 结果偏离预期

### mersenne 分析
- 使用 `((long long)i * i) % d`，涉及64位取模
- 5M周期超时，可能是 `__moddi3` 中的 `(a < 0)` 判断或循环条件导致死循环
- 需检查64位比较/取模的软件实现

---

## 六、关键源码文件

| 文件 | 说明 | 本轮修改 |
|------|------|----------|
| `vsrc/top/ysyx_23060124.v` | CPU 顶层 | ✅ 添加 exu_post_valid 连接 |
| `vsrc/ifu/ifu.v` | 取指单元 | - |
| `vsrc/idu/idu.v` | 译码单元 | - |
| `vsrc/exu/exu.v` | 执行单元顶层 | - |
| `vsrc/exu/alu.v` | ALU | - |
| `vsrc/exu/multiplier.v` | Booth-2 乘法器（2周期流水线） | ✅ MUL 符号修复 + MULHSU 修复 |
| `vsrc/exu/divider.v` | 除法器（34周期） | - |
| `vsrc/exu/lsu.v` | 加载存储单元（含 DCache） | ✅ non-cacheable 移位修复 |
| `vsrc/Registers/RegisterFile.v` | 寄存器堆 | ✅ exu_post_valid 门控 |
| `vsrc/wbu/wbu.v` | 写回单元 | - |
| `vsrc/ifu/icache.v` | 指令缓存 | - |
| `sim/axi_ram.v` | AXI4-Lite RAM 模型 | - |
| `sim/sim_main.cpp` | Verilator 主程序 | - |
| `sw/lib/klib.c` | C 标准库子集（sprintf, strcmp, __muldi3 等） | - |
| `sw/start.S` | 启动代码（清零 BSS, 调用 main） | - |
| `sw/link.ld` | 链接脚本 | - |

---

## 七、调试方法

```bash
# 运行单个测试
make run ALL=<test_name>

# 查看波形
gtkwave wave.vcd

# 重新编译 Verilator 仿真
make sim

# 重新编译软件
make sw

# 清理
make clean
```

### 调试技巧
1. 在 `sim_main.cpp` 中启用 `--debug` 模式打印 pmem_read 地址和数据
2. 在 Verilog 源码中添加 `$display` 观察信号（完成后需移除/注释）
3. 用 `--trace` 生成 VCD 波形，在 GTKWave 中分析总线时序
4. 对比 `.txt` 反汇编文件确认指令生成正确
5. 对于多周期指令调试，可在 `exu.v` 中取消注释 muldiv 调试 `$display`

---

## 八、已知问题（技术债务）

1. **axi_ram.v 宽度警告**: `r_addr` 32位扩展为34位时有 WIDTHEXPAND 警告（不影响功能）
2. **wstrb 宽度警告**: 4位 wstrb 传给32位期望的 DPI 函数（不影响功能）
3. **乘法器 $display 已禁用** — multiplier.v 的调试打印已注释
4. **ysyx_23060124.v 代码清洁度**: 本次修改中 sed 命令残留了若干空行（不影响编译），建议后续手动清理
5. **ALU 信号命名**: `srl_res` 和 `sra_res` 命名与实际功能相反（`srl_res` 实际做算术右移，`sra_res` 做逻辑右移），但 IDU 的 opt 映射也与之一致地"反了"，两处 bug 相消，功能正确但误导性极强

---

## 九、变更日志

| 日期 | 变更 | 作者 |
|------|------|------|
| 2026-05-01 | 初始化文档，运行全部37个测试，27通过/10失败 | Cline |
| 2026-05-01 | 禁用 multiplier.v 的 $display 调试输出 | Cline |
| 2026-05-01 | **修复 LSU non-cacheable 数据移位**：load-store, to-lower-case, unalign, hello-str, string, crc32 通过 | Cline |
| 2026-05-01 | **修复乘法器 MUL 符号**：matrix-mul 通过 | Cline |
| 2026-05-01 | **修复乘法器 MULHSU src1_neg**：预防性修复 | Cline |
| 2026-05-01 | **寄存器堆 exu_post_valid 门控**：多周期指令转发正确性改进 | Cline |
| 2026-05-01 | **替换整个乘法器为 Verilog * 实现**：mersenne PASS，MUL/MULH结果正确 | Cline |
| 2026-05-01 | 更新文档：35/37 通过，2个待解决 | Cline |
