# HelloCPU 验证文档

> 最后更新: 2026-05-02 | 状态: **37/37 全部通过 (100%)**

---

## 一、项目概述

**HelloCPU** 是一个自研 RISC-V 处理器（RV32IM）的 Verilator 仿真验证环境。

### 目标
- ✅ 让 CPU 通过全部 37 个软件测试用例
- ✅ 验证 RV32I 基础整数指令集和 RV32M 乘除法扩展的正确性
- ✅ 验证 AXI 总线与内存子系统的交互

---

## 二、CPU 设计架构

### 流水线概览

```
         握手控制
    ┌───────────────┐
    │  o_pre_ready  │ ← 后级通知前级"可以接收"
    │ o_post_valid  │ → 前级通知后级"数据有效"
    └───────────────┘

  ┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐    ┌──────┐
  │ IFU  │───→│ IDU  │───→│ EXU  │───→│ WBU  │───→│ RF   │
  │ 取指 │    │ 译码 │    │ 执行 │    │ 写回 │    │ 寄存器│
  └──┬───┘    └──────┘    └──┬───┘    └──────┘    └──────┘
     │                      │
     ▼                      ▼
  ┌──────┐            ┌──────────────┐
  │ICache│            │  LSU (DCache)│
  │ 指令 │            │  乘/除法器    │
  │ 缓存 │            │  ALU         │
  └──┬───┘            └──────┬───────┘
     │                       │
     └───────┬───────────────┘
             ▼
       ┌──────────┐
       │   Xbar   │  ← AXI 交叉开关（IFU/LSU/CLINT 仲裁）
       └────┬─────┘
            ▼
       ┌──────────┐
       │ AXI RAM  │  ← 仿真内存 (DPI-C)
       └──────────┘
```

**5 级流水线**，级间通过 valid/ready 握手控制停滞和推进。

### IFU — 取指单元

- 根据 `pc_next` 生成取指地址
- 通过 ICache 从 AXI 总线获取指令
- ICache 命中时 1 周期返回；未命中时发起 AXI 突发读（4-word cache line）
- 支持 `fence.i` 指令刷新缓存

### IDU — 译码单元

- 纯组合逻辑，单周期完成
- 支持全部 RV32I + RV32M 指令译码
- 生成立即数、ALU 操作码、EXU 选项、读写使能、分支/跳转信号
- 处理 CSR 访问（ecall/mret/csrrw/csrrs）

### EXU — 执行单元

| 子模块 | 周期 | 说明 |
|--------|------|------|
| **ALU** | 1 | 加减、逻辑、移位、比较（10 种操作） |
| **Multiplier** | 2 | Booth-2 编码 + Wallace Tree CSA 压缩 |
| **Divider** | 34 | Radix-2 Non-Restoring，支持 DIV/DIVU/REM/REMU |
| **LSU** | 不定 | Load/Store 单元，含 4 路组相联 DCache (写回+写分配) |
| **Branch** | 1 | 6 种分支条件判断 (BEQ/BNE/BLT/BGE/BLTU/BGEU) |

EXU 根据指令类型选择对应功能单元，多周期单元（LSU/MUL/DIV）通过 `o_pre_ready` 信号产生流水线反压。

### WBU — 写回单元

- 接收 EXU 结果，写入寄存器堆或 CSR
- 处理分支/跳转/ecall/mret 的 PC 更新

### 总线架构

```
IFU ──AR/R──┐
            ├── Xbar ── AXI4-Lite ── RAM (DPI-C)
LSU ──全通道──┘
```

- IFU 仅使用 AXI 读通道
- LSU 使用 AXI 全通道（读/写地址、读/写数据、写响应）
- Xbar 对两者仲裁（IFU 优先）

### 寄存器堆

- 32 × 32-bit 通用寄存器（x0 恒为 0）
- 双读端口 + 单写端口
- **三级转发**: EXU 结果 → WBU 结果 → 寄存器值
- `exu_post_valid` 门控防止多周期指令中间值被转发

