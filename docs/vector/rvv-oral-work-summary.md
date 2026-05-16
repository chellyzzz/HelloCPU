# RVV 工作口头说明

这段时间我主要完成了 HelloCPU 的 benchmark-driven partial RVV 子集收口。目标不是做完整 RVV compliance，而是先让一组小型整数向量 benchmark 能稳定跑通，同时把不支持的 RVV 功能明确冻结为 unsupported 或 deferred，避免 RTL 静默执行近似语义。

当前分支已经支持 `vsetvli` 的 rs1 AVL path、`SEW=8/16/32`、`LMUL=m1`、标准 `v0-v31` 寄存器字段、基础整数 ALU、bitwise、shift、move、`vmul.vv/vx`、compare mask、`vmerge`、`vredsum.vs`，以及 unmasked unit-stride `vle/vse8/16/32`。同时，`vl`、`vtype`、`vstart` 已经通过 CSR mirror 可读，`vstart` 当前固定为 0。

软件侧我新增并整理了本地 RVV benchmark harness，放在 `sw/benchmark/rvv-subset-benchmark/`，避免污染外部 `rvv-benchmark` submodule。当前 benchmark 包括 `vec_add_i32`、`vec_xor_u8`、`memcpy_vec`、`dot_i32_tiny` 和 `threshold_u8`。这些 benchmark 的功能路径已经改成标准 RVV load/compute/store，不再依赖 `rvv_debug_*` 写 VRF 的测试 hook。

验证侧新增了 focused tests，覆盖 compare/merge、reduction 和 staged memory contract。特别是 `rvv-phase15-memory-contract` 明确当前支持的内存契约：vector load 使用 static initialized backing memory，vector store 写到 scalar-visible destination 后由 scalar 检查。当前不声明 scalar store 立即喂 vector load 的 coherent cache 行为，这个 true scalar-cache/COP-bypass coherency 被明确放到后续阶段。

我还封装了最终验收入口 `make rvv-final-acceptance EXTRA_VERILATOR_FLAGS='-j 1'`。这个 target 会跑 `git diff --check`、完整 `rvv-subset-smoke` 和所有本地 RVV benchmark。该 final gate 已经在本分支通过。

目前本轮 partial RVV benchmark subset 可以认为已经完成，适合进入 merge/PR 收口。剩余风险主要不在当前 benchmark 子集，而在更完整 RVV 架构能力：true scalar/vector coherency、完整 illegal trap、precise vector exception、`vstart` restart、`LMUL>m1`、masked memory、strided/indexed/segment memory，以及 full RVV compliance。这些都已经在文档中明确为 deferred 或 out of scope。

下一步建议先做 PR 级别 hygiene：在干净 checkout 上重跑 `rvv-final-acceptance`，整理 merge note，并同步最新 mainline。后续如果继续推进 RVV，建议单独开 coherency phase，先解决 scalar cache 与 COP memory bypass 的一致性，再考虑异常、restart、masked memory 和更大寄存器组织。
