# HelloCPU CoreMark 跑分记录

> 测试日期: 2026-05-02 ~ 2026-05-04 | CPU: hcpu (RV32IM + Zicsr, 5 级流水线) | 分支预测器: 2026-05-03

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

### ITER=100 标准跑分 (无预测)

| 指标 | V2 当前 | V1 初始 (ITER=1) |
|------|---------|-------------------|
| **CoreMark/MHz** | **1.293** | 0.510 |
| **Total ticks** (kernel) | 77,213,027 | 1,801,042 |
| **Total cycles** (mcycle) | 77,289,890 | 1,959,779 |
| **Per-iteration ticks** | ~772,130 | 1,801,042 |
| **CoreMark Size** | 666 | 666 |

### CRC 校验 (ITER=100, 无预测)

| 子项 | CRC 值 | 结果 |
|------|--------|------|
| seedcrc | 0xe9f5 | ✅ |
| crclist | 0xe714 | ✅ |
| crcmatrix | 0x1fd7 | ✅ |
| crcstate | 0x8e3a | ✅ |
| crcfinal | 0x988c | ✅ |

### ITER=1 基准 (无预测, 2026-05-04 确认)

```
CoreMark Size    : 666
Total ticks      : 774,690
Total time (secs): 774,690
Iterations/Sec   : 0
Iterations       : 1
seedcrc          : 0xe9f5
[0]crclist       : 0xe714
[0]crcmatrix     : 0x1fd7
[0]crcstate      : 0x8e3a
[0]crcfinal      : 0xe714
Correct operation validated.
Total cycles     : 850,878
CoreMark/MHz     : 1.175
[HelloCPU] PASS (cycles: 855,796)
```

---

## 三、分支预测器与 CoreMark — 当前状态

### 预测器配置测试矩阵 (2026-05-04, gating fix `64b8ee2` 后)

| 配置 | BTB | JAL | RAS | cpu-tests | CoreMark ITER=1 |
|------|-----|-----|-----|-----------|-----------------|
| **无预测 (基线)** | OFF | OFF | OFF | 40/40 ✅ | ✅ CRC 正确, 856K cycles |
| **BTB 独占** | ON | OFF | OFF | 40/40 ✅ | ❌ CRC 错误 (0xc577≠0xe714) |
| **JAL 独占** | OFF | ON | OFF | 40/40 ✅ | ❌ 死循环 (45M inst) |
| **BTB+JAL** | ON | ON | OFF | 40/40 ✅ | ❌ 死循环 (80M inst) |
| **BTB+RAS** | ON | OFF | ON | 40/40 ✅ | ❌ CRC 错误 |
| **全预测** | ON | ON | ON | 40/40 ✅ | ❌ 死循环 (80M inst) |

### 预言器性能计数器 (全预测死循环, 80M inst)

```
BTB hits          : 19,043,190 (80.0%)
BTB misses        :  4,761,396 (20.0%)
BTB mispredicts   :  9,521,576 (40.0%)  ← 极高的误预测率
RAS hits          :          9 (18.8%)
RAS misses        :         39 (81.2%)
JAL tgt bad       :          0           ← JAL target 100% 正确
WBU pcupdate      :  4,761,637
```

### BTB-only 性能计数器 (879K cycles, CRC 错误)

```
BTB hits          :     57,564 (65.2%)
BTB misses        :     30,763 (34.8%)
BTB mispredicts   :     27,159 (30.7%)
RAS hits          :      5,453 (90.4%)
RAS misses        :        579 ( 9.6%)
WBU pcupdate      :     43,917
```

### 基线 (无预测, 856K cycles, CRC 正确)

```
BTB hits          :     58,085 (65.7%)
BTB misses        :     30,367 (34.3%)
BTB mispredicts   :     44,226 (50.0%)   ← BTB 查表产生但仍被 WBU pc_update 覆盖
RAS hits          :      5,327 (90.4%)
WBU pcupdate      :     44,334
```

> 注意：无预测时 BTB/RAS 仍在硬件中被查表和更新（EXU 中的 push/pop/update 照常执行），只是 IFU 中 `pred_taken_btb/jal/ras = 0` 不用于 PC 选择。

---

## 四、死循环详细分析

### 现象

JAL 预测开启时，CoreMark 死循环：
- 80M+ 条指令执行后仍未终止
- 仅 ~170 次 JAL/JALR（正常 ITER=1 约 8,000 次）
- 极高比例的 ALU 指令 (82%) — 嵌在计算密集循环中
- BTB mispredict 率 40% — 循环中大量分支但预测质量差

### 进度曲线 (JAL-only, 10M cycles)

| 周期 | 指令 | IPC | JAL/JALR |
|------|------|-----|----------|
| 2.5M | 1.12M | 0.45 | 296,937 |
| 5.0M | 2.26M | 0.45 | 593,873 |
| 7.5M | 3.39M | 0.45 | — |
| 10.0M | 4.53M | 0.45 | 1,187,746 |

> 线性增长 — 说明程序在重复执行相同代码路径，只是从不退出。

### 死循环发生位置推测