### CSR

- mstatus, mepc, mtvec, mcause, mvendorid, marchid
- mcycle: 64-bit 周期计数器
- 支持 csrrw/csrrs 指令

---

## 三、验证环境设计

### 整体流程

```
  C 测试源码 (.c)
       │ riscv64-linux-gnu-gcc -march=rv32im
       ▼
  RISC-V ELF (.elf)
       │ objcopy -O binary
       ▼
  裸二进制 (.bin)
       │ sim_main.cpp 加载到内存数组
       ▼
  Verilator 仿真 ─── CPU RTL ─── AXI RAM (DPI-C) ─── C++ mem[]
       │
       ▼
  UART 输出 / 测试结果 (PASS/FAIL)
```

### Verilator 仿真层 (`sim/`)

| 文件 | 作用 |
|------|------|
| `sim_top.v` | 顶层 wrapper，连接 CPU 和 AXI RAM |
| `axi_ram.v` | AXI4-Lite slave，通过 DPI-C 访问 C++ 内存 |
| `sim_main.cpp` | 主程序：加载 .bin、时钟生成、复位、结果判断 |

**时钟模型**: 双相时钟（0→1→0→1...），每个边沿 `top->eval()`。

**复位**: 前 10 个半周期 `reset=1`，之后释放。

**超时**: 默认 1000 万周期，可用 `--max-cycles=N` 覆盖。

**波形**: `--wave` 参数启用 VCD 波形，输出 `wave.vcd`。

### DPI-C 内存模型

```c
#define MEM_BASE 0x30000000
#define MEM_SIZE (64 * 1024 * 1024)

static uint8_t mem[MEM_SIZE];

void pmem_read(int addr, int *data) {
    *data = *(int *)(mem + (addr - MEM_BASE));
}

void pmem_write(int addr, int data, int strb) {
    // 字节选通写入
}
```

- 64 MB 模拟内存，起始地址 `0x30000000`
- `axi_ram.v` 通过 `import "DPI-C"` 直接调用 C++ 函数
- 零延迟：读写在同一个 eval() 周期完成

### MMIO 地址映射

| 地址 | 读写 | 作用 |
|------|------|------|
| `0x10000000` | 写 | UART TX：写 1 字节 → 主机 `putchar()` |
| `0x10000004` | 写 | 仿真控制：写任意值 → 仿真结束，值为 exit code |
| `0x30000000` ~ `0x33ffffff` | 读写 | 64 MB 主内存 |
| `0xa0000000` ~ `0xc0000000` | 读写 | DCache 地址范围 |

**UART 链路**: `putchar('H')` → SW 写 `0x10000000` → CPU LSU AXI 写 → DPI-C `pmem_write()` → 主机 `putchar()` → 终端输出。

### 软件框架 (`sw/`)

```
sw/
├── start.S             ← 启动代码 (设置 sp, 跳转 main)
├── link.ld             ← 链接脚本 (基址 0x30000000)
├── include/
│   ├── trap.h          ← check() 断言, halt() 退出
│   ├── am.h            ← printf() via UART
│   ├── klib.h          ← 标准库函数声明
│   └── klib-macros.h   ← LENGTH() 等宏
├── lib/
│   └── klib.c          ← sprintf, strcmp, memcpy, memset,
│                         64-bit 除法/取模 (__divdi3 等)
└── tests/              ← 37 个测试用例
```

**测试断言机制**:
```c
// trap.h
static inline void check(int cond) {
    if (!cond) halt(1);    // 失败 → exit(1)
}

static inline void halt(int code) {
    *(volatile int *)0x10000004 = code;  // 写停机 MMIO
}
```

### 构建系统 (`Makefile`)

```makefile
# 一键构建 + 运行
make all          # = make sim + make sw
make run          # 运行全部 37 个测试
make run ALL=add  # 运行单个测试

# 分步构建
make sim          # Verilator 编译 RTL → build/Vsim_top
make sw           # 交叉编译所有 .c → sw/build/*.bin
make clean        # 清理构建产物
```

