# HelloCPU Vector/RVV 长期路线图

## 一、目标边界

本文档描述 HelloCPU 向量/COP 方向的长期推进计划。目标不是一次性实现完整 RVV，而是在现有自定义 COP 原型上，分阶段收敛到一个可验证、可维护、能运行部分标准 RVV 程序的向量后端。

长期目标分三层：

1. 保持当前 COP 原型稳定，继续作为接口、kill、访存和 VRF 验证平台。
2. 逐步引入 RVV 架构状态、标准编码和最小执行语义。
3. 支持一个 benchmark-driven RVV 子集，包括 `vsetvli`、unit-stride load/store、基础整数向量算术、最小乘法、简单 mask/select 和单一 reduction。

非目标：

- 不在第一阶段追求完整 RVV 1.0 覆盖。
- 不以完整 RVV compliance 为最终目标；最终目标是支撑 `sw/benchmark/rvv-subset-benchmark/` 的小型整数 benchmark。
- 不在语义稳定前追求多 lane 高吞吐。
- 不绕过 CPU 侧统一 kill/flush/commit 语义做独立提交。
- 不为了短期跑分引入难以回收的 ad-hoc top-level special case。

## 二、当前基线

当前实现处于自定义 COP 原型阶段：

- 指令编码使用 `custom-0`，不是标准 RVV 编码。
- 执行模型是单发射，V1 约束下最多一个 COP 请求在飞。
- COP 结果通过 CPU/WBU 统一提交，killed COP work 不得产生架构写回。
- 已有 VRF 原型、lane 运算、vlen/scratch/opcount 状态和最小 COP memory 访问。
- COP memory 已接入 CPU memory owner 边界，后续 vector memory 应沿用统一 owner/service model。
- pending-kill 语义通过 directed RTL/sim coverage 验证，不依赖软件伪造未完成状态。

这套基线的价值是验证 CPU/COP 边界，而不是作为最终 ISA 形态。后续 RVV 工作必须尽量复用这些已验证边界。

## 三、推进原则

### 3.1 正确性优先

每个阶段先证明以下语义稳定，再扩大功能：

- issue 后 busy/backpressure 行为明确。
- complete 与 commit 边界明确。
- branch/flush/kill 后不产生错误写回。
- 访存响应晚到时不会污染 VRF 或 GPR。
- 异常和非法配置不会绕过 CPU 统一处理路径。

### 3.2 小步合并

每一阶段都应拆成独立、可 review、可回退的小 patch：

- 文档和测试先行。
- RTL 变化保持局部。
- CPU/COP 接口变化必须先走 interface review。
- 不把编码迁移、VRF 扩容、访存和性能优化塞进同一个 patch。

### 3.3 子集明确

所有 RVV 支持都必须写明支持范围。没有实现的能力应显式作为 illegal、reserved 或 unsupported，而不是静默执行成近似语义。

## 四、阶段规划

### 阶段 0：稳住自定义 COP 基线

目标：把现有 COP 原型作为可靠实验平台，而不是继续堆临时行为。

主要工作：

- 固化当前 `custom-0` 编码表和测试矩阵。
- 保持单发射、单请求在飞、CPU/WBU 统一提交语义。
- 补齐 COP memory smoke、pending-kill、重复请求和 stale response coverage。
- 清理过时文档，明确哪些行为只是原型语义。

验收标准：

- scalar smoke、COP lane/VRF/state、COP memory 和 directed pending-kill 测试稳定通过。
- kill 后无 GPR/VRF/内存架构状态污染。
- 文档能准确描述当前实现与 RVV 的差距。

### 阶段 1：RVV 状态模型草案

目标：先定义最小 RVV 架构状态，不急于改完整解码。

主要工作：

- 定义 `vl`、`vtype`、`vstart` 的最小实现范围。
- 明确 `VLEN`、`ELEN`、`LMUL`、`SEW` 的阶段性限制。
- 建议第一版采用固定小 `VLEN`，例如 32-bit 或 64-bit，用于验证语义。
- 明确 reset、flush、trap、非法 `vtype` 的状态变化。
- 将现有 `vlen` 原型状态映射到未来 `vl`，避免继续扩展自定义状态语义。

阶段性 RVV 子集建议：

