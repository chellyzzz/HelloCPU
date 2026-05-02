# HelloCPU CoreMark 跑分记录

> 测试日期: 2026-05-02 | CPU: hcpu (RV32IM + Zicsr, 5 级流水线)

---

## 一、测试配置

| 项目 | 当前配置 (V2) | V1 配置 |
|------|-------------|---------|
| **ICache** | 4KB (64 路组 × 4 路 × 16B) | 256B (4 × 4 × 16B) |
| **DCache** | 4KB (64 路组 × 4 路 × 16B) | 256B + 地址范围错误 |
| **Cacheable 范围** | 0x30000000–0x40000000 | 0xA0000000–0xC0000000 (无效) |
| **编译器** | riscv64-linux-gnu-gcc 11.4.0 | 同 |
| **编译选项** | -march=rv32im_zicsr -O2 | 同 |
| **内存基址** | 0x30000000 | 同 |
| **仿真引擎** | Verilator 5.008 | 同 |

---

## 二、跑分结果

### ITER=100 标准跑分

| 指标 | V2 当前 | V1 初始 (ITER=1) |
|------|---------|-------------------|
| **CoreMark/MHz** | **1.293** | 0.510 |
| **Total ticks** (kernel) | 77,213,027 | 1,801,042 |
| **Total cycles** (mcycle) | 77,289,890 | 1,959,779 |
| **Per-iteration ticks** | ~772,130 | 1,801,042 |
| **CoreMark Size** | 666 | 666 |

### CRC 校验 (ITER=100)

| 子项 | CRC 值 | 结果 |
|------|--------|------|
| seedcrc | 0xe9f5 | ✅ |
| crclist | 0xe714 | ✅ |
| crcmatrix | 0x1fd7 | ✅ |
| crcstate | 0x8e3a | ✅ |
| crcfinal | 0x988c | ✅ |

### 完整输出

```
2K performance run parameters for coremark.
CoreMark Size    : 666
Total ticks      : 77213027
Total time (secs): 77213027
Iterations/Sec   : 0
Iterations       : 100
Compiler version : riscv64-linux-gnu-gcc 11.4.0
Compiler flags   : rv32im_zicsr -O2
Memory location  : STACK
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0x988c
Correct operation validated. See README.md for run and reporting rules.
Total cycles     : 77289890
CoreMark/MHz     : 1.293

[HelloCPU] PASS (cycles: 77296934)
```

---

## 三、跑分提升历程

| 阶段 | CoreMark/MHz | per-iter | 改动 |
|------|-------------|----------|------|
| 初始 (ITER=1) | 0.510 | 1,801,042 | 测试用单次迭代 |
| ITER=100 | 0.662 | 1,508,015 | 摊薄初始化开销 + DCache 启用 |
| 4KB caches + DCache fix | **1.293** | 772,130 | ICache 256B→4KB, DCache 256B→4KB, CACHE_START 修正 |

**总提升: 2.5×** (0.510 → 1.293)

---

## 四、性能计数器分析 (PERF_COUNTERS)

> 开启 `PERF_COUNTERS + PERF_INST_MIX + PERF_STALL + PERF_BUS + PERF_CACHE` 后的 ITER=100 跑分