Verilator 编译参数：`-O3 --x-assign fast -j 8 --trace`，输出单个可执行文件 `build/Vsim_top`。

---

## 四、环境架构

```
HelloCPU/
├── vsrc/          ← CPU RTL 源码 (详见 二、CPU 设计架构)
├── sim/           ← 仿真环境 (详见 三、验证环境设计)
├── sw/            ← 软件测试框架
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
| **UART 输出** | `0x10000000` |
| **停机地址** | `0x10000004` |
| **仿真引擎** | Verilator 5.008 |
| **交叉编译** | riscv64-linux-gnu-gcc |

---

## 五、测试状态

**运行方式**: `make run`（全部）/ `make run ALL=<name>`（单个）

### ✅ 37/37 全部通过

| # | 测试 | 周期 | 分类 | | # | 测试 | 周期 | 分类 |
|---|------|------|------|-|---|------|------|------|
| 1 | add | 2,426 | 基础 | | 20 | min3 | 2,861 | 分支 |
| 2 | add-longlong | 3,957 | 64位 | | 21 | mov-c | 610 | 传送 |
| 3 | bit | 1,643 | 位操作 | | 22 | movsx | 1,001 | 符号扩展 |
| 4 | bubble-sort | 13,878 | 算法 | | 23 | mul-longlong | 857 | 64位乘法 |
| 5 | crc32 | 28,687 | M扩展 | | 24 | narcissistic | 64,162 | 水仙花数 |
| 6 | div | 5,939 | 除法 | | 25 | pascal | 12,746 | 算法 |
| 7 | dummy | 97 | 最小 | | 26 | prime | 51,997 | 算法 |
| 8 | fact | 1,356 | 递归 | | 27 | quick-sort | 15,458 | 算法 |
| 9 | fib | 2,053 | 递归 | | 28 | recursion | 47,638 | 递归 |
| 10 | goldbach | 9,325 | 算法 | | 29 | select-sort | 10,565 | 算法 |
| 11 | hello-str | 11,819 | 字符串 | | 30 | shift | 1,126 | 移位 |
| 12 | hello | 394 | UART | | 31 | string | 7,309 | 字符串 |
| 13 | if-else | 847 | 分支 | | 32 | sub-longlong | 3,957 | 64位 |
| 14 | leap-year | 7,216 | 分支 | | 33 | sum | 2,644 | 循环 |
| 15 | load-store | 1,476 | LSU | | 34 | switch | 723 | 跳转 |
| 16 | matrix-mul | 32,272 | 矩阵 | | 35 | to-lower-case | 3,616 | 字符 |
| 17 | max | 2,627 | 分支 | | 36 | unalign | 963 | 非对齐 |
| 18 | mem | 2,885 | 内存 | | 37 | wanshu | 19,437 | 算法 |
| 19 | mersenne | 172,921 | 算法 | |

---

## 六、RTL 修复记录

### Bug 1: LSU non-cacheable 访存数据移位 (`vsrc/exu/lsu.v`)

**根因**: LSU 对所有访存统一使用 `raw_word >> lat_shift8` 移位。Non-cacheable 访问通过 DPI-C 直接读写内存，数据已按地址定位到正确字节位置，进一步移位破坏数据。

**修复**: 新增 `load_src` / `eff_wstrb` / `eff_wdata` 信号，根据 `lat_cacheable` 决定是否移位。

### Bug 2: 乘法器 MUL 指令符号 + MULHSU 符号遗漏 (`vsrc/exu/multiplier.v`)

**根因**: MUL 返回 `unsigned_product[31:0]`（绝对值乘积），当操作数符号不同时结果错误；`src1_neg` 未覆盖 MULHSU (op=10)。

**修复**: MUL 改用 `signed_product[31:0]`；`src1_neg` 改为 `(~mul_op[1] | ~mul_op[0]) & src1[31]`。

### Bug 3: 寄存器堆多周期指令转发未门控 (`vsrc/Registers/RegisterFile.v`)

**根因**: 多周期指令（DIV/REM）计算过程中 `exu_wdata` 为中间值，被无条件转发给后续依赖指令。

**修复**: 新增 `exu_post_valid` 门控，仅当 EXU 结果有效时才允许转发。

### Bug 4: `mul_done` 电平信号导致乱序写入 (`vsrc/exu/multiplier.v`)

**根因**: `mul_done = pipe_valid` 是电平信号，连续 MUL 时跨指令边界保持高电平，EXU→WBU 寄存器在错乱时刻捕获数据和 rd_addr。

**修复**: 引入 `mul_busy` 状态机，`mul_done` 改为第 2 周期产生 1 周期脉冲。

### Bug 5: Booth-2 sign extension prevention 补偿偏差 (`vsrc/exu/multiplier.v`)

**根因**: 原 "sign extension prevention" 技巧通过反转 MSB + 静态常量补偿，但补偿偏差随 Booth group 模式（零/正/负 PP）变化而非恒定。

**修复**: 放弃 sign extension prevention 技巧，改为标准全符号扩展 `{{34{pp_val[32]}}, pp_val[31:0]}`。保留 neg_correction 和 Wallace Tree CSA 树。

---

## 七、关键源文件

| 文件 | 说明 | 修改 |
|------|------|------|
| `vsrc/top/hcpu.v` | CPU 顶层 | ✅ exu_post_valid 连接 |
| `vsrc/exu/lsu.v` | 加载存储单元 | ✅ non-cacheable 移位 |
| `vsrc/exu/multiplier.v` | Booth-2 + Wallace Tree 乘法器 | ✅ MUL符号+MULHSU+mul_done脉冲+全符号扩展 |
| `vsrc/Registers/RegisterFile.v` | 寄存器堆 | ✅ exu_post_valid 门控 |
| `vsrc/idu/idu.v` | 译码单元 | ✅ 逻辑重构，命名规范化 |
| `vsrc/Registers/Csrs.v` | CSR 寄存器 | ✅ mcycle 计数器 |
| `vsrc/exu/divider.v` | 除法器 (34 周期) | - |
| `vsrc/exu/alu.v` | ALU | - |
| `vsrc/exu/exu.v` | 执行单元顶层 | - |
| `vsrc/ifu/ifu.v` | 取指单元 | - |
| `vsrc/wbu/wbu.v` | 写回单元 | - |
| `sim/sim_main.cpp` | Verilator 主程序 | - |
| `sim/axi_ram.v` | AXI RAM 模型 | - |

---

## 八、调试方法

```bash
make run ALL=<test_name>    # 运行单个测试
make sim                     # 重新编译
make sw                      # 重新编译软件
make clean                   # 清理
gtkwave wave.vcd             # 查看波形
```

---

## 九、已知问题

1. **axi_ram.v 宽度警告**: `r_addr` 32 位扩展为 34 位（不影响功能）
2. **wstrb 宽度警告**: 4 位 wstrb 传给 32 位期望的 DPI 函数（不影响功能）
3. **ALU 信号命名**: `srl_res` / `sra_res` 命名与实际功能互换，但 IDU opt 映射同步互换，功能正确但命名误导

---

## 十、变更日志

| 日期 | 变更 | 通过率 |
|------|------|--------|
| 2026-05-01 | 初始环境搭建，27 通过 / 10 失败 | 73% |
| 2026-05-01 | LSU 移位修复 (+6) + 乘法器 MUL 符号 (+1) + exu_post_valid | 92% |
| 2026-05-01 | 消除 ysyx-workbench 符号链接依赖；mul_done 脉冲修复 (+2) | 100% |
| 2026-05-02 | Booth-2 全符号扩展替代 sign extension prevention | 100% |