- `VLEN`：先固定小宽度。
- `ELEN`：先支持 8-bit 和 32-bit 中的一种或两种。
- `LMUL`：先只支持 `m1`。
- `vstart`：先固定为 0，不支持异常后中途重启。
- tail/mask policy：先固定策略，并在文档里声明限制。

验收标准：

- 软件能通过受限接口设置和读取最小向量配置。
- 非法配置有明确处理方式。
- 现有 COP 原型测试不回退。

### 阶段 2：标准 RVV 编码前端

目标：引入标准 RVV 指令识别，但后端仍可复用现有 COP 执行路径。

主要工作：

- 在 CPU decode/dispatch 边界识别 OP-V 和相关 vector load/store 编码。
- 支持 `vsetvli` 或 `vsetivli` 的最小解码与配置写入。
- 将一小批 RVV 指令转换成 COP-local micro-op。
- 对未支持 RVV 指令产生明确 illegal/unsupported 行为。
- 保持 `custom-0` 原型编码用于回归测试，直到 RVV path 足够稳定。

第一批候选指令：

- `vsetvli` 或 `vsetivli`。
- `vadd.vv`。
- `vadd.vx` 或 `vadd.vi`。
- `vand.vv`、`vor.vv`、`vxor.vv` 中的一小部分。

验收标准：

- 能从标准 RVV 编码进入 COP backend。
- unsupported 指令不会误执行。
- RVV 编码 path 与 custom COP path 可以分别测试。

### 阶段 3：最小 RVV VRF 和整数 ALU 子集

目标：让标准 RVV 程序能完成纯寄存器整数向量计算。

主要工作：

- 将 VRF 语义从原型寄存器扩展为 RVV 风格 `v0` 到 `v31`。
- 建立 element-level 执行循环，先不追求多 lane 并行。
- 支持 `SEW=8` 或 `SEW=32` 的基础整数运算。
- 明确 tail element 和 inactive element 的处理策略。
- 先支持 `vm=1` 全使能；mask 支持可放到下一阶段。

最小功能目标：

- `vadd.vv`。
- `vadd.vx`。
- `vand.vv`、`vor.vv`、`vxor.vv`。
- `vmv.v.v` 或等价 move 类操作。

验收标准：

- 能运行一个不访存或只依赖预置 VRF 的 RVV integer ALU directed test。
- 每条指令的 `vl` 生效范围可通过测试观察。
- flush/kill 不留下半提交 VRF 状态。

### 阶段 4：unit-stride RVV load/store 子集

目标：支持最小可用的 RVV 内存程序。

主要工作：

- 基于 CPU memory owner/service model 接入 vector load/store。
- 先支持 unit-stride，不支持 strided/gather/scatter。
- 先支持自然对齐或明确受限的 misalign 行为。
- load 写 VRF 必须延迟到可提交点；killed load 响应必须被吸收。
- store 的架构可见性必须与 CPU commit/kill 语义对齐，不能在 killed work 中提前产生不可回滚写入。

第一批候选指令：

- `vle8.v` 或 `vle32.v`。
- `vse8.v` 或 `vse32.v`。

验收标准：

- 能运行标准 RVV 风格的 load、ALU、store 小程序。
- pending-kill load response 不污染 VRF。
- store 行为在 kill/flush 场景下有明确测试覆盖。

### 阶段 5：基础 mask 和 policy 支持

目标：从全使能执行扩展到 RVV 的基础 mask 语义。

主要工作：

- 实现 `v0` 作为 mask register 的最小读路径。
- 支持 `vm=0` 的 inactive element 跳过。
- 明确 mask/tail agnostic 或 undisturbed 的阶段性选择。
- 增加 mask 下的 ALU 和 load/store directed tests。

验收标准：

- masked ALU 不更新 inactive elements。
- masked load/store 不访问 inactive element 对应地址。
- tail policy 行为在文档和测试中一致。

### 阶段 6：形成可声明的 RVV 子集

目标：把实现从“能跑几个测试”收敛成“可声明支持的 RVV 子集”。

建议子集：

- `vsetvli` 或 `vsetivli`。
- `SEW=8` 和/或 `SEW=32`。
- `LMUL=m1`。
- `vadd`、bitwise logical、move 类整数指令。
- unit-stride `vle*.v` / `vse*.v`。
- `vm=1` 全使能，或基础 `vm=0` mask。

