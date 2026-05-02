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

## 四、对比案例

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

## 五、根因分析 (V1→V2 修复内容)

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

## 六、测试状态

37/37 全部通过 (100%)

---

## 七、运行命令

```bash
make bench ITER=100              # 编译 + 运行 CoreMark (100 次迭代)
make bench_only ITER=100         # 仅运行 (跳过测试编译)
make bench                       # 快速功能验证 (1 次迭代)
make run                         # 运行全部 37 个测试
make clean                       # 清理
```