```
┌─────────────────────────────────────────────────────┐
│            Performance Counter Summary              │
├─────────────────────────────────────────────────────┤
│ Total cycles         :     77296934                 │
│ Total instructions   :     37405083 (IPC = 0.484)       │
│ Stall cycles         :     39891852 (51.6%)            │
├─────────────────────────────────────────────────────┤
│ Instruction Mix                                    │
│   ALU ops           :   17790754 ( 47.6%)            │
│   Branches          :    4709548 ( 12.6%)            │
│     ├─ taken        :     690800 ( 14.7%)            │
│   Jumps (JAL+JALR)  :     460930 (  1.2%)            │
│   Loads             :    9116218 ( 24.4%)            │
│   Stores            :    3480656 (  9.3%)            │
│   Multiplies        :    1846800 (  4.9%)            │
│   Divides           :        174 (  0.0%)            │
│   CSR accesses      :          3 (  0.0%)            │
│   System (ECALL/MRET/EBREAK):    0 (  0.0%)     │
│   fence.i           :          0 (  0.0%)            │
├─────────────────────────────────────────────────────┤
│ Cache Statistics                                   │
│   ICache hits       :   76293473 ( 99.9%)            │
│   ICache misses     :     106909 (  0.1%)            │
│   ICache hit rate   :       99.9%                     │
├─────────────────────────────────────────────────────┤
│ Bus Transactions                                   │
│   IFU fetches       :     106909 / done: 106909                 │
│   Load  xacts       :        209 / done: 209                 │
│   Store xacts       :        600 / done: 599                 │
└─────────────────────────────────────────────────────┘
```

### 4.1 全局指标

| 指标 | 数值 | 说明 |
|------|------|------|
| **IPC** | 0.484 | 单发射理论峰值 1.0，实际利用 48.4% |
| **Stall 率** | 51.6% | 过半周期流水线停顿 |
| **ICache Hit Rate** | 99.9% | 4KB ICache 覆盖了几乎所有取指 |
| **DCache 读 miss** | 209 次 | 37.4M 条指令中仅 209 次 DCache 读 miss |
| **DCache 写回** | 150 次 | 600 AW = 4字×150 次完整写回 |

### 4.2 Stall 来源估算

| 来源 | 周期 | 占比 |
|------|------|------|
| **分支惩罚** (14.7% 分支跳转, ~2 周期/stall) | ~1.38M | 3.5% |
| **ICache miss** (106,909 × ~8 周期) | ~0.86M | 2.1% |
| **DCache miss refill** (209 × ~8 周期) | ~0.002M | 0.0% |
| **DCache writeback** (150 × ~12 周期) | ~0.002M | 0.0% |
| **除法器气泡** (174 × 33 周期) | ~0.006M | 0.0% |
| **数据冒险/转发失败/结构冲突/Xbar 仲裁** | ~37.7M | **94.4%** |

**核心发现：51.6% stall 的主要来源不是 cache miss，而是流水线内部的数据冒险和结构冲突。**

对于 5 级顺序流水线，IPC=0.484 是合理的。对比：ARM Cortex-M0+ (2 级) IPC≈0.7，Cortex-M3 (3 级) IPC≈0.9。

### 4.3 指令混合分析

CoreMark 是典型的嵌入式 workload：
- **24.4% Load + 9.3% Store = 33.7% 访存**。大量 load 暴露了数据冒险（load-use hazard）
- **12.6% 分支 + 1.2% 跳转 = 13.8% 控制流**。14.7% 的分支跳转率低，大量分支是循环回边（highly predictable）
- **4.9% 乘法**。CoreMark 矩阵乘法使用了大量 MUL 指令
- **0.0% 除法**。174 次除法全部在 printf 初始化阶段，热路径无除法

---

## 五、IPC 深度分析：为什么 0.484 < Cortex-M0+ 的 0.7？

> 一个常见误解：5 级流水线的 IPC 应该比 2 级流水线高。**事实相反：流水线越深，IPC 通常越低。** 深度流水线的收益是更高的主频，不是更高的 IPC。

### 5.1 CPI 逐类拆解

用性能计数器数据按指令类型计算理想 CPI：