交付物：

- `docs/vector/rvv-supported-subset.md`，列出每条支持/不支持指令。
- RVV directed software tests。
- RVV encoding decode tests。
- kill/flush/memory stale response tests。
- 与 custom COP 原型的迁移/保留策略。

当前支持矩阵维护在 `rvv-supported-subset.md`。后续任何 RVV RTL 扩展都应先更新该矩阵，再实现对应 decode/datapath/test。

从 mainline baseline 到当前 branch 的合并摘要见 `rvv-mainline-merge-summary.md`。

验收标准：

- 能稳定运行 2 到 3 个小型 RVV 程序，例如 vector add、vector xor、load-add-store。
- unsupported RVV 指令路径可预测，不 silent wrong execution。
- CPU scalar 回归不回退。

### 阶段 7：性能和覆盖扩展

目标：在 RVV 子集语义稳定后，再做吞吐和覆盖扩展。

可选方向：

- 多 lane 执行。
- 更宽 `VLEN`。
- `SEW=16/64`。
- strided load/store。
- more ALU ops，例如 compare、shift、multiply。
- 更完整 mask/tail policy。
- 更细粒度 perf counters。

验收标准：

- 每项性能优化都有前后性能数据。
- 不改变已声明 RVV 子集语义。
- 不破坏 CPU/COP owner boundary。

### 阶段 8：Benchmark-driven 最终子集

目标：让 `sw/benchmark/rvv-subset-benchmark/` 成为最终 partial RVV 的本地验收入口，而不是继续追完整 RVV。`sw/benchmark/rvv-benchmark/` 保留为外部 benchmark submodule。

目标 benchmark：

- `vec_add_i32`：32-bit vector add load/compute/store。
- `vec_xor_u8`：8-bit vector xor load/compute/store。
- `memcpy_vec`：byte unit-stride vector copy。
- `dot_i32_tiny`：tiny dot product，覆盖 multiply 和 reduction/add tail。
- `threshold_u8`：byte threshold/select，覆盖 compare mask 和 merge。

需要补齐的 ISA 能力：

- `vsetvli`，与现有 `vsetivli` 共用受限 `vtype` 策略。
- `SEW=16` datapath 和 `vle16.v/vse16.v`。
- `vmul.vv/vx`。
- `vmseq/vmsne/vmslt/vmsltu` 最小 compare mask。
- `vmerge`。
- `vredsum.vs`，作为唯一计划 reduction。

不进入该阶段的能力：

- `LMUL>m1`、fractional LMUL、`SEW=64`。
- strided/indexed/segment/fault-only-first/masked memory。
- full trap/precise vector exception 和 `vstart` restart。
- FP、widening/narrowing、saturating、divide/remainder、完整 mask load/store。

验收标准：

- 五个 benchmark 都能使用标准 RVV path 运行，不依赖 custom VRF read/write 作为功能路径。
- 每个 benchmark 都有 scalar reference check。
- scalar init、vector memory、scalar check 的 coherency contract 已文档化并由测试覆盖。
- 固定 smoke target 同时跑 acceptance、phase tests、benchmark tests 和 memory kill/store directed tests。

## 五、建议里程碑

### M0：原型稳定

- 当前 custom COP 文档和测试一致。
- COP memory owner routing 和 pending-kill coverage 合入主线。
- 所有新增行为都有 directed test。
- COP store 的 owner path 和 pre-accept killed-store side effect 有 directed coverage。

当前状态：M0/P0 已收尾于 `vector-next-cop-mem-pending-kill` 分支。已验证 scalar smoke、COP lane/state/VRF、COP memory smoke、pending-kill load、store AW/W/B owner path 和 pre-accept killed-store side effect。下一阶段进入 M1/P1 前，应保持 custom COP 原型作为回归基线，并优先定义最小 `vl/vtype` 状态与 unsupported RVV 行为。

### M1：RVV 状态可配置

- 最小 `vl/vtype` 状态实现。
- `vsetvli` 或 `vsetivli` 可配置受限向量状态。
- unsupported 配置明确失败。

P1A 状态契约见 `rvv-state-p1.md`。P1A 只冻结状态语义和验证范围；P1B 先做 COP-local prototype，不直接接标准 RVV decode。

