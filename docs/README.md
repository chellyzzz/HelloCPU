# HelloCPU 文档索引

当前状态：

- `master` 已合入 CPU lane-1 stage-3 稳定点和 partial RVV benchmark 子集稳定点。
- CPU 主线当前入口：`cpu/cpu-evolution-roadmap.md`。
- RVV 主线当前入口：`vector/rvv-subset-freeze.md`、`vector/rvv-mainline-merge-summary.md`。

文档按职责归档为三类：

1. `cpu/`：标量 CPU 微架构、性能、分支预测和 CPU 演进计划。
2. `vector/`：向量协处理器后端自身的结构、阶段和当前功能状态。
3. `interface/`：CPU 与向量协处理器之间的接口、交接和联合规划。

CPU 侧与当前性能演进直接相关的重点文档包括：

- `cpu/coremark-results.md`
- `cpu/microarchitecture.md`
- `cpu/cpu-evolution-roadmap.md`
- `cpu/post-merge-stabilization-freeze.md`
- `cpu/lsu-optimization-analysis.md`
- `cpu/two-wide-preparation-checklist.md`

向量/COP 侧与 RVV 长期演进直接相关的重点文档包括：

- `vector/vector-coprocessor-stages.md`
- `vector/vector-coprocessor-microarchitecture.md`
- `vector/vector-memory-access.md`
- `vector/cop-encoding.md`
- `vector/rvv-long-term-roadmap.md`
- `vector/rvv-supported-subset.md`
- `vector/rvv-subset-freeze.md`
- `vector/rvv-mainline-merge-summary.md`
- `vector/rvv-state-p1.md`
- `vector/rvv-standard-decode-p2-review.md`

当前代码也按同样边界整理：`vsrc/cpu/` 保存 CPU 主流水和公共片上结构，`vsrc/vector/` 保存向量/COP 后端相关 RTL。