| 指令类型 | 占比 | 周期/条 | CPI 贡献 | 说明 |
|----------|------|---------|----------|------|
| ALU | 47.6% | 1 | 0.476 | 纯 ALU 单周期 |
| Load (命中) | 24.4% | 3+ | 0.73+ | S_IDLE→S_CHECK→S_CACHE_HIT→done = 3 周期 |
| Store (命中) | 9.3% | 3+ | 0.28+ | 同上 |
| Branch (未跳转) | 10.7% | 1 | 0.107 | 顺序执行 |
| Branch (跳转) | 1.9% | 3 | 0.057 | flush 2 条指令 = +2 周期 |
| JAL/JALR | 1.2% | 3 | 0.036 | flush + 跳转 |
| MUL | 4.9% | 2-3 | 0.098 | 2 周期 + 可能 bubble |
| **理论 CPI 合计** | | | **~1.78** | → 理论 IPC ≈ 0.56 |
| | | | | |
| **额外损失** | | | **~0.28** | 数据冒险 / 结构冲突 / 非命中 LSU 延迟 |
| | | | | |
| **实测 CPI** | | | **2.07** | → 实测 IPC = **0.484** |

**理论 IPC 0.56 vs 实测 IPC 0.484** — 差异来自未被计数器直接捕获的微架构损失。

### 5.2 与 ARM Cortex-M 的核心差异

| 因素 | Cortex-M0+ (IPC≈0.7) | Cortex-M3 (IPC≈0.9) | hcpu (IPC=0.48) |
|------|----------------------|---------------------|-----------------|
| **流水线深** | 2 级 | 3 级 | 5 级 |
| **指令集** | Thumb-1 (16-bit) | Thumb-2 (16+32) | RV32IM (32-bit) |
| **代码密度** | 极致紧凑 | 紧凑 | 松散 (30%+ 更大) |
| **分支预测** | 无 | BTB + 全局历史 | **无** |
| **哈佛架构** | 是 (I/D 总线分离) | 是 | 否 (共享 Xbar) |
| **Load-use 处理** | 0 stall (2 级天然无冲突) | 0-1 stall | 1+ stall |
| **乘法器** | 单周期 (MULS) | 单周期 | **2 周期** (Booth-2) |
| **转发路径** | 天然转发 (2 级) | 多级转发 | 三级转发 |

### 5.3 根因一：Load/Store 是 IPC 杀手

**hcpu 每一条 load 和 store 都会阻塞流水线**，因为 `o_pre_ready = lsu_done`（只有 LSU 完成才接受下条指令）。

- 24.4% + 9.3% = **33.7% 的指令是访存**
- 每次访存产生 ~3 周期阻塞
- 仅此一项就贡献 CPI 的 ~43%

Cortex-M0+ 虽然也是单发射，但 2 级流水线的 load 不需要额外阻塞（fetch→execute→writeback 在同一个较长周期内完成，或通过哈佛架构的独立总线避免冲突）。

### 5.4 根因二：无分支预测 × 5 级流水

- 每条跳转分支 flush 掉 IFU/IDU 中的 2 条指令 = **2 周期惩罚**
- 690,800 次跳转 × 2 周期 = 1.38M 周期损失
- Cortex-M3 有 BTB，跳转惩罚仅 ~1 周期（甚至 0）

### 5.5 根因三：指令集密度 (Thumb vs RV32)

CoreMark 编译后：
- **ARM Thumb**: ~10KB .text
- **RV32IM (本 CPU)**: **15KB** .text (大 50%)

更大的代码 = 更多的 ICache miss = 更多的取指停顿。即使 ICache hit rate 99.9%，0.1% miss 也产生 106K 次 AXI 突发。

### 5.6 根因四：共享总线仲裁

IFU 和 LSU 共享一条 AXI 总线通过 Xbar。当 DCache 在做 writeback 时，IFU 的取指请求必须等待。反之亦然。

### 5.7 总结

| | |
|---|---|
| IPC=0.48 是否正常？ | **正常**。同等条件（单发射顺序、无分支预测、RV32IM）的 VexRiscv small 约 IPC≈0.5-0.6 |
| 深度流水线的作用？ | 提高主频上限（1.5-2×），而非 IPC。5 级 vs 2 级在主频上可翻倍，综合性能 = IPC × 频率 |
| 最有效的提升路径？ | ① **分支预测** (→IPC 0.55+) ② **哈佛总线** (→IPC 0.58+) ③ **RVC 压缩指令** (→减少 ICache 压力) |