当前状态：P1B 已实现 custom COP `vtype` prototype 和 `vl` 饱和到 `VLMAX=4` 的 prototype 行为。该阶段仍不声明标准 RVV supported；标准 `vset*` decode 留给后续 P2/interface review。

P1C/P2 prototype 已新增 custom COP `vstate_add` 和 `vsetivli_p`：前者验证 `vl/vtype/vill` 被执行类操作消费，后者验证 vset-like AVL 饱和和 `vtype` 配置路径。两者仍使用 custom-0，不是标准 RVV decode。

### M2：RVV ALU 子集可运行

- 标准 RVV 编码进入 backend。
- 基础整数向量 ALU 可执行。
- `vl` 控制 element 执行范围。

### M3：RVV memory 子集可运行

- unit-stride load/store 可执行。
- load/ALU/store 小程序通过。
- kill/flush/stale response 覆盖齐全。

### M4：声明部分 RVV 支持

- 发布支持矩阵。
- 至少 2 到 3 个标准 RVV 风格程序稳定通过。
- custom COP 原型进入兼容/回归角色，新增功能优先走 RVV path。

当前状态：M4 已在 `vector-next-rvv-state-p1` 上形成第一版 partial RVV subset，并以 `rvv-subset-freeze.md` 冻结当前支持范围。下一步进入 M5，目标从“更多 RVV 指令”改为“跑通 benchmark-driven 最终子集”。

### M5：RVV benchmark 子集

- 建立 `sw/benchmark/rvv-subset-benchmark/` benchmark harness。当前已落地 build/run 入口和五个 benchmark。
- 跑通 `vec_add_i32`、`vec_xor_u8`、`memcpy_vec`、`dot_i32_tiny`、`threshold_u8`。benchmark 功能路径使用标准 RVV load/compute/store，不再依赖 `rvv_debug_*`。
- 已补 `vle16/vse16`、`vmul.vv/vx`、compare mask、`vmerge` 和 `vredsum.vs`。
- 已新增 `rvv-phase15-memory-contract`，覆盖 static backing vector load + vector store to scalar-visible memory。
- 当前冻结阶段性 scalar/vector memory contract：benchmark 不依赖 scalar store 到 vector load 的 coherent cache 行为。
- 已封装 `rvv-final-acceptance`，作为本分支 benchmark-driven partial RVV 最终验收入口。

## 六、风险与前置条件

### CPU 接口风险

RVV decode、CSR、exception、memory side effect 都可能触碰 CPU shared boundary。任何这类变化进入 mainline 前必须先经过 interface review。

### Store 可回滚性风险

Vector store 是最容易破坏 kill 语义的路径。第一版应避免在指令可被 kill 的窗口提前产生不可回滚写入，或者明确通过 CPU commit 边界序列化 store side effect。

### 状态膨胀风险

`vl/vtype/vstart/mask/tail` 很容易把原型状态扩成难以验证的组合。每个状态位都需要有软件可见语义和 directed test。

### 编码迁移风险

`custom-0` 和标准 RVV 编码可能长期并存。并存期间必须保证 decode 优先级和 illegal path 明确，避免同一 bit pattern 被两个路径解释。

## 七、近期执行建议

接下来最适合做的工作顺序：

1. 使用 `make rvv-final-acceptance EXTRA_VERILATOR_FLAGS='-j 1'` 作为本分支最终验收入口。
2. 将 true scalar cache/COP bypass coherency 另起阶段处理，避免扩大本轮 CPU/COP memory boundary。
3. 后续若继续扩展 RVV，先更新 `rvv-subset-freeze.md` 和 `rvv-supported-subset.md`。

## 八、完成定义

当以下条件满足时，可以说 HelloCPU 至少支持部分 RVV：

- 使用标准 RVV 编码，而不是只依赖 `custom-0`。
- 能配置最小 `vl/vtype`。
- 能执行至少一种 SEW 下的基础整数向量 ALU。
- 能执行对应 SEW 的 unit-stride vector load/store。
- 能运行 load/compute/store 形式的 RVV 小程序。
- 能运行 `sw/benchmark/rvv-subset-benchmark/` 中的目标 benchmark，并通过 scalar reference check。
- 对 unsupported RVV 指令和配置有明确行为。
- kill/flush 不会造成 GPR、VRF 或内存错误提交。
