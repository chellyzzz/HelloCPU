# HelloCPU CPU 演进路线文档

## 一、文档目标

本文档描述 HelloCPU 从当前高性能顺序标量核继续演进的主线，同时考虑未来与向量协处理器的协同扩展。

当前阶段不是简单继续堆局部 patch，而是：

1. 继续提升标量 CPU 性能；
2. 让微架构边界更清晰；
3. 为未来的 RVV/COP 扩展留出自然接口。

## 二、当前快照

当前稳定点：`8f48295`（DIV fast path）

| Metric | Value |
|--------|-------|
| CoreMark/MHz | 2.853 |
| Total cycles | 35,047,662 |
| IPC | 0.874 |
| Stall rate | 10.4% |

当前主要 stall：

| Source | Cycles | % of stalls | Owner |
|--------|--------|-------------|-------|
| Frontend/empty | 2,005,006 | 55.0% | B |
| Other backend | 837,926 | 23.0% | A |
| Control recovery | 795,702 | 21.8% | B |
| LSU wait | 7,107 | 0.2% | Done |
| DIV wait | 2,962 | 0.1% | Done |

这说明 HelloCPU 已经不再是“访存太慢”的 CPU，而是一个前端恢复成本和后端局部时序仍待继续优化的顺序核。

## 三、已经完成的阶段

### 阶段 A：显式后端大瓶颈清除（已完成）

已完成项目：

1. 128-entry BTB
2. WBU `pc_update` 原因归因
3. Same-cycle LSU load hit
4. Same-cycle LSU store hit
5. MUL low fast path
6. DIV trivial fast path（by-1, trivial-zero）

效果：

- CoreMark/MHz: 2.382 → 2.853（+19.8%）
- LSU wait: 6.98M → 7K（-99.9%）
- Stall rate: 25.2% → 10.4%

结论：后端显式 LSU/DIV 大瓶颈已经基本清空。

## 四、当前演进主线

### 主线 1：前端恢复和预测（B 线）

当前最大的浪费来自 redirect 相关成本：

- Frontend/empty 2.0M cycles，其中 96% 是 redirect recovery bubble
- Control recovery 796K cycles
- 合计 redirect 总成本约 2.73M cycles，占全部 stall 的 74.8%

这条线的任务不是继续写分析文档，而是交付带 CoreMark 改善的 RTL：

1. BTB miss rate 降低
2. redirect recovery 缩短

### 主线 2：Other backend 归因与优化（A 线）

`Other backend = 837,926 cycles`，目前尚未归因。

该类 stall 的判定条件是：

`idu2exu_valid && exu2idu_ready && !exu2wbu_valid`

意味着 EXU 已接收指令，但结果尚未到达 WBU。高概率来源：

1. MULH/MULHSU/MULHU 的 2-cycle latency
2. COP backend 2-cycle latency
3. EXU→WBU 边界中的结构气泡

这是 A 线的下一个实际优化目标。

### 主线 3：结构化扩展准备（A/C）

在前端和后端现有瓶颈进一步降低后，再推进：

1. 统一执行后端接口
2. 前后端解耦（fetch/decode queue）
3. 轻量级 scoreboard
4. Vector memory access / RVV migration 所需的 CPU 接口改造

## 五、未来与向量协处理器的关系

当前 CPU 的优化已经证明：

- 标量后端性能可以通过局部语义理顺获得大收益；
- 未来接入更强 COP/RVV 时，真正关键的不是 AXI 带宽本身，而是 issue / complete / commit / flush 的边界清晰度。

因此 CPU 演进路线与向量扩展的兼容原则是：

1. 标量 LSU / COP / future vector memory path 使用统一的完成语义
2. flush / redirect / exception 尽量统一控制框架
3. 不把 future vector support 继续塞进 EXU 条件分支里

## 六、近期排序

### 第一梯队

1. B：BTB miss rate 改善
2. A：Other backend 归因和优化

### 第二梯队

3. B：真正有效的 redirect recovery -1 cycle
4. A：统一 EXU 后端接口（为 vector memory/COP 扩展铺路）

### 第三梯队

5. A/C：vector memory access 接口准备
6. A/B：前后端轻量解耦

## 七、结论

HelloCPU 当前已经从“LSU 阻塞型顺序核”演进到“前端 redirect 成本主导的高性能顺序核”。

后续最值得投入的方向已经非常明确：

1. 前端预测与恢复（B）
2. Other backend 归因和后端局部优化（A）
3. 统一结构边界，为向量访存和 RVV 迁移铺路（A/C）