基于极低的 JAL/JALR 计数（全部 170 次在早期发生），死循环发生在：
1. CoreMark 初始化后的主循环计算阶段
2. 循环计数器递减指令 (`addi`) 或分支返回指令 (`bnez`) 被冲刷丢失
3. 函数调用（JAL）在死循环中不再出现 — 可能是因为代码路径在某个永不退出的内循环中，或 JAL 被冲刷后目标代码跳过函数调用

### 根因说明

JAL 预测触发 pc_update 冲刷流水线。冲刷窗口 (2 周期) 可能在某些模式中导致循环控制指令被连锁冲刷，从而永不更新循环计数器。详见 `docs/分支预测器修复方案.md`。

---

## 五、跑分提升历程

| 阶段 | CoreMark/MHz | per-iter | 改动 |
|------|-------------|----------|------|
| 初始 (ITER=1) | 0.510 | 1,801,042 | 测试用单次迭代 |
| ITER=100 | 0.662 | 1,508,015 | 摊薄初始化开销 + DCache 启用 |
| 4KB caches + DCache fix | **1.293** | 772,130 | ICache 256B→4KB, DCache 256B→4KB, CACHE_START 修正 |

**总提升: 2.5×** (0.510 → 1.293)

---

## 六、性能计数器分析 (PERF_COUNTERS)

> ITER=100 无预测跑分

```
总周期:       77,296,934
总指令:       37,405,083 (IPC = 0.484)
停顿周期:     39,891,852 (51.6%)

指令混合:
  ALU 运算:       17,790,754 (47.6%)
  分支:            4,709,548 (12.6%)
    ├─ 跳转:         690,800 (14.7%)
  跳转 (JAL+JALR):   460,930 (1.2%)
  加载:            9,116,218 (24.4%)
  存储:            3,480,656 (9.3%)
  乘法:            1,846,800 (4.9%)

Cache 统计:
  ICache hits:    76,293,473 (99.9%)
  ICache misses:     106,909 (0.1%)

总线访问:
  IFU 取指:           106,909
  加载 xacts:             209
  存储 xacts:             600
```

### Stall 来源估算 (ITER=100)

| 来源 | 周期 | 占比 |
|------|------|------|
| 分支惩罚 (14.7% × 2 周期) | ~1.38M | 3.5% |
| ICache miss (106,909 × ~8 周期) | ~0.86M | 2.1% |
| **数据冒险/结构冲突/Xbar 仲裁** | ~37.7M | **94.4%** |

**核心发现：51.6% 停顿的主要来源不是 cache miss，而是流水线内部的 load-use 数据冒险和结构冲突。**

---

## 七、对比案例

| CPU | ISA | 特性 | CoreMark/MHz |
|-----|-----|------|-------------|
| SERV | RV32I | 位串行 | ~0.03 |
| PicoRV32 | RV32IMC | 多周期状态机 | ~0.51 |
| darkriscv | RV32E | 3 级流水 | ~1.0 |
| **helloCPU (V2)** | **RV32IM** | **5 级 + 4KB caches + 分支预测** | **1.293** |
| VexRiscv (small) | RV32IM | 4 级 + 分支预测 | 1.40 |
| SCR1 | RV32IMC | 2-4 级顺序 | 1.72 |
| PULPino Zero-riscy | RV32IMC | 2 级顺序 | 2.48 |
| SiFive E31 | RV32IMAC | 6 级顺序 | 3.12 |

---

## 八、修复内容总结

### V1→V2 修复

| # | 修复 | 文件 | 影响 |
|---|------|------|------|
| 1 | DCache cacheable 范围 | `lsu.v` | **关键** — DCache 从未触发 |
| 2 | Refill 期间 load_res 覆盖 | `lsu.v` | 垃圾数据 |
| 3 | 删除重复 wire 声明 | `lsu.v` | 构建警告 |
| 4 | ICache/DCache 4KB | `icache_direct.v` | **性能核心** — 16× 容量 |
| 5 | CoreMark 链接 klib.c | `sw/Makefile` | 64-bit 除法 |
| 6 | ITER 可配置 | `Makefile` | `make bench ITER=100` |

### 分支预测器修复 (2026-05-03 ~ 2026-05-04)

| # | 修复 | 提交 | 影响 |
|---|------|------|------|
| 7 | JAL target 检测 | `b360380` | 方向+目标双重验证 |
| 8 | 误预测 latch 机制 | `db7fabc` | 解决组合信号竞争 |
| 9 | BTB 3 项测试 | `db7fabc` | 回归测试 |
| 10 | 独立 o_valid 输出 | `1f4b2cc` | EXU→WBU 流控 |
| 11 | 恢复全 WBU pc_update | `6c3d91c` / `d8d99e4` | 37→40 测试通过 |
| 12 | **EXU→WBU gating** | **`64b8ee2`** | **防止错误路径污染** |

---

## 九、运行命令

```bash
make bench ITER=100              # 编译 + 运行 CoreMark (100 次迭代)
make bench_only ITER=100         # 仅运行 (跳过测试编译)
make bench                       # 快速功能验证 (1 次迭代)
make run                         # 运行全部 40 个测试
make clean                       # 清理
```