在 `Makefile` 中添加：
```makefile
VERILATOR_FLAGS += "+define+PERF_COUNTERS"
VERILATOR_FLAGS += "+define+PERF_INST_MIX"
VERILATOR_FLAGS += "+define+PERF_STALL"
VERILATOR_FLAGS += "+define+PERF_BUS"
VERILATOR_FLAGS += "+define+PERF_CACHE"
```

计数器通过 DPI-C 从 RTL → C++ static 变量，仿真结束后 `print_perf_summary()` 汇总输出。

---

## 六、对比案例

### RISC-V 开源/商业 CPU

| CPU | ISA | 特性 | CoreMark/MHz |
|-----|-----|------|-------------|
| SERV | RV32I | 位串行 | ~0.03 |
| PicoRV32 | RV32IMC | 多周期状态机 | ~0.51 |
| darkriscv | RV32E | 3 级流水 | ~1.0 |
| **helloCPU (V2)** | **RV32IM** | **5 级 + 4KB caches** | **1.293** |
| VexRiscv (small) | RV32IM | 4 级 + 分支预测 | 1.40 |
| SCR1 | RV32IMC | 2-4 级顺序 | 1.72 |
| PULPino Zero-riscy | RV32IMC | 2 级顺序 | 2.48 |
| SiFive E31 | RV32IMAC | 6 级顺序 | 3.12 |

helloCPU V2 已进入同档位竞争区间。与 VexRiscv small 差距仅 ~8%，主要短板在：
- **无分支预测**：CoreMark 每 5 条指令就有一条分支，无预测导致 2 周期惩罚
- **无 C 扩展**：代码量比 RV32IMC 大 30-40%，ICache 压力更大
- **34 周期除法器**：SRT-4 可降至 17 周期
- **单发射**：VexRiscv small 同样是单发射但配了分支预测器

---

## 七、根因分析 (V1→V2 修复内容)

### 修复 1: DCache cacheable 范围 (关键)

`vsrc/exu/lsu.v`: `CACHE_START` 原为 `0xA0000000`，与实际内存基址 `0x30000000` 不匹配，导致 DCache 从未被触发。

### 修复 2: Refill 期间 load_res 覆盖

`lsu.v:678`: 原条件 `state == S_REFILL_R` 在 refill 的每一拍都会更新 load_res，导致最终拿到非目标 word 的垃圾数据。改为 `refill_hit_word` 仅在目标 word 到达时更新。

### 修复 3: 删除重复 wire 声明

`lsu.v:208-209,674`: 原文有 copy-paste 产生的重复 `eff_wstrb/eff_wdata/load_src` 声明。

### 修复 4: ICache/DCache 容量提升 (性能关键)

| 缓存 | V1 | V2 | 提升 |
|------|----|----|------|
| ICache | 256B (16 条缓存行) | 4KB (256 条) | 16× |
| DCache | 256B | 4KB | 16× |

CoreMark .text 15KB (~940 条缓存行)，V1 的 256B ICache 仅能容纳 1.7%，几乎每条指令都在等 ICache miss。4KB (256 条缓存行) 可容纳热点函数工作集，miss 率大幅下降。

### 修复 5: CoreMark 链接 klib.c

`sw/Makefile:29-30`: 多迭代 (ITER>1) 时 score 计算需要 64-bit 除法 `__udivdi3`，原 CoreMark 构建未链接 `lib/klib.c`。

### 修复 6: ITER 可配置

`Makefile:70` / `sw/Makefile:21`: 新增 `ITER ?= 1` 变量，支持 `make bench ITER=100` 等标准跑法。

---

## 八、测试状态

37/37 全部通过 (100%)

---

## 九、运行命令

```bash
make bench ITER=100              # 编译 + 运行 CoreMark (100 次迭代)
make bench_only ITER=100         # 仅运行 (跳过测试编译)
make bench                       # 快速功能验证 (1 次迭代)
make run                         # 运行全部 37 个测试
make clean                       # 清理
```
